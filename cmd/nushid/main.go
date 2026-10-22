// Command nushid is the Nushi daemon: it runs agents and serves the app over a Unix socket.
package main

import (
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
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/store"
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
	dir := filepath.Join(home, "Library", "Application Support", "Nushi Next")
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
	chatSvc := chats.New("claude", launch, st, st, hub.Publish)
	srv := &http.Server{Handler: api.Handler(token, chatSvc, hub), Protocols: new(http.Protocols)}
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
// goes to the daemon log. Claude keeps a todo list (ACP plan updates) only
// with its todo tools on, as its own terminal UI has them; a value already
// in the environment wins.
func launchClaude(dir string, h acp.Handler) (chats.Agent, error) {
	cmd := exec.Command("npx", "--yes", claudeACP)
	cmd.Dir = dir
	if _, ok := os.LookupEnv("CLAUDE_CODE_ENABLE_TODO_TOOLS"); !ok {
		cmd.Env = append(os.Environ(), "CLAUDE_CODE_ENABLE_TODO_TOOLS=1")
	}
	cmd.Stderr = log.Writer()
	return acp.Start(cmd, h)
}
