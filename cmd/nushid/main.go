// Command nushid is the Nushi daemon: it runs agents and serves the app over a Unix socket.
package main

import (
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
	"strings"
	"syscall"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/claudehistory"
	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/terminal"
)

// claudeACP is the pinned Claude Code ACP adapter.
const claudeACP = "@agentclientprotocol/claude-agent-acp@0.94.0"

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
	launch := func(h acp.Handler) (chats.Agent, error) { return launchClaude(dir, h) }
	st := store.New(dir)
	copyHistory := func(id, from, to string) (func() error, error) { return claudehistory.Copy(projects, id, from, to) }
	chatSvc := chats.New("claude", launch, st, st, copyHistory, git.Worktrees{}, filepath.Join(dir, "scratch"), hub.Publish)
	termSvc := terminals.New(startShell, filepath.Base(loginShell), chatSvc, hub.Publish)
	srv := &http.Server{Handler: api.Handler(token, chatSvc, mcp.New(claudemcp.Claude{}, chatSvc.MCPChanged), termSvc, hub),
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

// loadToken reads the client token, creating it on first start.
func loadToken(path string) (string, error) {
	b, err := os.ReadFile(path)
	if err == nil {
		return strings.TrimSpace(string(b)), nil
	}
	if !errors.Is(err, fs.ErrNotExist) {
		return "", err
	}
	raw := make([]byte, 32)
	_, _ = rand.Read(raw)
	token := hex.EncodeToString(raw)
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

// launchClaude starts Claude Code's ACP adapter. It runs in the daemon's own
// folder, so npx never resolves the adapter or npm settings from a project;
// the chat's folder reaches the agent only as the session's cwd. Its stderr
// goes to the daemon log.
func launchClaude(dir string, h acp.Handler) (chats.Agent, error) {
	cmd := exec.Command("npx", "--yes", claudeACP)
	cmd.Dir = dir
	cmd.Stderr = log.Writer()
	return acp.Start(cmd, h)
}

var loginShell = cmp.Or(os.Getenv("SHELL"), "/bin/zsh")

// startShell starts the user's login shell in a terminal, with the daemon's
// environment.
func startShell(folder string, cols, rows int, changed func()) (terminals.Shell, error) {
	env := append(os.Environ(), "TERM=xterm-256color", "COLORTERM=truecolor")
	return terminal.Start([]string{loginShell, "-l"}, folder, env, cols, rows, changed)
}
