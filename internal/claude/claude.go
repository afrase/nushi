// Package claude knows what Claude Code's ACP adapter (claude-agent-acp
// 0.94.0) does beyond ACP: how to start it, the _meta it reads and sends,
// and its quirks. `main` hands these to the chats feature, which knows
// nothing of Claude. Claude's files are read in claudehistory, claudemcp
// and claudetrust. Nushi's Go agent (claudeacp, `nushid claude-acp`)
// speaks the same dialect and runs instead of the adapter when the daemon
// is told to (goagent.go).
package claude

import (
	"cmp"
	"embed"
	"encoding/json"
	"io/fs"
	"log/slog"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeacp"
	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
)

// Adapter is Claude Code's ACP adapter, as Nushi pins it: adapter/'s
// package.json names the version, its lockfile every package's (make
// adapters writes it again, and says the sizes). Its own Claude Code (an
// optional dependency) is left out: it runs the user's.
var Adapter, _ = fs.Sub(adapterFiles, "adapter")

const (
	AdapterPackage  = "@agentclientprotocol/claude-agent-acp"
	AdapterBin      = "claude-agent-acp"
	AdapterDownload = 8_979_854
	AdapterDisk     = 73_064_448
)

//go:embed adapter
var adapterFiles embed.FS

// Start starts the adapter set up in Nushi's data folder (its program,
// under node, the Node on PATH), running cli, the user's Claude Code, in
// env (the login shell's, ADR 0048). It runs in dir (the daemon's own
// folder); a chat's folder reaches the agent only as the session's cwd.
// Its stderr goes to log.
func Start(dir, node, program, cli string, env []string, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	cmd := exec.Command(node, program) //nolint:gosec,noctx // lives until Stop or Close, not a context; the adapter set up in the data folder (ADR 0037)
	cmd.Dir = dir
	cmd.Env = append(slices.Clone(env), "CLAUDE_CODE_EXECUTABLE="+cli)
	return agentproc.Start(cmd, client, log)
}

// CLI is Claude Code's program, and Page where to get it.
const (
	CLI  = "claude"
	Page = "https://code.claude.com/docs/en/setup"
)

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

// Tested are the Claude Code versions the adapter was run with: its own
// (until milestone Z), then the user's. The Go agent has none: it pins no
// version, and asks claude what it supports.
var Tested = []string{"2.1.303", "2.1.310"}

// SignedIn asks the CLI whether it's signed in (`claude auth status`,
// JSON): "yes" or "no", or "" when it can't say. Claude reads its own
// login for that; Nushi sees only the answer's loggedIn.
func SignedIn(run func(args ...string) ([]byte, error)) string {
	out, err := run("auth", "status", "--json")
	var st struct {
		LoggedIn *bool `json:"loggedIn"`
	}
	if err != nil || json.Unmarshal(out, &st) != nil || st.LoggedIn == nil {
		return ""
	}
	if *st.LoggedIn {
		return "yes"
	}
	return "no"
}

// InitMeta is initialize's client _meta: the adapter then sends a
// subagent's text and thinking too.
var InitMeta = map[string]any{"subagent-transcript": true}

// Subagents says the adapter shows subagents as sessions of their own
// (ACP's subagents RFD) to a client that says it can take them: each
// subagent's end, why it ended, and a stop of its own (session/cancel on
// its session).
const Subagents = true

// SessionMeta is the session requests' _meta, the host options the adapter
// passes Claude Code. perTaskStopAffordance, as Claude Code's terminal has
// it, makes stopping a turn (session/cancel) stop only the turn: without
// it Claude Code's interrupt kills the background subagents too, which no
// update then tells. CLAUDE_CODE_REPORT_FINDINGS in Claude Code's
// environment makes its /code-review report through its ReportFindings
// tool, which the transcript draws as a card, instead of printing JSON.
var SessionMeta = map[string]any{"claudeCode": map[string]any{"options": map[string]any{
	"perTaskStopAffordance": true,
	"env":                   map[string]any{"CLAUDE_CODE_REPORT_FINDINGS": "1"},
}}}

// UltracodeMeta joins SessionMeta for a chat with Ultracode on: Claude
// Code's ultracode (standing multi-agent workflow orchestration) for the
// session, through host options' settings, which the adapter gives Claude
// Code as its programmatic settings (as --settings would). It takes
// effect only with workflows on and a model that supports it; the adapter
// keeps it on across effort changes.
var UltracodeMeta = map[string]any{"claudeCode": map[string]any{"options": map[string]any{
	"settings": map[string]any{"ultracode": true},
}}}

// TurnDone says a usage update is the result of the user's turn: the one
// with the cost, from a model cycle the user started
// (`_claude/origin.kind` "human", not a task notification or a
// subagent's report). The adapter answers the turn's prompt only once the
// background subagents the turn started have ended, and their reports
// have been answered.
func TurnDone(u *acp.UsageUpdate) bool {
	origin, _ := u.Meta["_claude/origin"].(map[string]any)
	return u.Cost != nil && origin["kind"] == "human"
}

// ForkAt says how to fork a session at a message, if the agent is the
// adapter or Nushi's Go agent. ACP's session/fork copies a whole
// conversation; the adapter cuts the copy after an agent message (its ACP
// messageId, the message included) only given a vendor extension meant for
// JetBrains AIR, `_meta.jetbrains.air.fork` (ADR 0020), which the Go agent
// reads too. Drop it when ACP has a standard way.
func ForkAt(init *acp.InitializeResponse) func(messageID string) map[string]any {
	if init.AgentInfo == nil || init.AgentInfo.Name != AdapterPackage && init.AgentInfo.Name != claudeacp.Name {
		return nil
	}
	return func(messageID string) map[string]any {
		return map[string]any{"jetbrains": map[string]any{"air": map[string]any{
			"fork": map[string]any{"version": 1, "messageId": messageID}}}}
	}
}

// Parent reads the subagent tool call an update comes from (the subagent's
// own tool calls, text and thinking), from _meta.claudeCode.
func Parent(meta map[string]any) string { return claudeCode(meta, "parentToolUseId") }

func claudeCode(meta map[string]any, key string) string {
	cc, _ := meta["claudeCode"].(map[string]any)
	s, _ := cc[key].(string)
	return s
}

// ToolCall adds what Claude tells about a tool call: the subagent it comes
// from, its tool's name, for one that starts a subagent (Agent, Task) the
// subagent's type, prompt, model and effort (its input comes in pieces),
// the model it ran on once it has ended, and for a subagent's SubagentHandback, which ends it,
// the report it hands back as its text (Report): true then, since the
// call's own output is only an acknowledgement; for ReportFindings the
// review's findings; for TaskStop the task it stops. Claude may send the
// input in a later update than the name.
func ToolCall(it *model.Item, meta map[string]any, input json.RawMessage) (ownText bool) {
	it.Parent, it.Tool = cmp.Or(it.Parent, Parent(meta)), cmp.Or(claudeCode(meta, "toolName"), it.Tool)
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
	}
	return false
}

// findings reads ReportFindings' input, once it holds the findings: the
// adapter sends it as it grows.
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
func Background(output string) bool { return strings.HasPrefix(output, "Async agent launched") }

// ReportElsewhere says a subagent call's output only points at the
// subagent's report, its SubagentHandback call, which session/load doesn't
// replay.
func ReportElsewhere(output string) bool {
	return strings.HasPrefix(strings.TrimSpace(output), "This agent's report was delivered to you")
}

// Other says field is the free-text "Other" answer that Claude's
// AskUserQuestion form puts after a question: `<id>_custom`.
func Other(field, before model.Field) bool {
	return len(field.Options) == 0 && field.ID == before.ID+"_custom"
}

// Default says v is the model list's "Default (recommended)": Claude
// picks the model then.
func Default(o model.ConfigOption, v model.ConfigValue) bool {
	return o.Category == "model" && strings.HasPrefix(strings.ToLower(v.Name), "default")
}

// ForkTitle says whether title is Claude's for a fork of a session titled
// of: "<title> (fork)", for a fork of a fork "<title> (fork) (fork)".
func ForkTitle(title, of string) bool {
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
func Compacted(it model.Item) bool {
	return it.Kind == model.ToolCall && it.Tool == "compact" ||
		it.Kind == model.UserMessage && strings.HasPrefix(it.Text, summaryStart)
}

// ContextCommand says what fills the context. The adapter answers it
// itself, without the model, but Claude keeps the answer in the
// conversation (ADR 0017).
const ContextCommand = "context"

// ReadContext reads /context's reply: its last message, since the adapter
// sends the output twice, as two messages.
func ReadContext(messages []string) model.ContextUsage {
	md := messages[len(messages)-1]
	cats, _ := Parse(md) // the app shows the markdown when there are none
	return model.ContextUsage{Markdown: md, Categories: cats}
}

// Redelete is how long after deleting a session that nobody will see again
// it is deleted once more: deleting closes it first, but Claude writes a
// little of the session back as it ends.
const Redelete = 3 * time.Second
