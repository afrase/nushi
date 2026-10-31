// Command nushid is the Nushi daemon: it runs agents and serves the app over a Unix socket.
package main

import (
	"bytes"
	"cmp"
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime/debug"
	"slices"
	"strings"
	"sync"
	"syscall"

	"golang.org/x/sys/unix"

	"github.com/afrase/nushi/claudeacp"
	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/claudehistory"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/memory"
	"github.com/afrase/nushi/internal/features/preview"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/restart"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/mcpserver"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/pig"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/sysproxy"
	"github.com/afrase/nushi/internal/terminal"
	"github.com/afrase/nushi/internal/transcripts"
	"github.com/afrase/nushi/relay"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == ante.Command { // the bridge Nushi runs Ante through
		ante.Main()
		return
	}
	if len(os.Args) > 1 && os.Args[1] == pig.Command { // and PiG
		pig.Main()
		return
	}
	if len(os.Args) > 1 && os.Args[1] == claudeacp.Command { // and Claude, when its Go agent is on (ADR 0066)
		claudeacp.Main()
		return
	}
	if len(os.Args) > 1 && os.Args[1] == mcpserver.Command { // a chat's agent's MCP server of Nushi's tools
		mcpserver.Main()
		return
	}
	if len(os.Args) > 1 && os.Args[1] == "-version" {
		fmt.Println("nushid", version()) //nolint:forbidigo // -version's answer
		return
	}
	// Until the daemon holds its socket, its lines go to stderr, which the
	// launcher points at nushid.log.
	slog.SetDefault(slog.New(logs.Handler(os.Stderr)))
	if len(os.Args) > 1 && os.Args[1] == loginFlag {
		fatal(execLogin())
	}
	if err := run(); err != nil {
		fatal(err)
	}
}

func fatal(err error) {
	slog.Error("nushid can't run", "why", err)
	os.Exit(1) //nolint:revive // main's own fatal, called before anything needs closing
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
	if err := os.Chmod(dir, 0o700); err != nil { //nolint:gosec // a folder: 0700 is owner-only
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
	if _, err := logs.Setup(filepath.Join(dir, "nushid.log")); err != nil {
		return err
	}
	logs.Mask(token)
	slog.Info("nushid started", "version", version(), "build", api.Build(), "api", api.Version, "data", dir, "pid", os.Getpid(),
		"log_level", logs.Level.Level())

	hub := &events.Hub{}
	st := store.New(dir)
	known := knownagents.All(projects, st.ClaudeGoAgent)
	agentSvc := newAgents(dir, known)
	st.HadMessages = func(s model.ChatRecord) bool { return claudehistory.Has(projects, s.SessionID, s.Folder) }
	copies, err := transcripts.Open(filepath.Join(dir, "transcripts"))
	if err != nil {
		return err
	}
	dev := os.Getenv("NUSHI_DATA") != ""
	jiraSvc := newJira(st, dev)
	shows := preview.New(hub.Publish)
	toolSvc := tools.New(jiraSvc.Tools(), shows)
	channels := newChannels()
	remoteSvc, err := remote.New(st, &relay.Dialer{Proxies: sysproxy.For}, channels.serve, keepAwake, hub.Publish)
	if err != nil {
		return err
	}
	kinds := chatKinds(dir, known, agentSvc)
	chatSvc := chats.New(context.Background(), kinds, chats.Options{Remembered: st, Sessions: st, Worktrees: git.Worktrees{},
		Scratch: filepath.Join(dir, "scratch"), Publish: hub.Publish, Tools: mcpTools(toolSvc, filepath.Join(dir, "nushid.sock")),
		Viewers: remoteSvc, Processes: proctree.Tree{}, Copies: copies, CopiesOn: st.KeepTranscripts, CopyDays: st.TranscriptDays, Sleep: st})
	shows.UseChats(chatSvc)
	go chatSvc.EndStalePrompts() // what a daemon that stopped left pending
	termSvc := terminals.New(startShell, filepath.Base(loginShell()), chatSvc, hub.Publish)
	chatSvc.UseTerminals(termSvc)
	go follow(hub, termSvc.Follow)
	agentSvc.UseChats(chatSvc)
	// The API, on the socket for the app (with the token) and on each
	// paired device's channel (ADR 0034).
	logs.SetDebug(st.DebugLog())
	restarts := restart.New(chatSvc, termSvc)
	sv := api.Services{Log: st, Transcripts: st, Chats: chatSvc, Agents: agentSvc, MCP: newMCP(known, agentSvc, chatSvc.MCPChanged), Skills: newSkills(known), Terms: termSvc,
		Trust: newTrust(known, st), Hub: hub, Memory: memory.New(chatSvc), Restart: restarts, Jira: jiraSvc, Remote: remoteSvc}
	sv.GitHub = newGitHub(st, dev)
	sv.Updates = startUpdates(st, hub.Publish)
	sv.ClaudeGo = st
	if err := usePush(st, sv.Remote, chatSvc, kinds); err != nil {
		return err
	}
	go follow(hub, sv.Remote.Follow)
	// A handler's panic, which net/http recovers, is logged with its stack.
	errorLog := slog.NewLogLogger(slog.Default().Handler(), slog.LevelError)
	remoteSrv := &http.Server{Handler: api.ForDevices(sv), ConnContext: api.DeviceConn, Protocols: new(http.Protocols), ErrorLog: errorLog} //nolint:gosec // served only over paired devices' Noise channels
	remoteSrv.Protocols.SetUnencryptedHTTP2(true)
	// Serve returns once remoteSrv.Close below closes channels.
	go func() { _ = remoteSrv.Serve(channels) }()
	mux := http.NewServeMux()
	mux.Handle("/tools/", api.Tools(toolSvc)) // a chat's key, not the token (ADR 0043)
	mux.Handle("/", api.WithToken(token, api.New(sv)))
	srv := &http.Server{Handler: mux, Protocols: new(http.Protocols), ErrorLog: errorLog} //nolint:gosec // a Unix socket in a 0700 folder; clients need the token
	srv.Protocols.SetUnencryptedHTTP2(true)

	// On SIGINT or SIGTERM, once its app is deleted, or for a restart
	// into a newer build, stop the agents too: their sessions reopen
	// through session/load when the daemon is back.
	closeChats := sync.OnceFunc(func() { chatSvc.Close(); termSvc.CloseAll() })
	why, err := serve(srv, ln, restarts.Due(), closeChats)
	if why != "" {
		slog.Info("nushid stopping", "why", why)
	} else {
		slog.Error("nushid stopping", "why", err)
	}
	sv.Remote.Close()
	_ = remoteSrv.Close() // stopping: nothing is left to tell
	closeChats()
	if errors.Is(err, http.ErrServerClosed) {
		slog.Info("nushid stopped")
		return nil
	}
	return err
}

// serve serves the API on ln until SIGINT or SIGTERM, until the app the
// daemon runs from is deleted (appDeleted), or until a restart is due
// (internal/features/restart), and says why it stopped: "" when Serve
// failed by itself. For a restart the chats and terminals close first,
// while the socket still answers (prompts refused, to be sent again): the
// app starts the new daemon once the socket is gone, so the two never run
// at once.
func serve(srv *http.Server, ln net.Listener, restartDue <-chan struct{}, closeChats func()) (string, error) {
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	exe, _ := os.Executable() // "" (never deleted) if macOS can't say
	deleted := appDeleted(exe, appCheck)
	why := make(chan string, 1)
	go func() {
		select {
		case sig := <-stop:
			why <- unix.SignalName(sig.(syscall.Signal)) //nolint:forcetypeassert // signal.Notify sends syscall.Signals
		case <-deleted:
			why <- "its app was deleted"
		case <-restartDue:
			closeChats()
			why <- "restarting into a newer build"
		}
		_ = srv.Close() // Serve returns ErrServerClosed
	}()
	err := srv.Serve(ln)
	select {
	case w := <-why:
		return w, err
	default:
		return "", err
	}
}

// version is the release the daemon was packaged as ("dev" when it
// wasn't), the commit it was built from ("-dirty" with changes not
// committed) and the Go it was built with.
func version() string {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return cmp.Or(api.Release, "dev")
	}
	var rev, dirty string
	for _, s := range info.Settings {
		switch {
		case s.Key == "vcs.revision" && len(s.Value) >= 12:
			rev = s.Value[:12]
		case s.Key == "vcs.modified" && s.Value == "true":
			dirty = "-dirty"
		}
	}
	return cmp.Or(api.Release, "dev") + " (" + cmp.Or(rev, "unknown") + dirty + " " + info.GoVersion + ")"
}

// follow gives fn every event, in the daemon, for its life: never
// dropped, however far behind (events.Unbounded).
func follow(hub *events.Hub, fn func(model.Event)) {
	_ = hub.Subscribe(context.Background(), func(e model.Event) bool { fn(e); return true }, events.Unbounded()) // ends only with fn's false
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
	_ = os.Remove(path) // WriteFile keeps an old file's mode
	return token, os.WriteFile(path, []byte(token), 0o600)
}

// listen takes over the socket at path unless another daemon is answering on it.
func listen(path string) (net.Listener, error) {
	if c, err := new(net.Dialer).DialContext(context.Background(), "unix", path); err == nil {
		_ = c.Close()
		return nil, fmt.Errorf("a daemon is already listening on %s", path)
	}
	_ = os.Remove(path)
	return new(net.ListenConfig).Listen(context.Background(), "unix", path)
}

// loginShell is the user's shell from the user database, as Terminal picks
// it, else $SHELL, else zsh. The daemon's own $SHELL is whatever started it.
// It is asked once, when first needed: not by the subcommands (a bridge, a
// chat's tools), which run this executable too.
var loginShell = sync.OnceValue(func() string {
	// id -P prints the user's passwd entry; the shell is its last field.
	out, _ := exec.Command("/usr/bin/id", "-P").Output()
	shell := strings.TrimSpace(string(out[bytes.LastIndexByte(out, ':')+1:]))
	if st, err := os.Stat(shell); err == nil && st.Mode().IsRegular() && st.Mode()&0o111 != 0 {
		return shell
	}
	return cmp.Or(os.Getenv("SHELL"), "/bin/zsh")
})

// startShell starts the user's login shell in a terminal, with the daemon's
// environment and $SHELL naming that shell.
func startShell(folder string, cols, rows int, changed func()) (terminals.Shell, error) {
	env := slices.DeleteFunc(os.Environ(), func(v string) bool { return strings.HasPrefix(v, "SHELL=") })
	env = append(env, "SHELL="+loginShell(), "TERM=xterm-256color", "COLORTERM=truecolor")
	return terminal.Start([]string{loginShell(), "-l"}, folder, env, cols, rows, changed)
}
