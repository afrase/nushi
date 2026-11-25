// Package claude knows what Claude's ACP agent does beyond ACP: how to
// start it, the _meta it reads and sends, and its quirks, as its Harness;
// the chats feature, which knows nothing of Claude, takes that through its
// interfaces. The agent is Nushi's Go agent (claudeacp, `nushid
// claude-acp`, ADR 0066), which keeps the wire shape of claude-agent-acp,
// the Node adapter Claude ran through until 2026-11-04. Claude's files are
// read in claudehistory (whose Local is this Harness with them), claudemcp
// and claudetrust; its settings files' layer is here (settings.go).
package claude

import (
	"cmp"
	"encoding/json"
	"log/slog"
	"math"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
)

// Harness is Claude Code as Nushi runs it, for the chats feature's
// interfaces. Nothing here reads Claude's files: claudehistory.Local adds
// that.
type Harness struct{}

// Info is what Harness is. Claude deletes a session once more 3 seconds on:
// deleting closes it first, but Claude writes a little of the session back
// as it ends. The agent shows subagents as sessions of their own (ACP's
// subagents RFD) to a client that says it can take them: each subagent's
// end, why it ended, its text and thinking, and a stop of its own
// (session/cancel on its session), so Nushi's initialize needs no _meta.
// It asks Claude Code itself that stopping a turn (session/cancel) stop
// only the turn (perTaskStopAffordance, as Claude Code's terminal has it),
// as without it Claude Code's interrupt kills the background tasks too,
// which no update then tells.
//
// Its _meta: SessionMeta is the host options the agent passes Claude Code:
// CLAUDE_CODE_REPORT_FINDINGS in Claude Code's environment makes its
// /code-review report through its ReportFindings tool, which the transcript
// draws as a card, instead of printing JSON. UltracodeMeta is Claude Code's
// ultracode (standing multi-agent workflow orchestration) for the session,
// through host options' settings, which the agent gives Claude Code as its
// programmatic settings (as --settings would): it takes effect only with
// workflows on and a model that supports it, and the agent keeps it on
// across effort changes.
func (Harness) Info() model.HarnessInfo {
	return model.HarnessInfo{Name: "claude", Title: "Claude", Resume: "claude --resume", ClientMCP: true,
		Expires: "Claude Code deletes sessions after 30 days by default", NamesSessions: true, SubagentSessions: true, Redelete: 3 * time.Second, Moves: true,
		OtherSuffix: "_custom",        // AskUserQuestion's free text after a question
		OtherNotes:  model.NotesOnOne, // claude-acp-go's `answered`: a note on one pick, one more answer to several
		SessionMeta: map[string]any{"claudeCode": map[string]any{"options": map[string]any{
			"env": map[string]any{"CLAUDE_CODE_REPORT_FINDINGS": "1"},
		}}},
		UltracodeMeta: map[string]any{"claudeCode": map[string]any{"options": map[string]any{
			"settings": map[string]any{"ultracode": true},
		}}}}
}

// Start starts Nushi's Go agent (start.go), running r's CLI, the user's
// Claude Code, in r's environment (the login shell's, ADR 0048). It runs in
// dir (the daemon's own folder); a chat's folder reaches the agent only as
// the session's cwd. Its stderr goes to log.
func (Harness) Start(dir string, r model.AgentRun, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	cmd, err := goCommand(dir, r.CLI, Environ(r.Env))
	if err != nil {
		return nil, err
	}
	return agentproc.Start(cmd, client, log)
}

// TodoTools is the variable that turns on Claude Code's to-do list (its
// task tools, TaskCreate and the rest) for the current models: without it
// Claude keeps no plan, so the agent sends none (docs/facts/claude.md).
const TodoTools = "CLAUDE_CODE_ENABLE_TODO_TOOLS"

// Environ is env, the user's agent environment, with what Nushi adds for
// Claude Code: TodoTools on, unless env sets it, so a user's own value
// stands. It goes in the agent's process environment rather than the
// session's _meta, whose env the agent lays over its own: it passes both
// on to claude.
func Environ(env []string) []string {
	env = slices.Clone(env)
	for _, kv := range env {
		if k, _, _ := strings.Cut(kv, "="); k == TodoTools {
			return env
		}
	}
	return append(env, TodoTools+"=1")
}

// CLI is Claude Code's program.
const CLI = "claude"

// ConfigDir is Claude Code's config folder: $CLAUDE_CONFIG_DIR, else
// ~/.claude. As every agent's folder, it is read from the daemon's own
// environment.
func ConfigDir() string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return dir
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude")
}

// ConfigFile is Claude's own config file, which holds user and local MCP
// servers and the folders trusted: $CLAUDE_CONFIG_DIR/.claude.json, else
// ~/.claude.json (beside ~/.claude, not in it).
func ConfigFile() string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return filepath.Join(dir, ".claude.json")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude.json")
}

// UserSettings is your settings file: settings.json in the config folder.
func UserSettings() string { return filepath.Join(ConfigDir(), "settings.json") }

// SignedIn asks the CLI whether it's signed in (`claude auth status`,
// JSON): "yes" or "no", or "" when it can't say. Claude reads its own
// login for that; Nushi sees only the answer's loggedIn. Signed out, it
// exits 1 after printing its answer (docs/facts/claude.md), so the answer
// is read whatever the exit; one that didn't start or was stopped printed
// none.
func SignedIn(run func(args ...string) ([]byte, error)) string {
	out, _ := run("auth", "status", "--json")
	var st struct {
		LoggedIn *bool `json:"loggedIn"`
	}
	if json.Unmarshal(out, &st) != nil || st.LoggedIn == nil {
		return ""
	}
	if *st.LoggedIn {
		return "yes"
	}
	return "no"
}

// ReadOnlyMode is Claude's plan mode (docs/facts/claude.md).
func (Harness) ReadOnlyMode() string { return "plan" }

// OwnTurnEnded says a usage update ends Claude's own turn: its result's,
// the one with the cost. Claude sends one without after each model call
// in the turn too (claude-acp-go's contextUsed).
func (Harness) OwnTurnEnded(u *acp.UsageUpdate) bool { return u.Cost != nil }

// ForkAt says how to fork a session at a message. ACP's session/fork
// copies a whole conversation; Nushi's Go agent cuts the copy after an
// agent message (its ACP messageId, the message included) given the
// vendor extension claude-agent-acp took from JetBrains AIR,
// `_meta.jetbrains.air.fork` (ADR 0020), from any client. The harness
// starts only that agent, so init isn't asked. Drop it when ACP has a
// standard way.
func (Harness) ForkAt(*acp.InitializeResponse) func(messageID string) map[string]any {
	return func(messageID string) map[string]any {
		return map[string]any{"jetbrains": map[string]any{"air": map[string]any{
			"fork": map[string]any{"version": 1, "messageId": messageID}}}}
	}
}

// Parent reads the subagent tool call an update comes from (the subagent's
// own tool calls, text and thinking), from _meta.claudeCode.
func (Harness) Parent(meta map[string]any) string { return claudeCode(meta, "parentToolUseId") }

// Sent reads when a replayed message was sent: the _meta.claudeCode.timestamp
// claude-acp-go (v0.8.0 on) puts on the first chunk of each message
// session/load replays, the user's or the agent's (a thought's, when the
// message begins with thinking), from the transcript record's own
// timestamp. Zero when the chunk has none or it is no time.
func (Harness) Sent(meta map[string]any) time.Time {
	at, err := time.Parse(time.RFC3339Nano, claudeCode(meta, "timestamp"))
	if err != nil {
		return time.Time{}
	}
	return at
}

// Gone says a session/load error means Claude no longer has the session:
// the agent answers ACP's "Resource not found".
func (Harness) Gone(err error) bool { return agentproc.NotFound(err) }

func claudeCode(meta map[string]any, key string) string {
	cc, _ := meta["claudeCode"].(map[string]any)
	s, _ := cc[key].(string)
	return s
}

// ToolCall adds what Claude tells about a tool call: the subagent it comes
// from, its tool's name, for one that starts a subagent (Agent, Task) the
// subagent's type, prompt, model and effort (its input comes in pieces),
// the model it ran on and the worktree it had once it has ended, and for a subagent's SubagentHandback, which ends it,
// the report it hands back as its text (Report): true then, since the
// call's own output is only an acknowledgement; for ReportFindings the
// review's findings; for TaskStop the task it stops; for Workflow the run
// it launched; for an MCP tool's call, its server and tool, from the
// tool's name or, for a call that came without it (an ask, a copy saved
// before Nushi read them), its title, which is the same name. Claude may
// send the input in a later update than the name.
func (h Harness) ToolCall(it *model.Item, meta map[string]any, input json.RawMessage) (ownText bool) {
	it.Parent, it.Tool = cmp.Or(it.Parent, h.Parent(meta)), cmp.Or(claudeCode(meta, "toolName"), it.Tool)
	if server, tool := mcpName(cmp.Or(it.Tool, it.Title)); server != "" {
		it.MCPServer, it.MCPTool = server, tool
	}
	var in struct {
		Type       string `json:"subagent_type"`
		Prompt     string `json:"prompt"`
		Model      string `json:"model"`
		Effort     string `json:"effort"`
		Message    string `json:"message"`
		To         string `json:"to"`
		TaskID     string `json:"task_id"`
		Background bool   `json:"run_in_background"`
	}
	_ = json.Unmarshal(input, &in)
	cc, _ := meta["claudeCode"].(map[string]any)
	resp, _ := cc["toolResponse"].(map[string]any)
	switch it.Tool {
	case "Bash":
		it.InBackground = it.InBackground || in.Background
		if id, _ := resp["backgroundTaskId"].(string); id != "" {
			it.TaskID = id
		}
	case "Agent", "Task":
		it.Agent = cmp.Or(in.Type, it.Agent, "Agent")
		it.Prompt, it.Model, it.Effort = cmp.Or(in.Prompt, it.Prompt), cmp.Or(in.Model, it.Model), cmp.Or(in.Effort, it.Effort)
		if m, _ := resp["resolvedModel"].(string); m != "" {
			it.RanModel = modelName(m)
		}
		if id, _ := resp["agentId"].(string); id != "" {
			it.AgentID = id
		}
		if p, _ := resp["worktreePath"].(string); p != "" { // a foreground subagent's only (docs/facts/claude.md)
			it.WorktreePath = p
		}
		if t := totals(resp); t != nil {
			it.Totals = t
		}
	case "SendMessage": // to a subagent, by the agent's id for it
		it.AgentID = cmp.Or(in.To, it.AgentID)
	case "TaskStop": // a subagent's or a background command's task, by its id
		it.Stops = cmp.Or(in.TaskID, it.Stops)
	case "SubagentHandback":
		it.Text, it.Report = cmp.Or(in.Message, it.Text), true
		return true
	case "ReportFindings":
		if f := findings(input); f != nil {
			it.Findings = f
		}
	case "Workflow": // a run in the background (ADR 0127); chats follows it
		if w := workflowCall(resp); w != nil && it.Workflow == nil {
			it.Workflow, it.TaskID = w, w.TaskID
		}
	}
	return false
}

// totals reads what an Agent call's toolResponse says its subagent used,
// as its last update brings it (docs/facts/claude.md): nil without them.
// JSON's numbers come as float64.
func totals(resp map[string]any) *model.Totals {
	ms, okMs := resp["totalDurationMs"].(float64)
	tokens, okTokens := resp["totalTokens"].(float64)
	if !okMs && !okTokens {
		return nil
	}
	return &model.Totals{Duration: time.Duration(ms) * time.Millisecond, Tokens: int64(tokens)}
}

// findings reads ReportFindings' input, once it holds the findings: the
// agent sends it as it grows.
func findings(input json.RawMessage) *model.Findings {
	var in struct {
		Level    string `json:"level"`
		Findings *[]struct {
			File            string `json:"file"`
			Line            int    `json:"line"`
			Summary         string `json:"summary"`
			ShortSummary    string `json:"short_summary"`
			FailureScenario string `json:"failure_scenario"`
			Category        string `json:"category"`
			Verdict         string `json:"verdict"`
			Outcome         string `json:"outcome"`
		} `json:"findings"`
	}
	if json.Unmarshal(input, &in) != nil || in.Findings == nil {
		return nil
	}
	out := &model.Findings{Level: in.Level, Items: []model.Finding{}}
	for _, f := range *in.Findings {
		if f.Line < 0 || f.Line > math.MaxInt32 {
			f.Line = 0 // not a line
		}
		out.Items = append(out.Items, model.Finding{File: f.File, Line: f.Line, Summary: f.Summary,
			ShortSummary: f.ShortSummary, FailureScenario: f.FailureScenario, Category: f.Category, Verdict: f.Verdict, Outcome: f.Outcome})
	}
	return out
}

// modelName names a model id as Claude's model picker does:
// "claude-sonnet-5-5" is "Sonnet 5.5"; a date suffix and a context tag
// ("[1m]") go.
func modelName(id string) string {
	id, _, _ = strings.Cut(strings.TrimPrefix(id, "claude-"), "[")
	var words, version []string
	for p := range strings.SplitSeq(id, "-") {
		switch _, err := strconv.Atoi(p); {
		case err != nil && p != "":
			words = append(words, strings.ToUpper(p[:1])+p[1:])
		case len(p) <= 2:
			version = append(version, p)
		}
	}
	return strings.TrimSpace(strings.Join(words, " ") + " " + strings.Join(version, "."))
}

// Background says an Agent call's output tells that Claude started the
// subagent in the background: it then completes the call at once, and the
// subagent runs until its SubagentHandback.
func (Harness) Background(output string) bool {
	return strings.HasPrefix(output, "Async agent launched")
}

// ReportElsewhere says a subagent call's output only points at the
// subagent's report, its SubagentHandback call, which session/load doesn't
// replay.
func (Harness) ReportElsewhere(output string) bool {
	return strings.HasPrefix(strings.TrimSpace(output), "This agent's report was delivered to you")
}

// Default says v is the model list's "Default (recommended)": Claude
// picks the model then.
func (Harness) Default(o model.ConfigOption, v model.ConfigValue) bool {
	return o.Category == "model" && strings.HasPrefix(strings.ToLower(v.Name), "default")
}

// ForkTitle says whether title is Claude's for a fork of a session titled
// of: "<title> (fork)", for a fork of a fork "<title> (fork) (fork)".
func (Harness) ForkTitle(title, of string) bool {
	rest, ok := strings.CutPrefix(title, of)
	return ok && rest != "" && strings.Trim(strings.ReplaceAll(rest, " (fork)", ""), " ") == ""
}

// summaryStart is how the summary Claude Code writes when it compacts a
// conversation begins; Claude's replay of a compacted session starts with
// it, as a user message, and replays only what follows.
const summaryStart = "This session is being continued from a previous conversation"

// Compacted says an item is part of a compaction of the conversation: its
// call while it runs (/compact, or Claude's own), or the summary a replay
// after one starts with. Neither call nor command is replayed.
func (Harness) Compacted(it model.Item) bool {
	return it.Kind == model.ToolCall && it.Tool == "compact" ||
		it.Kind == model.UserMessage && strings.HasPrefix(it.Text, summaryStart)
}
