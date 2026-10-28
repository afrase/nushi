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
	"syscall"

	"golang.org/x/sys/unix"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
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
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/memory"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/features/trust"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/mcpserver"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/npm"
	"github.com/afrase/nushi/internal/omp"
	"github.com/afrase/nushi/internal/omptrust"
	"github.com/afrase/nushi/internal/pig"
	"github.com/afrase/nushi/internal/readonly"
	"github.com/afrase/nushi/internal/shellenv"
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
	slog.Info("nushid started", "version", version(), "build", api.Build, "api", api.Version, "data", dir, "pid", os.Getpid(),
		"log_level", logs.Level.Level())

	hub := &events.Hub{}
	agentSvc := newAgents(dir)
	// The agents found on PATH, and their adapters (ADR 0037). A chat
	// starts its agent through Run, says more through Explain, and asks
	// Run whether it could start (Ready).
	launch := func(name string, start func(agents.Run, acp.Client, *slog.Logger) (*agentproc.Agent, error)) chats.Launch {
		return func(h acp.Client, log *slog.Logger) (chats.Agent, error) {
			run, err := agentSvc.Run(name)
			if err != nil {
				return nil, err
			}
			a, err := start(run, h, log)
			if err != nil {
				return nil, err // not a nil *agentproc.Agent in a chats.Agent
			}
			return a, nil
		}
	}
	ready := func(name string) func() error {
		return func() error { _, err := agentSvc.Run(name); return err }
	}
	// What each agent does beyond ACP is in its own packages: internal/claude*,
	// internal/codex*, internal/ante* (Ante's bridge too, ADR 0030),
	// internal/omp* and internal/pig (PiG's bridge, ADR 0039).
	claudeKind := chats.Kind{Name: "claude", Title: "Claude", Resume: "claude --resume", MCP: true,
		Explain: agentSvc.Explain("claude"), Ready: ready("claude"), Launch: launch("claude", func(r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
			return claude.Start(dir, r.Node, r.Program, r.CLI, r.Env, h, log)
		}),
		Dialect: chats.Dialect{InitMeta: claude.InitMeta, SessionMeta: claude.SessionMeta, UltracodeMeta: claude.UltracodeMeta, TurnDone: claude.TurnDone, ForkAt: claude.ForkAt, Parent: claude.Parent, ToolCall: claude.ToolCall,
			Background: claude.Background, ReportElsewhere: claude.ReportElsewhere,
			Shell: claude.Shell, ReadShell: claude.ReadShell,
			SubagentID: claude.SubagentID, Relay: claude.Relay, Relayed: claude.Relayed, Relaying: claude.Relaying,
			Subagents: claude.Subagents, StopTask: claude.StopTask, StopRelayed: claude.StopRelayed, Stopped: claude.Stopped,
			Other: claude.Other, Default: claude.Default, ForkTitle: claude.ForkTitle, Compacted: claude.Compacted,
			ContextCommand: claude.ContextCommand, ReadContext: claude.ReadContext, Redelete: claude.Redelete, NamesSessions: true},
		History:       func(id, from, to string) (func() error, error) { return claudehistory.Copy(projects, id, from, to) },
		OpenElsewhere: claudehistory.Open, Forked: func(ids []string) map[string]bool { return claudehistory.Forked(projects, ids) },
		Gone: chats.NotFound, HistoryGone: func(sid, folder string) bool { return claudehistory.Gone(projects, sid, folder) },
		Expires: "Claude Code deletes sessions after 30 days by default"}
	codexKind := chats.Kind{Name: "codex", Title: "Codex", Resume: codex.Resume, History: codex.History, DeleteArchives: codex.DeleteArchives, Gone: codex.Gone,
		OpenElsewhere: codex.OpenElsewhere, Forked: codex.Forked, OneWriter: true,
		Explain: agentSvc.Explain("codex"), Ready: ready("codex"), Launch: launch("codex", func(r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
			return codex.Start(dir, r.Node, r.Program, r.CLI, r.Env, h, log)
		}),
		Dialect: chats.Dialect{ForkAt: codex.ForkAt, ToolCall: codex.ToolCall, Other: codex.Other}}
	anteKind := chats.Kind{Name: "ante", Title: "Ante", Resume: ante.Resume, OpenElsewhere: ante.OpenElsewhere,
		Explain: agentSvc.Explain("ante"), Ready: ready("ante"), Launch: launch("ante", func(r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
			return ante.Start(dir, r.Env, h, log)
		}),
		Dialect: chats.Dialect{ForkAt: ante.ForkAt, Other: ante.Other, Context: ante.Context}}
	ompKind := chats.Kind{Name: "omp", Title: "oh-my-pi", Resume: omp.Resume, Forked: omp.Forked, OpenElsewhere: omp.OpenElsewhere, OneWriter: true,
		Explain: agentSvc.Explain("omp"), Ready: ready("omp"), Launch: launch("omp", func(r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
			return omp.Start(dir, r.CLI, r.Env, h, log)
		}),
		Dialect: chats.Dialect{Other: omp.Other, ToolCall: omp.ToolCall}}
	pigKind := chats.Kind{Name: "pig", Title: "PiG", Resume: pig.Resume, Gone: chats.NotFound,
		Explain: agentSvc.Explain("pig"), Ready: ready("pig"), Launch: launch("pig", func(r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
			return pig.Start(dir, r.Env, h, log)
		}),
		Dialect: chats.Dialect{ForkAt: pig.ForkAt, Context: pig.Context}}
	st := store.New(dir)
	st.HadMessages = func(s model.Session) bool { return claudehistory.Has(projects, s.SessionID, s.Folder) }
	kinds := []chats.Kind{claudeKind, codexKind, anteKind, ompKind, pigKind}
	chatSvc := chats.New(kinds, st, st, git.Worktrees{}, filepath.Join(dir, "scratch"), hub.Publish)
	chatSvc.AutoSleep(st)
	copies, err := transcripts.Open(filepath.Join(dir, "transcripts"))
	if err != nil {
		return err
	}
	chatSvc.UseCopies(copies, st.KeepTranscripts)
	chatSvc.AutoClearCopies(st.TranscriptDays)
	termSvc := terminals.New(startShell, filepath.Base(loginShell), chatSvc, hub.Publish)
	chatSvc.UseTerminals(termSvc)
	go hub.Subscribe(nil, func() bool { return true }, func(e model.Event) bool { termSvc.Follow(e); return true })
	agentSvc.UseChats(chatSvc)
	// The API, on the socket for the app (with the token) and on each
	// paired device's channel (ADR 0034).
	logs.SetDebug(st.DebugLog())
	sv := api.Services{Log: st, Transcripts: st, Chats: chatSvc, Agents: agentSvc, MCP: mcp.New(claudemcp.Claude{}, chatSvc.MCPChanged), Skills: newSkills(), Terms: termSvc,
		Trust: trust.New(map[string]trust.Agent{"claude": claudetrust.Trust{}, "codex": codextrust.Trust{}, "ante": antetrust.Trust{}, "omp": omptrust.Trust{}, "pig": pig.Trust{}}, st),
		Hub:   hub, Memory: memory.New(chatSvc)}
	sv.Jira = newJira(st, os.Getenv("NUSHI_DATA") != "")
	sv.GitHub = newGitHub(st, os.Getenv("NUSHI_DATA") != "")
	toolSvc := tools.New(sv.Jira.Tools())
	chatSvc.UseTools(mcpTools(toolSvc, filepath.Join(dir, "nushid.sock")))
	channels := newChannels()
	if sv.Remote, err = remote.New(st, &relay.Dialer{Proxies: sysproxy.For}, channels.serve, keepAwake, hub.Publish); err != nil {
		return err
	}
	chatSvc.UseViewers(sv.Remote)
	if err := usePush(st, sv.Remote, chatSvc, kinds); err != nil {
		return err
	}
	go hub.Subscribe(nil, func() bool { return true }, func(e model.Event) bool { sv.Remote.Follow(e); return true })
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

	// On SIGINT or SIGTERM, or once its app is deleted, stop the agents
	// too: their sessions reopen through session/load when the daemon is
	// back.
	why, err := serve(srv, ln)
	if why != "" {
		slog.Info("nushid stopping", "why", why)
	} else {
		slog.Error("nushid stopping", "why", err)
	}
	sv.Remote.Close()
	_ = remoteSrv.Close() // stopping: nothing is left to tell
	chatSvc.Close()
	termSvc.CloseAll()
	if errors.Is(err, http.ErrServerClosed) {
		slog.Info("nushid stopped")
		return nil
	}
	return err
}

// serve serves the API on ln until SIGINT or SIGTERM, or until the app
// the daemon runs from is deleted (appDeleted), and says why it stopped:
// "" when Serve failed by itself.
func serve(srv *http.Server, ln net.Listener) (string, error) {
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

// newAgents is the agents feature: the agents Nushi knows, found on the
// PATH of the environment they start with (ADR 0048), their adapters set
// up in dir/agents.
func newAgents(dir string) *agents.Service {
	// Agents start with the login shell's environment, read now and when
	// Settings › Agents asks, whatever started the daemon (ADR 0048).
	// NUSHI_SHELL_ENV=off keeps the daemon's own (tests set PATH to their
	// fake agents; the shell's would replace it).
	shellEnv := shellenv.New(knownShell(loginShell), os.Environ())
	if os.Getenv("NUSHI_SHELL_ENV") == "off" {
		shellEnv = shellenv.Off(os.Environ())
	}
	shellEnv.Start()
	probe := func(ctx context.Context, path string, args ...string) ([]byte, error) {
		return readonly.Output(ctx, shellEnv.Environ(), path, args...)
	}
	svc := agents.New([]agents.Agent{
		{Name: "claude", Title: "Claude", CLI: claude.CLI, Page: claude.Page, SignedIn: claude.SignedIn, Tested: claude.Tested,
			Adapter: &agents.Adapter{Lock: claude.Adapter, Package: claude.AdapterPackage, Bin: claude.AdapterBin, Download: claude.AdapterDownload, Disk: claude.AdapterDisk}},
		{Name: "codex", Title: "Codex", CLI: codex.CLI, Page: codex.Page, Tested: codex.Tested,
			Adapter: &agents.Adapter{Lock: codex.Adapter, Package: codex.AdapterPackage, Bin: codex.AdapterBin, Download: codex.AdapterDownload, Disk: codex.AdapterDisk}},
		{Name: "ante", Title: "Ante", CLI: ante.CLI, Also: ante.Also(), Page: ante.Page, Min: ante.Min, Tested: ante.Tested},
		{Name: "omp", Title: "oh-my-pi", CLI: omp.CLI, Page: omp.Page, Needs: omp.Needs, Tested: omp.Tested},
		{Name: "pig", Title: "PiG", CLI: pig.CLI, Page: pig.Page, Tested: pig.Tested},
	}, probe, filepath.Join(dir, "agents"), npm.Installer{Environ: shellEnv.Environ})
	svc.UseEnv(shellEnv)
	return svc
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
