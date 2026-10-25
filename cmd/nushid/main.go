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
	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/antetrust"
	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/claudehistory"
	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/claudetrust"
	"github.com/afrase/nushi/internal/codex"
	"github.com/afrase/nushi/internal/codextrust"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/memory"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/trust"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/omp"
	"github.com/afrase/nushi/internal/omptrust"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/sysproxy"
	"github.com/afrase/nushi/internal/terminal"
	"github.com/afrase/nushi/relay"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == ante.Command { // the bridge Nushi runs Ante through
		ante.Main()
		return
	}
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
	// What each agent does beyond ACP is in its own packages: internal/claude*,
	// internal/codex*, internal/ante* (Ante's bridge too, ADR 0030) and
	// internal/omp*.
	claudeKind := chats.Kind{Name: "claude", Title: "Claude", Resume: "claude --resume", MCP: true,
		Launch: func(h acp.Handler) (chats.Agent, error) { return claude.Start(dir, h) },
		Dialect: chats.Dialect{InitMeta: claude.InitMeta, ForkAt: claude.ForkAt, Parent: claude.Parent, ToolCall: claude.ToolCall,
			Background: claude.Background, ReportElsewhere: claude.ReportElsewhere,
			Shell: claude.Shell, ReadShell: claude.ReadShell,
			SubagentID: claude.SubagentID, Relay: claude.Relay, Relayed: claude.Relayed, Other: claude.Other, Default: claude.Default, ForkTitle: claude.ForkTitle,
			ContextCommand: claude.ContextCommand, ReadContext: claude.ReadContext, Redelete: claude.Redelete},
		History:       func(id, from, to string) (func() error, error) { return claudehistory.Copy(projects, id, from, to) },
		OpenElsewhere: claudehistory.Open, Forked: func(ids []string) map[string]bool { return claudehistory.Forked(projects, ids) }}
	codexKind := chats.Kind{Name: "codex", Title: "Codex", Resume: codex.Resume, History: codex.History, DeleteArchives: codex.DeleteArchives,
		OpenElsewhere: codex.OpenElsewhere, Forked: codex.Forked, OneWriter: true,
		Launch:  func(h acp.Handler) (chats.Agent, error) { return codex.Start(dir, h) },
		Dialect: chats.Dialect{ForkAt: codex.ForkAt, ToolCall: codex.ToolCall, Other: codex.Other}}
	anteKind := chats.Kind{Name: "ante", Title: "Ante", Resume: ante.Resume, OpenElsewhere: ante.OpenElsewhere,
		Launch:  func(h acp.Handler) (chats.Agent, error) { return ante.Start(dir, h) },
		Dialect: chats.Dialect{ForkAt: ante.ForkAt, Other: ante.Other, Context: ante.Context}}
	ompKind := chats.Kind{Name: "omp", Title: "oh-my-pi", Resume: omp.Resume, Forked: omp.Forked, OpenElsewhere: omp.OpenElsewhere, OneWriter: true,
		Launch:  func(h acp.Handler) (chats.Agent, error) { return omp.Start(dir, h) },
		Dialect: chats.Dialect{Other: omp.Other, ToolCall: omp.ToolCall}}
	st := store.New(dir)
	st.HadMessages = func(s model.Session) bool { return claudehistory.Has(projects, s.SessionID, s.Folder) }
	chatSvc := chats.New([]chats.Kind{claudeKind, codexKind, anteKind, ompKind}, st, st, git.Worktrees{}, filepath.Join(dir, "scratch"), hub.Publish)
	chatSvc.AutoSleep(st)
	termSvc := terminals.New(startShell, filepath.Base(loginShell), chatSvc, hub.Publish)
	chatSvc.UseTerminals(termSvc)
	go hub.Subscribe(nil, func() bool { return true }, func(e model.Event) bool { termSvc.Follow(e); return true })
	// The API, on the socket for the app (with the token) and on each
	// paired device's channel (ADR 0034).
	sv := api.Services{Chats: chatSvc, MCP: mcp.New(claudemcp.Claude{}, chatSvc.MCPChanged), Terms: termSvc,
		Trust: trust.New(map[string]trust.Agent{"claude": claudetrust.Trust{}, "codex": codextrust.Trust{}, "ante": antetrust.Trust{}, "omp": omptrust.Trust{}}, st),
		Hub:   hub, Memory: memory.New(chatSvc)}
	channels := newChannels()
	if sv.Remote, err = remote.New(st, &relay.Dialer{Proxies: sysproxy.For}, channels.serve, keepAwake, hub.Publish); err != nil {
		return err
	}
	remoteSrv := &http.Server{Handler: api.ForDevices(sv), Protocols: new(http.Protocols)}
	remoteSrv.Protocols.SetUnencryptedHTTP2(true)
	go remoteSrv.Serve(channels)
	srv := &http.Server{Handler: api.WithToken(token, api.New(sv)), Protocols: new(http.Protocols)}
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
	sv.Remote.Close()
	remoteSrv.Close()
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
