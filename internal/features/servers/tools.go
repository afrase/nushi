package servers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/launchfile"
	"github.com/afrase/nushi/internal/model"
)

// The agent's dev server tools (ADR 0100), on Nushi's MCP server beside
// show, Claude desktop's names: preview_list, preview_start, preview_stop
// and preview_logs. They name an entry of the chat's folder's launch files
// by its name, never a command (ADR 0098's rule), and carry no annotations:
// the harness asks before each, and the ask's card shows the command the
// entry runs (Command).

// AgentTools is the tool set. It's made before the service, whose chats
// take the tools, and given it with Use, before any agent can call.
type AgentTools struct{ s *Service }

// Use gives the set the service.
func (t *AgentTools) Use(s *Service) { t.s = s }

// Bounds of what an agent asks for.
const (
	defaultLogLines = 100
	maxLogLines     = 500
	maxLogBytes     = 32 << 10
)

// Instructions say what the tools are for: Claude's MCP tools are
// deferred, so without them it may not look.
func (t *AgentTools) Instructions(tools.Grant) string {
	if t.s == nil {
		return ""
	}
	return "preview_list lists the dev servers this chat's folder configures in its launch files (.agents/launch.json, .claude/launch.json). " +
		"preview_start and preview_stop run and stop one by its name, and preview_logs reads its output. " +
		"A server you start opens beside the chat once it answers."
}

// nameSchema is an entry's name, as preview_start, _stop and _logs take it.
const nameSchema = `"name":{"type":"string","maxLength":64,"description":"The server's name in the launch file (preview_list)."}`

// Tools is the four, with no annotations on purpose (ADR 0068's reason:
// a readOnlyHint could let a harness run one unasked).
func (t *AgentTools) Tools(tools.Grant) []tools.Tool {
	if t.s == nil {
		return nil
	}
	return []tools.Tool{
		{Name: "preview_list", Description: "Lists the dev servers this chat's folder configures in .agents/launch.json and .claude/launch.json: each one's name, state, port and URL.",
			InputSchema: json.RawMessage(`{"type":"object","properties":{},"additionalProperties":false}`)},
		{Name: "preview_start", Description: "Starts a dev server of this chat's folder's launch files by its name, on a free port, and waits a while for it to answer. " +
			"Once it answers, its page opens in a browser tab beside the chat. A server that already runs is left as it is.",
			InputSchema: json.RawMessage(`{"type":"object","properties":{` + nameSchema + `},"required":["name"],"additionalProperties":false}`)},
		{Name: "preview_stop", Description: "Stops a running dev server of this chat's folder, by its name.",
			InputSchema: json.RawMessage(`{"type":"object","properties":{` + nameSchema + `},"required":["name"],"additionalProperties":false}`)},
		{Name: "preview_logs", Description: "Reads a dev server's output (running, or the last run), as plain text: its last lines, 100 unless you ask for up to 500.",
			InputSchema: json.RawMessage(`{"type":"object","properties":{` + nameSchema +
				`,"lines":{"type":"integer","minimum":1,"maximum":500,"description":"How many of its last lines; 100 when not given."}},"required":["name"],"additionalProperties":false}`)},
	}
}

// toolError is a tool's failure: text for the agent, which may quote its
// folder's launch files or its server's words; kind, fixed, for the log
// (tools.Logged).
type toolError struct{ kind, text string }

func (e toolError) Error() string  { return e.text }
func (e toolError) Logged() string { return e.kind }

// Logged is a refused start's kind, for the log (tools.Logged): its text
// may quote the launch file.
func (e *StartError) Logged() string { return e.Kind }

// The tools' refusals of what the agent sent, each fixed text: nothing it
// sends reaches the log. Claude desktop's codes lead where it has one
// (docs/facts/claude.md).
var (
	errToolArgs = errors.New("the arguments must be an object of name (a string) and, for preview_logs, lines (a whole number)")
	errToolName = errors.New("name must be a launch file entry's name: a letter or digit, then letters, digits, ':', '_', '.' or '-', 64 at most")
	errLines    = fmt.Errorf("lines must be a whole number from 1 to %d", maxLogLines)
	errNotFound = errors.New("launch_config_name_not_found: no server of that name in this folder's launch files; preview_list lists them")
)

// Call runs one of the four for the grant's chat (a side chat's is its
// chat's, as for show).
func (t *AgentTools) Call(ctx context.Context, g tools.Grant, tool string, raw json.RawMessage) (string, error) {
	var args struct {
		Name  *string `json:"name"`
		Lines *int    `json:"lines"`
	}
	if err := tools.Decode(raw, &args, "name", "lines"); err != nil {
		return "", errToolArgs
	}
	if tool == "preview_list" {
		return t.list(g.Chat)
	}
	if args.Name == nil || !launchfile.ValidName(*args.Name) {
		return "", errToolName
	}
	name := *args.Name
	switch tool {
	case "preview_start":
		return t.start(ctx, g.Chat, name)
	case "preview_stop":
		return t.stop(g.Chat, name)
	case "preview_logs":
		lines := defaultLogLines
		if args.Lines != nil {
			lines = *args.Lines
		}
		if lines < 1 || lines > maxLogLines {
			return "", errLines
		}
		return t.logs(g.Chat, name, lines)
	}
	return "", errToolArgs
}

// listed is a row as preview_list gives it.
type listed struct {
	Name    string `json:"name"`
	State   State  `json:"state"`
	Port    int    `json:"port,omitempty"`
	URL     string `json:"url,omitempty"`
	Source  string `json:"source"`
	Attach  bool   `json:"attach,omitempty"` // a server already running at url: nothing to start
	Problem string `json:"problem,omitempty"`
	Error   string `json:"error,omitempty"`
	Changed bool   `json:"changed,omitempty"` // its entry changed since it started: a restart applies it
}

// list is the folder's servers as JSON; an entry whose name isn't fit
// for the agent's text is only counted (the user runs it from the
// Servers menu).
func (t *AgentTools) list(chat string) (string, error) {
	l, err := t.s.List(chat)
	if err != nil {
		return "", toolError{"the launch files can't be read", "the launch files can't be read: " + err.Error()}
	}
	out := struct {
		Servers []listed `json:"servers"`
		Hidden  int      `json:"unnamed,omitempty"`
		Note    string   `json:"note,omitempty"`
	}{Servers: []listed{}}
	for _, r := range l.Rows {
		if !r.NameOK {
			out.Hidden++
			continue
		}
		out.Servers = append(out.Servers, listed{Name: r.Name, State: r.State, Port: r.Port, URL: r.URL, Source: r.Source.Path,
			Attach: r.Attach, Problem: r.Problem, Error: r.Error, Changed: r.Changed})
	}
	switch {
	case len(l.Files) == 0:
		out.Note = "launch_config_missing: this folder has no .agents/launch.json or .claude/launch.json"
	case out.Hidden > 0:
		out.Note = "entries whose names aren't fit to show are counted as unnamed: the user runs them from the Servers menu"
	}
	b, _ := json.Marshal(out) // strings and numbers
	return string(b), nil
}

// named is the row of a chat's folder's entry (or server whose entry is
// gone) called name, without case, among those whose names are fit.
func (t *AgentTools) named(chat, name string) (Row, error) {
	l, err := t.s.List(chat)
	if err != nil {
		return Row{}, toolError{"the launch files can't be read", "the launch files can't be read: " + err.Error()}
	}
	i := slices.IndexFunc(l.Rows, func(r Row) bool { return r.NameOK && strings.EqualFold(r.Name, name) })
	if i < 0 {
		return Row{}, errNotFound
	}
	return l.Rows[i], nil
}

// start starts the entry of name, as the card that asked showed it if
// one did, and waits StartWait for it to answer or fail.
func (t *AgentTools) start(ctx context.Context, chat, name string) (string, error) {
	r, err := t.s.Start(ctx, chat, Pick{Name: name, Hash: t.s.takeAsked(chat, name), Agent: true})
	var refused *StartError
	switch {
	case errors.As(err, &refused) && refused.Kind == "no such entry":
		return "", errNotFound
	case errors.As(err, &refused) && refused.Kind == "the entry changed":
		return "", toolError{refused.Kind, "the launch file changed since the permission card showed this server's command: call preview_start again"}
	case err != nil:
		return "", err
	}
	r = t.s.settle(ctx, r)
	where := fmt.Sprintf("port %d (%s)", r.Port, r.URL)
	switch r.State {
	case Running:
		return fmt.Sprintf("%s runs on %s. Its page opens beside the chat.", r.Name, where), nil
	case Starting, NotAnswering:
		return fmt.Sprintf("%s started on %s but hasn't answered yet. preview_list says when it does, preview_logs shows its output; its page opens beside the chat once it answers.", r.Name, where), nil
	case Stopped, Failed:
	}
	text := r.Name + " failed"
	if r.Error != "" {
		text += ": " + r.Error
	}
	if r.Output != "" {
		text += "\n\nIts last lines:\n" + lastLines([]byte(r.Output), 30, 4<<10)
	}
	return "", toolError{"the server failed", text}
}

// stop stops the running server of name, the agent's doing.
func (t *AgentTools) stop(chat, name string) (string, error) {
	r, err := t.named(chat, name)
	if err != nil {
		return "", err
	}
	sv := t.s.find(r.ServerID)
	if sv == nil {
		return r.Name + " isn't running.", nil
	}
	t.s.stop(sv, ByAgent)
	return "Stopped " + r.Name + ".", nil
}

// logs is the last lines of name's output, running or its last run.
func (t *AgentTools) logs(chat, name string, lines int) (string, error) {
	r, err := t.named(chat, name)
	if err != nil {
		return "", err
	}
	if r.LogID == "" {
		return "", toolError{"no output kept", r.Name + " has no output kept: it hasn't run in this folder since Nushi's daemon started"}
	}
	sv, err := t.s.logged(chat, r.LogID)
	if err != nil {
		return "", toolError{"no output kept", r.Name + " has no output kept any more"}
	}
	text := t.s.tail(sv, lines, maxLogBytes)
	if text == "" {
		text = "(no output)"
	}
	return fmt.Sprintf("%s (%s), its last %d lines at most:\n%s", r.Name, r.State, lines, text), nil
}

// settle waits up to StartWait, or until ctx ends, for a server Start
// started to answer or end, and returns its row as it then is.
func (s *Service) settle(ctx context.Context, r Row) Row {
	deadline := time.After(s.StartWait)
	tick := time.NewTicker(100 * time.Millisecond)
	defer tick.Stop()
	for {
		s.mu.Lock()
		state := Stopped
		if sv := s.server(r.ServerID); sv != nil {
			state = sv.state
			if sv.port != 0 {
				r.Port, r.URL = sv.port, sv.url
			}
			r.Error, r.Output = sv.err, sv.output
		}
		s.mu.Unlock()
		r.State = state
		if state != Starting {
			return r
		}
		select {
		case <-ctx.Done():
			return r
		case <-deadline:
			return r
		case <-tick.C:
		}
	}
}

// server is the live or ended server of id; under the lock.
func (s *Service) server(id string) *server {
	if i := slices.IndexFunc(s.alive, func(sv *server) bool { return sv.id == id }); i >= 0 {
		return s.alive[i]
	}
	if i := slices.IndexFunc(s.ended, func(sv *server) bool { return sv.id == id }); i >= 0 {
		return s.ended[i]
	}
	return nil
}

// showAsked asks the Mac to show a page beside a chat, as the agent's
// show would (ADR 0068's rules, in the app): a server its agent started,
// once it answers (ADR 0100).
func (s *Service) showAsked(chatID, url string) {
	if chatID != "" && url != "" && s.Publish != nil {
		s.Publish(model.Event{ChatID: chatID, ShowURL: url})
	}
}
