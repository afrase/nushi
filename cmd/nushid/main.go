// Command nushid is the Nushi daemon: it runs agents and serves the app over a Unix socket.
package main

import (
	"bytes"
	"cmp"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"slices"
	"strings"
	"syscall"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/claudehistory"
	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/claudetrust"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/trust"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/terminal"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	projects, err := claudehistory.Projects()
	if err != nil {
		return err
	}
	// NUSHI_DATA runs a second daemon beside the usual one, for development.
	dir := os.Getenv("NUSHI_DATA")
	if dir == "" {
		support := filepath.Join(home, "Library", "Application Support")
		dir = filepath.Join(support, "Nushi")
		if err := moveData(filepath.Join(support, "Nushi Next"), dir, projects); err != nil {
			return fmt.Errorf("moving Nushi Next's data: %w", err)
		}
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	if err := os.Chmod(dir, 0o700); err != nil {
		return err
	}
	token, err := loadToken(filepath.Join(dir, "token"))
	if err != nil {
		return err
	}
	ln, err := listen(filepath.Join(dir, "nushid.sock"))
	if err != nil {
		return err
	}
	log.Printf("nushid listening on %s", ln.Addr())

	hub := &events.Hub{}
	// Every chat runs Claude: what it does beyond ACP is in internal/claude*.
	launch := func(h acp.Handler) (chats.Agent, error) { return claude.Start(dir, h) }
	dialect := chats.Dialect{InitMeta: claude.InitMeta, ForkAt: claude.ForkAt, Parent: claude.Parent, ToolCall: claude.ToolCall,
		Background: claude.Background, ReportElsewhere: claude.ReportElsewhere,
		Shell: claude.Shell, ReadShell: claude.ReadShell,
		SubagentID: claude.SubagentID, Relay: claude.Relay, Relayed: claude.Relayed, Other: claude.Other, Default: claude.Default, ForkTitle: claude.ForkTitle,
		ContextCommand: claude.ContextCommand, ReadContext: claude.ReadContext, Redelete: claude.Redelete}
	st := store.New(dir)
	st.HadMessages = func(s model.Session) bool { return claudehistory.Has(projects, s.SessionID, s.Folder) }
	copyHistory := func(id, from, to string) (func() error, error) { return claudehistory.Copy(projects, id, from, to) }
	chatSvc := chats.New("claude", launch, dialect, st, st, copyHistory, git.Worktrees{}, filepath.Join(dir, "scratch"), hub.Publish)
	termSvc := terminals.New(startShell, filepath.Base(loginShell), chatSvc, hub.Publish)
	chatSvc.UseTerminals(termSvc)
	go hub.Subscribe(nil, func() bool { return true }, func(e model.Event) bool { termSvc.Follow(e); return true })
	srv := &http.Server{Handler: api.Handler(token, chatSvc, mcp.New(claudemcp.Claude{}, chatSvc.MCPChanged), termSvc, trust.New(claudetrust.Trust{}, st), hub),
		Protocols: new(http.Protocols)}
	srv.Protocols.SetUnencryptedHTTP2(true)

	// On SIGINT or SIGTERM, stop the agents too: their sessions reopen
	// through session/load when the daemon is back.
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-stop
		srv.Close()
	}()
	err = srv.Serve(ln)
	chatSvc.Close()
	termSvc.CloseAll()
	if errors.Is(err, http.ErrServerClosed) {
		log.Print("nushid stopped")
		return nil
	}
	return err
}

// loadToken reads the client token, making a new one on first start or
// when the file holds too little to be one (an empty token would let
// "Bearer " in). The file is kept at mode 0600.
func loadToken(path string) (string, error) {
	b, err := os.ReadFile(path)
	if token := strings.TrimSpace(string(b)); err == nil && len(token) >= 32 {
		return token, os.Chmod(path, 0o600)
	}
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return "", err
	}
	raw := make([]byte, 32)
	_, _ = rand.Read(raw)
	token := hex.EncodeToString(raw)
	os.Remove(path) // WriteFile keeps an old file's mode
	return token, os.WriteFile(path, []byte(token), 0o600)
}

// listen takes over the socket at path unless another daemon is answering on it.
func listen(path string) (net.Listener, error) {
	if c, err := net.Dial("unix", path); err == nil {
		c.Close()
		return nil, fmt.Errorf("a daemon is already listening on %s", path)
	}
	_ = os.Remove(path)
	return net.Listen("unix", path)
}

// loginShell is the user's shell from the user database, as Terminal picks
// it, else $SHELL, else zsh. The daemon's own $SHELL is whatever started it.
var loginShell = func() string {
	// id -P prints the user's passwd entry; the shell is its last field.
	out, _ := exec.Command("/usr/bin/id", "-P").Output()
	shell := strings.TrimSpace(string(out[bytes.LastIndexByte(out, ':')+1:]))
	if st, err := os.Stat(shell); err == nil && st.Mode().IsRegular() && st.Mode()&0o111 != 0 {
		return shell
	}
	return cmp.Or(os.Getenv("SHELL"), "/bin/zsh")
}()

// startShell starts the user's login shell in a terminal, with the daemon's
// environment and $SHELL naming that shell.
func startShell(folder string, cols, rows int, changed func()) (terminals.Shell, error) {
	env := slices.DeleteFunc(os.Environ(), func(v string) bool { return strings.HasPrefix(v, "SHELL=") })
	env = append(env, "SHELL="+loginShell, "TERM=xterm-256color", "COLORTERM=truecolor")
	return terminal.Start([]string{loginShell, "-l"}, folder, env, cols, rows, changed)
}
