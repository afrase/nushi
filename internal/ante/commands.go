package ante

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"strings"
	"time"
	"unicode"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/toolcall"
)

// skill is one the user can run in the session, as Ante lists them
// (SessionStart, ExtensionRefreshed): each is a slash command, run with
// the SlashCommand op.
type skill struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Hint        string `json:"argument_hint"`
}

// ownCommands are the bridge's own slash commands, which Ante's protocol
// has ops for: they never reach the model.
var ownCommands = []acp.AvailableCommand{
	{Name: "model", Description: "Show the model, or switch to another from the next turn on", Input: hint("model id")},
	{Name: "effort", Description: "Show the effort, or set it from the next turn on", Input: hint("level")},
	{Name: "compact", Description: "Summarize the conversation to free context", Input: hint("what to keep")},
}

func hint(h string) *acp.AvailableCommandInput {
	if h == "" {
		return nil
	}
	return &acp.AvailableCommandInput{Unstructured: &acp.UnstructuredCommandInput{Hint: h}}
}

// slash reads a prompt that starts with a slash command: its name, and
// what follows it.
func slash(text string) (name, arg string, ok bool) {
	rest, ok := strings.CutPrefix(strings.TrimSpace(text), "/")
	if !ok {
		return "", "", false
	}
	i := strings.IndexFunc(rest, unicode.IsSpace)
	if i < 0 {
		i = len(rest)
	}
	if i == 0 {
		return "", "", false
	}
	return rest[:i], strings.TrimSpace(rest[i:]), true
}

func isOwn(name string) bool {
	return slices.ContainsFunc(ownCommands, func(c acp.AvailableCommand) bool { return c.Name == name })
}

// commandsLocked is the session's slash commands: the bridge's own, then
// its skills (one named like one of the bridge's is left out).
func (s *session) commandsLocked() acp.SessionUpdate {
	cmds := slices.Clone(ownCommands)
	for _, sk := range s.info.Skills {
		if !isOwn(sk.Name) {
			cmds = append(cmds, acp.AvailableCommand{Name: sk.Name, Description: sk.Description, Input: hint(sk.Hint)})
		}
	}
	return acp.SessionUpdate{SessionUpdate: "available_commands_update", AvailableCommandsUpdate: &acp.AvailableCommandsUpdate{AvailableCommands: cmds}}
}

// commands tells the client the session's slash commands once it knows
// the session: a new one's id comes in the answer, a moment later.
func (b *bridge) commands(s *session, known bool) {
	if !known {
		time.Sleep(afterAnswer)
	}
	s.mu.Lock()
	u := s.commandsLocked()
	s.mu.Unlock()
	b.update(s.id, u)
}

// afterAnswer is about how long the client takes to know a session it got
// in an answer, so it doesn't drop the session's first updates.
const afterAnswer = 200 * time.Millisecond

// refreshedLocked takes the skills an ExtensionRefreshed lists.
func (s *session) refreshedLocked(ev event) {
	var p struct {
		Skills []skill `json:"skills"`
	}
	if json.Unmarshal(ev.Payload, &p) == nil && p.Skills != nil {
		s.info.Skills = p.Skills
	}
}

// opOf is the op that runs a prompt: a skill's command runs the skill
// (Ante sends its instructions, the arguments in them, to the model),
// /compact compacts, anything else is the user's input.
func (s *session) opOf(text string) any {
	if name, arg, ok := slash(text); ok {
		s.mu.Lock()
		skill := slices.ContainsFunc(s.info.Skills, func(sk skill) bool { return sk.Name == name })
		s.mu.Unlock()
		switch {
		case name == "compact":
			c := map[string]any{}
			if arg != "" {
				c["instructions"] = arg
			}
			return map[string]any{"Compact": c}
		case skill && !isOwn(name):
			return map[string]any{"SlashCommand": map[string]any{"name": name, "args": arg}}
		}
	}
	return map[string]any{"UserInput": text}
}

// setting runs /model or /effort as a turn of its own, after the running
// one: with no argument it says the current value, else it changes it
// (UpdateSession, from the next turn on) and says the new one.
func (s *session) setting(ctx context.Context, name, arg string) (*acp.PromptResponse, error) {
	t, err := s.next(ctx)
	if err != nil {
		return nil, err
	}
	reply, err := s.change(ctx, name, arg)
	if err == nil {
		s.b.update(s.id, chunk(false, reply, acp.MessageID("cmd-"+t.id)))
	}
	s.mu.Lock()
	if err != nil {
		s.endLocked(t, nil, err)
	} else {
		s.endLocked(t, &acp.PromptResponse{StopReason: "end_turn"}, nil)
	}
	s.mu.Unlock()
	r := <-t.result
	return r.resp, r.err
}

func (s *session) change(ctx context.Context, name, arg string) (string, error) {
	s.mu.Lock()
	in := s.info
	efforts := s.b.efforts(in)
	s.mu.Unlock()
	model := map[string]any{"id": in.Model.ID}
	switch {
	case name == "model" && arg == "":
		return "Model: " + in.Model.ID, nil
	case name == "model":
		model["id"] = arg
	case len(efforts) == 0 && arg == "":
		return in.Model.ID + " takes no effort setting", nil
	case len(efforts) == 0:
		return "", fmt.Errorf("%s takes no effort setting", in.Model.ID)
	case arg == "":
		return "Effort: " + in.Model.Effort, nil
	case !slices.Contains(efforts, arg): // Ante answers an unknown one with an Error for no op
		return "", fmt.Errorf("no effort %q: %s takes %s", arg, in.Model.ID, strings.Join(efforts, ", "))
	default:
		model["effort"] = arg
	}
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	ev, err := s.await(ctx, map[string]any{"UpdateSession": map[string]any{"model": model}}, "SessionUpdated")
	if err != nil {
		return "", err
	}
	var now info // what the event says: the session takes it after the waiter
	_ = json.Unmarshal(ev.Payload, &now)
	if name == "model" {
		return "Model: " + now.Model.ID, nil
	}
	return "Effort: " + now.Model.Effort, nil
}

// compactTitle is how a compaction shows, as Claude's does: a tool call.
const compactTitle = "Compact conversation"

// compactionLocked shows a compaction (/compact's, or Ante's own) as a
// tool call that holds the summary once done. /compact's ends with its
// info block's line (over), which says why when nothing was compacted or
// it failed.
func (s *session) compactionLocked(ev event) (out []acp.SessionUpdate, over bool) {
	id := acp.ToolCallID("compact-" + ev.Parent)
	switch ev.Name {
	case "CompactStart":
		s.compact = compaction{id: id}
		call := acp.ToolCall{ToolCallID: id, Title: compactTitle, Kind: "think", Status: "in_progress"}
		return []acp.SessionUpdate{{SessionUpdate: "tool_call", ToolCall: &call}}, false
	case "CompactEnd":
		var p struct {
			Summary *string `json:"summary"`
		}
		_ = json.Unmarshal(ev.Payload, &p)
		u := acp.ToolCallUpdate{ToolCallID: id, Status: "failed"}
		if p.Summary != nil {
			u.Status, u.Content = "completed", toolcall.Text(*p.Summary)
			s.compact.done = true
		}
		return []acp.SessionUpdate{toolcall.Update(u)}, false
	}
	var p struct {
		ID     string `json:"id"`
		Detail string `json:"detail"`
	}
	_ = json.Unmarshal(ev.Payload, &p)
	if acp.ToolCallID(p.ID) != id {
		return nil, false
	}
	switch {
	case s.compact.id != id: // nothing to compact
		out = []acp.SessionUpdate{chunk(false, p.Detail, acp.MessageID("cmd-"+ev.Parent))}
	case !s.compact.done: // failed: why
		out = []acp.SessionUpdate{toolcall.Update(acp.ToolCallUpdate{ToolCallID: id, Status: "failed", Content: toolcall.Text(p.Detail)})}
	}
	return out, true
}

// compaction is the last compaction the session showed.
type compaction struct {
	id   acp.ToolCallID
	done bool // with a summary
}
