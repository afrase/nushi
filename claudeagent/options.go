package claudeagent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
)

// PermissionMode is how claude asks before it uses a tool.
type PermissionMode string

// The permission modes claude knows; it may know more.
const (
	PermissionDefault PermissionMode = "default" // ask, as the settings say ("Manual")
	AcceptEdits       PermissionMode = "acceptEdits"
	Plan              PermissionMode = "plan"
	Auto              PermissionMode = "auto"
	BypassPermissions PermissionMode = "bypassPermissions"
	DontAsk           PermissionMode = "dontAsk"
)

// Thinking is how the model thinks before it answers.
type Thinking struct {
	Type         string // "adaptive", "enabled" or "disabled"
	BudgetTokens int    // for "enabled"; 0 means adaptive
	Display      string // "summarized", "omitted"…; "" = claude's default
}

// MCPServer is an MCP server claude starts or connects to for the session.
type MCPServer struct {
	Type    string            `json:"type"` // "stdio", "http" or "sse"
	Command string            `json:"command,omitempty"`
	Args    []string          `json:"args,omitempty"`
	Env     map[string]string `json:"env,omitempty"`
	URL     string            `json:"url,omitempty"`
	Headers map[string]string `json:"headers,omitempty"`
}

// Options says how to run claude. The zero value runs the claude on PATH
// in the current folder with claude's own defaults.
type Options struct {
	CLIPath string   // "" = claude, looked up on Env's PATH
	Cwd     string   // "" = this process's
	Env     []string // nil = os.Environ(); edited as the package doc says

	Model, FallbackModel, Effort string
	PermissionMode               PermissionMode // "" = claude decides, from the settings
	AllowBypass                  bool           // lets the session switch to BypassPermissions
	Resume                       string         // a session id to continue
	SessionID                    string         // the new session's id
	ForkSession                  bool           // with Resume: continue in a new session
	ResumeSessionAt              string         // with Resume: the message to resume after
	SettingSources               []string       // nil = every source; empty = none
	Settings                     json.RawMessage
	MCPServers                   map[string]MCPServer
	AddDirs                      []string
	AllowedTools                 []string
	DisallowedTools              []string
	Tools                        []string // nil = the default set; empty = none
	Thinking                     *Thinking
	MaxTurns                     int
	IncludePartialMessages       bool // StreamEvent messages as the model writes
	ReplayUserMessages           bool // claude echoes the user messages it takes
	// ExtraArgs passes flags the options don't name: --key=value, or
	// --key for a nil value.
	ExtraArgs map[string]*string

	// Init is what the initialize request carries.
	Init Init

	// CanUseTool answers claude's permission requests; without it claude
	// asks no one and decides by its settings.
	CanUseTool func(ctx context.Context, r PermissionRequest) (PermissionResult, error)

	// Stderr takes each line claude writes on stderr; nil = the log. It
	// runs on the reading goroutine, and claude's exit is reported only
	// once stderr is read through, so it should return promptly.
	Stderr    func(line string)
	ClientApp string       // names the app in claude's User-Agent, e.g. "nushi/0.9"
	MaxLine   int          // the longest stdout line read; 0 = 128 MiB
	Spawner   Spawner      // nil = Exec
	Log       *slog.Logger // nil = no log
}

// defaultMaxLine is the stdout line cap: a tool result with images can
// run to tens of MiB, and a line over the cap is lost.
const defaultMaxLine = 128 << 20

// args is claude's command line (after its name) for o. Values go in the
// --flag=value form, so one starting with "-" can't be read as a flag;
// JSON goes in an argument of its own, as the official SDKs pass it. There
// is no -p: claude doesn't run interactively when its stdout isn't a
// terminal, and the SDKs rely on that too.
func args(o Options) ([]string, error) {
	if o.FallbackModel != "" && o.FallbackModel == o.Model {
		return nil, errors.New("claudeagent: the fallback model is the model")
	}
	a := []string{"--output-format", "stream-json", "--verbose", "--input-format", "stream-json"}
	if o.CanUseTool != nil {
		a = append(a, "--permission-prompt-tool=stdio") // asks come to us as can_use_tool requests
	}
	flag := func(name, value string) {
		if value != "" {
			a = append(a, "--"+name+"="+value)
		}
	}
	on := func(name string, set bool) {
		if set {
			a = append(a, "--"+name)
		}
	}
	list := func(name string, values []string) {
		if values != nil {
			a = append(a, "--"+name+"="+strings.Join(values, ","))
		}
	}
	flag("model", o.Model)
	flag("fallback-model", o.FallbackModel)
	flag("effort", o.Effort)
	flag("permission-mode", string(o.PermissionMode))
	on("allow-dangerously-skip-permissions", o.AllowBypass)
	flag("resume", o.Resume)
	flag("session-id", o.SessionID)
	on("fork-session", o.ForkSession)
	flag("resume-session-at", o.ResumeSessionAt)
	list("setting-sources", o.SettingSources)
	if len(o.Settings) > 0 {
		a = append(a, "--settings", string(o.Settings))
	}
	if len(o.MCPServers) > 0 {
		config, err := json.Marshal(map[string]any{"mcpServers": o.MCPServers})
		if err != nil {
			return nil, fmt.Errorf("claudeagent: MCP servers: %w", err)
		}
		a = append(a, "--mcp-config", string(config))
	}
	for _, d := range o.AddDirs {
		flag("add-dir", d)
	}
	if len(o.AllowedTools) > 0 {
		list("allowedTools", o.AllowedTools)
	}
	if len(o.DisallowedTools) > 0 {
		list("disallowedTools", o.DisallowedTools)
	}
	list("tools", o.Tools)
	if t := o.Thinking; t != nil {
		switch {
		case t.Type == "disabled":
			a = append(a, "--thinking=disabled")
		case t.Type == "enabled" && t.BudgetTokens > 0:
			a = append(a, "--max-thinking-tokens="+strconv.Itoa(t.BudgetTokens))
		default:
			a = append(a, "--thinking=adaptive")
		}
		if t.Type != "disabled" {
			flag("thinking-display", t.Display)
		}
	}
	if o.MaxTurns > 0 {
		flag("max-turns", strconv.Itoa(o.MaxTurns))
	}
	on("include-partial-messages", o.IncludePartialMessages)
	on("replay-user-messages", o.ReplayUserMessages)
	for _, k := range slices.Sorted(maps.Keys(o.ExtraArgs)) {
		if err := extraArg(k); err != nil {
			return nil, err
		}
		if v := o.ExtraArgs[k]; v != nil {
			a = append(a, "--"+k+"="+*v)
		} else {
			a = append(a, "--"+k)
		}
	}
	return a, nil
}

// extraArg refuses a key that isn't a flag's name, and the flags that
// would change what the package relies on: print mode's own, and --bare,
// which would drop the user's login, CLAUDE.md, hooks and skills.
func extraArg(k string) error {
	switch {
	case k == "" || strings.HasPrefix(k, "-") || strings.ContainsAny(k, "= \t\n"):
		return fmt.Errorf("claudeagent: %q isn't a flag's name", k)
	case k == "bare" || k == "print" || k == "p" || k == "input-format" || k == "output-format":
		return fmt.Errorf("claudeagent: --%s can't be set: the package sets how claude runs", k)
	}
	return nil
}

// environ is claude's environment for o.
//
//   - CLAUDECODE goes, so claude doesn't take itself for one run inside
//     Claude Code; NODE_OPTIONS too, which isn't meant for it.
//   - What says an official SDK runs it goes (CLAUDE_AGENT_SDK_VERSION),
//     and so does what says this host refreshes tokens: it never does.
//   - CLAUDE_CODE_ENTRYPOINT is sdk-cli unless set: claude's own value for
//     a run in print mode with no official SDK.
//   - CLAUDE_CODE_EMIT_SESSION_STATE_EVENTS turns on SessionState messages.
//   - CLAUDE_AGENT_SDK_CLIENT_APP names the app in claude's User-Agent.
//   - PWD is Cwd, when set.
func environ(o Options) []string {
	base := o.Env
	if base == nil {
		base = os.Environ()
	}
	drop := map[string]bool{
		"CLAUDECODE": true, "NODE_OPTIONS": true, "CLAUDE_AGENT_SDK_VERSION": true,
		"CLAUDE_CODE_SDK_HAS_OAUTH_REFRESH": true, "CLAUDE_CODE_SDK_HAS_HOST_AUTH_REFRESH": true,
	}
	set := map[string]string{"CLAUDE_CODE_EMIT_SESSION_STATE_EVENTS": "1"}
	keep := map[string]string{ // unless the environment has them
		"CLAUDE_CODE_ENTRYPOINT":      "sdk-cli",
		"CLAUDE_AGENT_SDK_CLIENT_APP": "claudeagent-go/" + Version,
	}
	if o.ClientApp != "" {
		set["CLAUDE_AGENT_SDK_CLIENT_APP"] = o.ClientApp
		delete(keep, "CLAUDE_AGENT_SDK_CLIENT_APP")
	}
	if o.Cwd != "" {
		set["PWD"] = o.Cwd
	}
	env := make([]string, 0, len(base)+len(set)+len(keep))
	for _, kv := range base {
		k, _, _ := strings.Cut(kv, "=")
		if drop[k] {
			continue
		}
		if _, ok := set[k]; ok {
			continue
		}
		delete(keep, k)
		env = append(env, kv)
	}
	for _, m := range []map[string]string{set, keep} {
		for _, k := range slices.Sorted(maps.Keys(m)) {
			env = append(env, k+"="+m[k])
		}
	}
	return env
}

// spec is how to start claude for o.
func spec(o Options) (Spec, error) {
	a, err := args(o)
	if err != nil {
		return Spec{}, err
	}
	env := environ(o)
	path := o.CLIPath
	if path == "" {
		path = "claude"
	}
	if !strings.ContainsRune(path, filepath.Separator) {
		if path, err = lookPath(path, getenv(env, "PATH")); err != nil {
			return Spec{}, err
		}
	}
	return Spec{Path: path, Args: a, Env: env, Dir: o.Cwd}, nil
}

// lookPath finds the program name on path, a PATH list: exec.LookPath
// reads this process's PATH, and claude's environment may have another.
func lookPath(name, path string) (string, error) {
	for _, dir := range filepath.SplitList(path) {
		if dir == "" || !filepath.IsAbs(dir) {
			continue // a relative PATH entry would resolve against our folder, not claude's
		}
		p := filepath.Join(dir, name)
		if fi, err := os.Stat(p); err == nil && fi.Mode().IsRegular() && fi.Mode()&0o111 != 0 {
			return p, nil
		}
	}
	return "", fmt.Errorf("claudeagent: %s isn't on PATH", name)
}

// getenv is key's value in env, the last one set.
func getenv(env []string, key string) string {
	for _, kv := range slices.Backward(env) {
		if k, v, ok := strings.Cut(kv, "="); ok && k == key {
			return v
		}
	}
	return ""
}
