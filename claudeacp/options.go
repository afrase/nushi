package claudeacp

import (
	"encoding/json"
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// setup is what a session request says of how to run claude: session/new's
// fields, and the same in load, resume and fork.
type setup struct {
	cwd          string
	dirs         []string
	mcpServers   []acp.MCPServer
	systemPrompt *acp.SystemPrompt
	meta         map[string]any
}

// sessionOptions are the keys of _meta.claudeCode.options the agent
// applies: the ones Nushi sends, and a few more of the SDK options of the
// same names. Others are logged and ignored.
type sessionOptions struct {
	PerTaskStopAffordance *bool                            `json:"perTaskStopAffordance"`
	ForwardSubagentText   *bool                            `json:"forwardSubagentText"`
	Env                   map[string]string                `json:"env"`
	Settings              json.RawMessage                  `json:"settings"` // an object, or a file's path
	Model                 string                           `json:"model"`
	PermissionMode        string                           `json:"permissionMode"`
	AdditionalDirectories []string                         `json:"additionalDirectories"`
	DisallowedTools       []string                         `json:"disallowedTools"`
	MCPServers            map[string]claudeagent.MCPServer `json:"mcpServers"`
}

var sessionOptionKeys = []string{
	"perTaskStopAffordance", "forwardSubagentText", "env", "settings", "model",
	"permissionMode", "additionalDirectories", "disallowedTools", "mcpServers",
}

// options is how to run claude for a session set up as su.
func (a *agent) options(su setup) (claudeagent.Options, error) {
	if !filepath.IsAbs(su.cwd) {
		return claudeagent.Options{}, invalidParams("cwd %q isn't an absolute path", su.cwd)
	}
	if fi, err := os.Stat(su.cwd); err != nil || !fi.IsDir() {
		return claudeagent.Options{}, invalidParams("cwd %q isn't a folder", su.cwd)
	}
	caps := a.clientCaps()
	o := claudeagent.Options{
		CLIPath: a.cfg.CLIPath, Cwd: su.cwd, Spawner: a.cfg.Spawn, Log: a.cfg.Log,
		// The user's own settings, CLAUDE.md, hooks, skills and MCP
		// servers, as in claude's terminal.
		SettingSources:         []string{"user", "project", "local"},
		IncludePartialMessages: true,
		ReplayUserMessages:     true, // a prompt's turn starts at its echo
		AllowBypass:            os.Geteuid() != 0 || os.Getenv("IS_SANDBOX") != "",
		Init: claudeagent.Init{
			// A cancel then spares background subagents, which the
			// client stops one by one.
			PerTaskStopAffordance: true,
			ForwardSubagentText:   caps.subagents || caps.subagentText,
		},
	}
	if !caps.forms {
		o.DisallowedTools = []string{"AskUserQuestion"} // its questions need a form
	}
	if err := a.applyOptions(&o, su.meta); err != nil {
		return o, err
	}
	o.AddDirs = append(o.AddDirs, su.dirs...)
	for _, s := range su.mcpServers { // over the options' servers of the same name
		name, srv, ok := mcpServer(s)
		if !ok {
			a.log.Warn("an MCP server claude can't run, left out", "type", s.Type)
			continue
		}
		if o.MCPServers == nil {
			o.MCPServers = map[string]claudeagent.MCPServer{}
		}
		o.MCPServers[name] = srv
	}
	if sp := su.systemPrompt; sp != nil {
		var texts []string
		for _, b := range sp.Content {
			if b.Text == nil {
				return o, invalidParams("a system prompt has text blocks only")
			}
			texts = append(texts, b.Text.Text)
		}
		switch text := strings.Join(texts, "\n\n"); sp.Mode {
		case acp.SystemPromptModeOverride:
			o.Init.SystemPrompt = text
		case acp.SystemPromptModeAppend:
			o.Init.AppendSystemPrompt = text
		default:
			return o, invalidParams("no system prompt mode %q", sp.Mode)
		}
	}
	return o, nil
}

// applyOptions applies _meta.claudeCode.options to o.
func (a *agent) applyOptions(o *claudeagent.Options, meta map[string]any) error {
	cc, _ := meta["claudeCode"].(map[string]any)
	raw, _ := cc["options"].(map[string]any)
	if len(raw) == 0 {
		return nil
	}
	for _, k := range slices.Sorted(maps.Keys(raw)) {
		if !slices.Contains(sessionOptionKeys, k) {
			a.log.Info("a session option the agent doesn't apply", "key", k)
		}
	}
	b, err := json.Marshal(raw)
	if err != nil {
		return invalidParams("_meta.claudeCode.options: %v", err)
	}
	var so sessionOptions
	if err := json.Unmarshal(b, &so); err != nil {
		return invalidParams("_meta.claudeCode.options: %v", err)
	}
	if so.PerTaskStopAffordance != nil {
		o.Init.PerTaskStopAffordance = *so.PerTaskStopAffordance
	}
	if so.ForwardSubagentText != nil {
		o.Init.ForwardSubagentText = *so.ForwardSubagentText
	}
	if len(so.Env) > 0 {
		o.Env = withEnv(os.Environ(), so.Env)
	}
	if err := settings(o, so.Settings); err != nil {
		return err
	}
	o.Model = so.Model
	o.PermissionMode = claudeagent.PermissionMode(so.PermissionMode)
	o.AddDirs = so.AdditionalDirectories
	o.DisallowedTools = append(o.DisallowedTools, so.DisallowedTools...)
	o.MCPServers = so.MCPServers
	return nil
}

// settings sets o's flag settings: an object as it is, or a settings
// file's path, relative to the session's folder.
func settings(o *claudeagent.Options, v json.RawMessage) error {
	var path string
	switch {
	case len(v) == 0 || string(v) == "null":
	case json.Unmarshal(v, &path) == nil:
		if !filepath.IsAbs(path) {
			path = filepath.Join(o.Cwd, path)
		}
		o.Settings = json.RawMessage(path) // claude's --settings takes JSON or a path
	case v[0] == '{':
		o.Settings = v
	default:
		return invalidParams("_meta.claudeCode.options.settings is an object or a path")
	}
	return nil
}

// withEnv is env with set's variables, replacing those of the same names.
func withEnv(env []string, set map[string]string) []string {
	out := make([]string, 0, len(env)+len(set))
	for _, kv := range env {
		k, _, _ := strings.Cut(kv, "=")
		if _, ok := set[k]; !ok {
			out = append(out, kv)
		}
	}
	for _, k := range slices.Sorted(maps.Keys(set)) {
		out = append(out, k+"="+set[k])
	}
	return out
}

// mcpServer is an ACP MCP server as claude's: stdio, http or sse. Others
// (an ACP-transport server) claude can't run.
func mcpServer(s acp.MCPServer) (string, claudeagent.MCPServer, bool) {
	headers := func(hs []acp.HTTPHeader) map[string]string {
		m := map[string]string{}
		for _, h := range hs {
			m[h.Name] = h.Value
		}
		return m
	}
	switch {
	case s.Stdio != nil:
		env := map[string]string{}
		for _, e := range s.Stdio.Env {
			env[e.Name] = e.Value
		}
		return s.Stdio.Name, claudeagent.MCPServer{Type: "stdio", Command: s.Stdio.Command, Args: s.Stdio.Args, Env: env}, true
	case s.HTTP != nil:
		return s.HTTP.Name, claudeagent.MCPServer{Type: "http", URL: s.HTTP.URL, Headers: headers(s.HTTP.Headers)}, true
	case s.SSE != nil:
		return s.SSE.Name, claudeagent.MCPServer{Type: "sse", URL: s.SSE.URL, Headers: headers(s.SSE.Headers)}, true
	}
	return "", claudeagent.MCPServer{}, false
}

func invalidParams(format string, args ...any) *acp.Error {
	return &acp.Error{Code: acp.ErrorCodeInvalidParams, Message: fmt.Sprintf(format, args...)}
}
