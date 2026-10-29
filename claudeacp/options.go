package claudeacp

import (
	"fmt"
	"os"
	"path/filepath"

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
	o.AddDirs = su.dirs
	return o, nil
}

func invalidParams(format string, args ...any) *acp.Error {
	return &acp.Error{Code: acp.ErrorCodeInvalidParams, Message: fmt.Sprintf(format, args...)}
}
