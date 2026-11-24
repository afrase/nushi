// Command nushid is the Nushi daemon: it runs agents and serves the app over a Unix socket.
package main

import (
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
	"os/signal"
	"path/filepath"
	"runtime/debug"
	"slices"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/claudehistory"
	"github.com/afrase/nushi/internal/codex"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/memory"
	"github.com/afrase/nushi/internal/features/preview"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/restart"
	"github.com/afrase/nushi/internal/features/servers"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/filelock"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/mcpserver"
	"github.com/afrase/nushi/internal/pi"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/sysproxy"
	"github.com/afrase/nushi/internal/terminal"
	"github.com/afrase/nushi/internal/transcripts"
	"github.com/afrase/nushi/relay"
)

func main() {
	noCurrentDirPrograms()
	if len(os.Args) > 1 && os.Args[1] == ante.Command { // the bridge Nushi runs Ante through
		ante.Main()
		return
	}
	for _, f := range []pi.Flavor{pi.Pi, pi.PiG} { // and Pi and PiG
		if len(os.Args) > 1 && os.Args[1] == f.Command() {
			f.Main()
			return
		}
	}
	if len(os.Args) > 1 && os.Args[1] == claude.AgentCommand { // and Claude, through its Go agent (ADR 0066)
		if runClaudeAgent() != nil {
			os.Exit(1) // Main logged why
		}
		return
	}
	if len(os.Args) > 1 && os.Args[1] == codex.AgentCommand { // and Codex, through its Go agent (ADR 0142)
		if runCodexAgent() != nil {
			os.Exit(1) // Main logged why
		}
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
	login, err := daemonArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	// Until the daemon holds its socket, its lines go to stderr, which the
	// launcher points at nushid.log.
	slog.SetDefault(slog.New(logs.Handler(os.Stderr)))
	switch relaunched, err := hideConsole(); {
	case relaunched:
		return // the daemon started again with a console of no window takes over
	case err != nil:
		slog.Warn("console not hidden; a program the daemon starts may open a window", "err", err)
	}
	if login {
		fatal(execLogin())
	}
	if err := run(); err != nil {
		fatal(err)
	}
}

// daemonArgs reads the daemon's arguments, once the subcommands' are
// ruled out: none, or -login (loginFlag). Anything else (a -h, a typo) is
// an error saying how it runs, never a daemon started on the default data
// folder. Launch Services' `-psn_…` (a process serial number, which macOS
// has given an app it opens) is passed over.
func daemonArgs(args []string) (login bool, err error) {
	args = slices.DeleteFunc(slices.Clone(args), func(a string) bool { return strings.HasPrefix(a, "-psn_") })
	switch {
	case len(args) == 0:
		return false, nil
	case len(args) == 1 && args[0] == loginFlag:
		return true, nil
	}
	return false, fmt.Errorf("nushid: unknown arguments %q\nusage: nushid [%s | -version]", args, loginFlag)
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
	dir := dataFolder(home)
	forgetLauncher()
	if dir == "" {
		return errNoDataFolder
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	if err := ownDataFolder(dir); err != nil {
		return err
	}
	unlock, err := lockDataFolder(dir, 5*time.Second)
	if err != nil {
		return err
	}
	defer unlock() // as run returns; until then this keeps the lock's file open, which a dropped *os.File's finalizer would close
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
	known := knownagents.All(projects, st.GoAgent)
	shellEnv := newShellEnv()
	sysproxy.UseShellEnviron(shellEnv.Environ) // Linux only; before the relay, Jira, GitHub or Web Push asks
	agentSvc := newAgents(dir, known, shellEnv)
	copies, err := transcripts.Open(filepath.Join(dir, "transcripts"))
	if err != nil {
		return err
	}
	dev := os.Getenv("NUSHI_DATA") != ""
	jiraSvc := newJira(st, dev)
	shows := preview.New(hub.Publish)
	serverTools := &servers.AgentTools{}
	toolSvc := tools.New(jiraSvc.Tools(), shows, serverTools)
	channels := newChannels()
	remoteSvc, err := remote.New(st, &relay.Dialer{Proxies: sysproxy.For}, channels.serve, keepAwake, hub.Publish)
	if err != nil {
		return err
	}
	kinds := chatKinds(dir, known, agentSvc)
	usageSvc, closeUsage := openUsage(filepath.Join(dir, "nushi.db"), st)
	record := newRecord(dir)
	chatSvc := chats.New(context.Background(), kinds, chats.Options{Remembered: st, Sessions: st, Worktrees: git.Worktrees{},
		Scratch: filepath.Join(dir, "scratch"), Uploads: filepath.Join(dir, "uploads"), Publish: hub.Publish, Tools: mcpTools(toolSvc, filepath.Join(dir, "nushid.sock")),
		Viewers: remoteSvc, Processes: proctree.Tree{}, Record: record, Copies: copies, CopiesOn: st.KeepTranscripts, CopyDays: st.TranscriptDays, Sleep: st, Meter: usageSvc})
	shows.UseChats(chatSvc)
	// Each terminal names its own shell (terminal.Terminal's Name).
	termSvc := terminals.New(shellStarter(agentSvc), "", chatSvc, hub.Publish)
	chatSvc.UseTerminals(termSvc)
	go hub.Follow(context.Background(), termSvc.Follow)
	srvSvc := newServers(record, chatSvc, agentSvc, hub.Publish)
	chatSvc.UseServers(srvSvc)
	serverTools.Use(srvSvc)
	go hub.Follow(context.Background(), srvSvc.Follow)
	agentSvc.UseChats(chatSvc)
	// The API, on the socket for the app (with the token) and on each
	// paired device's channel (ADR 0034).
	logs.SetDebug(st.DebugLog())
	updateSvc := startUpdates(st, hub.Publish, agentSvc.Environ, home)
	restarts := restart.New(chatSvc, restart.Together{termSvc, srvSvc, updateSvc})
	sv := api.Services{Settings: st, ChatFiles: st, Chats: chatSvc, Agents: agentSvc, MCP: newMCP(known, agentSvc, chatSvc.MCPChanged), Skills: newSkills(known), Terms: termSvc,
		Trust: newTrust(known, st), Hub: hub, Memory: memory.New(chatSvc), Restart: restarts, Jira: jiraSvc, Remote: remoteSvc, Servers: srvSvc}
	sv.GitHub = newGitHub(st, dev, shellEnv)
	chatSvc.UseGitHub(sv.GitHub)
	sv.Updates = updateSvc
	sv.Usage = usageSvc
	if err := usePush(st, sv.Remote, chatSvc, kinds); err != nil {
		return err
	}
	go hub.Follow(context.Background(), sv.Remote.Follow)
	// A handler's panic, which net/http recovers, is logged with its stack.
	errorLog := slog.NewLogLogger(slog.Default().Handler(), slog.LevelError)
	socket, devices := api.Handlers(sv, toolSvc, token)
	remoteSrv := &http.Server{Handler: devices, ConnContext: api.DeviceConn, Protocols: new(http.Protocols), ErrorLog: errorLog} //nolint:gosec // served only over paired devices' Noise channels
	remoteSrv.Protocols.SetUnencryptedHTTP2(true)
	// Serve returns once remoteSrv.Close below closes channels.
	go func() { _ = remoteSrv.Serve(channels) }()
	srv := &http.Server{Handler: socket, Protocols: new(http.Protocols), ErrorLog: errorLog} //nolint:gosec // a Unix socket in a 0700 folder; clients need the token
	srv.Protocols.SetUnencryptedHTTP2(true)

	// On SIGINT or SIGTERM (the app's stop event on Windows), once its app
	// is deleted, or for a restart into a newer build, stop the agents
	// too: their sessions reopen through session/load when the daemon is
	// back. The terminals and the
	// dev servers end first: the restart found none running a moment ago,
	// and ending them before the agents (which take up to stopGrace)
	// leaves none the time to start.
	// Usage is written last: the chats' last turns end as they close.
	closeChats := sync.OnceFunc(func() { termSvc.CloseAll(); srvSvc.CloseAll(); chatSvc.Close(); closeUsage() })
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	watchStopEvent(stop)
	why, err := serve(srv, ln, stop, restarts.Due(), closeChats)
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

// serve serves the API on ln until a signal comes on stop (SIGINT or
// SIGTERM), until the app the daemon runs from is deleted (appDeleted),
// or until a restart is due (internal/features/restart), and says why it
// stopped: "" when Serve failed by itself. The chats and terminals close
// first, while the socket still answers (prompts refused, to be sent
// again): an app starts a daemon once the socket is gone, and the new one
// mustn't reopen sessions the old one's agents are still ending (ADR
// 0056).
func serve(srv *http.Server, ln net.Listener, stop <-chan os.Signal, restartDue <-chan struct{}, closeChats func()) (string, error) {
	exe, _ := os.Executable() // "" (never deleted) if macOS can't say
	deleted := appDeleted(exe, appCheck)
	why := make(chan string, 1)
	go func() {
		var w string
		select {
		case sig := <-stop:
			w = signalName(sig)
		case <-deleted:
			w = "its app was deleted"
		case <-restartDue:
			w = "restarting into a newer build"
		}
		closeChats()
		why <- w
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

// lockDataFolder takes the lock on dir's nushid.lock, so one daemon runs
// on a data folder: two started together could each pass listen's dial
// and write a token of their own, and the one left without the socket
// would run on, unreachable. It waits up to wait for one that holds it,
// such as an old daemon still returning after its socket closed (ADR
// 0056). The lock lasts until unlock or the process's end, whichever
// comes first.
func lockDataFolder(dir string, wait time.Duration) (unlock func(), err error) {
	unlock, err = filelock.Lock(filepath.Join(dir, "nushid.lock"), wait)
	if err != nil {
		return nil, fmt.Errorf("locking the data folder (another daemon runs on it?): %w", err)
	}
	return unlock, nil
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
// it, else $SHELL, else fallbackShell. The daemon's own $SHELL is whatever started it.
// It is asked once, when first needed: not by the subcommands (a bridge, a
// chat's tools), which run this executable too.
var loginShell = sync.OnceValue(func() string {
	shell := passwdShell()
	if st, err := os.Stat(shell); err == nil && st.Mode().IsRegular() && st.Mode()&0o111 != 0 {
		return shell
	}
	return cmp.Or(os.Getenv("SHELL"), fallbackShell)
})

// shellStarter starts the user's shell in a terminal (terminalShell: the
// login shell, or Windows Terminal's default profile's), or that shell
// running a command, with terminalEnv's environment, built on
// terminalBase's (and commandEnv's for a command).
func shellStarter(agents interface{ Environ() []string }) terminals.Start {
	return func(folder, command string, cols, rows int, changed func()) (terminals.Shell, error) {
		base := terminalBase(agents)
		argv := terminalShell(base, command)
		env := terminalEnv(base, argv[0])
		if command != "" {
			env = commandEnv(env)
		}
		return terminal.Start(argv, folder, env, cols, rows, changed)
	}
}

// commandEnv is a command's terminal's environment: env with no pager.
// It is a terminal, so git log, man or journalctl would page their output
// through less and wait there for keys, and the command would never end;
// its output goes in a card, in full, as it does where nothing is a
// terminal.
func commandEnv(env []string) []string {
	pagers := []string{"PAGER=cat", "GIT_PAGER=cat", "MANPAGER=cat", "SYSTEMD_PAGER="}
	env = slices.DeleteFunc(slices.Clone(env), func(v string) bool {
		name, _, _ := strings.Cut(v, "=")
		return slices.ContainsFunc(pagers, func(p string) bool { return strings.HasPrefix(p, name+"=") })
	})
	return append(env, pagers...)
}

// terminalEnv is a terminal's environment: the daemon's, $SHELL naming
// shell, without Nushi's own variables, as an agent's is (shellenv.Own): a
// dev daemon started from the terminal (NUSHI_DATA=… make run) must not
// find the installed daemon's data folder or its log there.
func terminalEnv(environ []string, shell string) []string {
	env := slices.DeleteFunc(slices.Clone(environ), func(v string) bool {
		name, _, _ := strings.Cut(v, "=")
		return name == "SHELL" || shellenv.Own(name)
	})
	return append(env, "SHELL="+shell, "TERM=xterm-256color", "COLORTERM=truecolor")
}
