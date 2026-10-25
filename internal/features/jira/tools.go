package jira

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/model"
)

// Tools is Jira's tool set for a chat's agent: its issue only, never
// another or a search across the site. What the agent may do with them
// is its harness's to ask (ADR 0007); Nushi asks nothing more.
func (s *Service) Tools() tools.Set { return toolSet{s} }

type toolSet struct{ s *Service }

func schema(props string, required ...string) json.RawMessage {
	req, _ := json.Marshal(required) // a list of strings
	if len(required) == 0 {
		req = []byte("[]")
	}
	return json.RawMessage(`{"type":"object","properties":{` + props + `},"required":` + string(req) + `,"additionalProperties":false}`)
}

const keyProp = `"key":{"type":"string","description":"The issue's key; only this chat's issue is allowed."}`

// named is the chat's issue for the agent: its key, and its summary as it
// was when the chat started, quoted and on one line.
func named(is *model.ChatIssue) string {
	summary := strings.Join(strings.Fields(is.Summary), " ")
	if summary == "" {
		return is.Key
	}
	if r := []rune(summary); len(r) > 200 {
		summary = string(r[:200]) + "…"
	}
	return fmt.Sprintf("%s (%q)", is.Key, summary)
}

// Instructions say which issue the chat works on: with no message in the
// box, this is how the agent knows.
func (t toolSet) Instructions(g tools.Grant) string {
	if g.Issue == nil {
		return ""
	}
	k := g.Issue.Key
	text := "This chat works on Jira issue " + named(g.Issue)
	if u := t.s.Browse(g.Issue.Site, k); u != "" {
		text += ", " + u
	}
	return text + ". jira_issue reads it, with its recent comments; jira_comment comments on it and jira_transition moves it, " +
		"when the user asks. These tools reach " + k + " only."
}

func (t toolSet) Tools(g tools.Grant) []tools.Tool {
	if g.Issue == nil {
		return nil
	}
	k, this := g.Issue.Key, named(g.Issue)+", the Jira issue this chat works on"
	return []tools.Tool{
		{Name: "jira_issue", Description: "Reads " + this + ": its fields, description, acceptance criteria, recent comments, links and subtasks, as Markdown.",
			InputSchema: schema(keyProp)},
		{Name: "jira_comment", Description: "Adds a comment to " + this + ". The comment is Markdown.",
			InputSchema: schema(keyProp+`,"body":{"type":"string","description":"The comment, in Markdown."}`, "body")},
		{Name: "jira_transitions", Description: "Lists the moves " + k + "'s workflow allows now (to which status), and the fields each needs; " + this + ".",
			InputSchema: schema(keyProp)},
		{Name: "jira_transition", Description: "Moves " + this + " through one of the moves jira_transitions lists, by its id or name.",
			InputSchema: schema(keyProp+`,"transition":{"type":"string","description":"The move's id or name."},`+
				`"fields":{"type":"object","additionalProperties":{"type":"string"},"description":"Values for the fields the move needs, by field id."}`, "transition")},
	}
}

func (t toolSet) Call(ctx context.Context, g tools.Grant, tool string, raw json.RawMessage) (string, error) {
	var args struct {
		Key        string            `json:"key"`
		Body       string            `json:"body"`
		Transition string            `json:"transition"`
		Fields     map[string]string `json:"fields"`
	}
	if len(raw) > 0 {
		if err := json.Unmarshal(raw, &args); err != nil {
			return "", fmt.Errorf("arguments: %w", err)
		}
	}
	is := g.Issue
	if is == nil {
		return "", errors.New("this chat isn't on a Jira issue")
	}
	if args.Key != "" && !strings.EqualFold(args.Key, is.Key) {
		return "", fmt.Errorf("this chat's Jira tools are for %s only", is.Key)
	}
	by := g.Agent + " in chat " + g.Chat
	switch tool {
	case "jira_issue":
		md, _, err := t.s.Context(ctx, is.Site, is.Key)
		return md, err
	case "jira_comment":
		c, err := t.s.AddComment(ctx, is.Site, is.Key, args.Body, by)
		if err != nil {
			return "", err
		}
		t.s.wrote(model.JiraWrite{Site: is.Site, Key: is.Key, Kind: "comment", Comment: c.ID, Chat: g.Chat, Agent: g.Agent})
		return "Comment added to " + is.Key + ".", nil
	case "jira_transitions":
		ts, err := t.s.Transitions(ctx, is.Site, is.Key)
		if err != nil {
			return "", err
		}
		if len(ts) == 0 {
			return is.Key + " has no moves now.", nil
		}
		return movesText(ts), nil
	case "jira_transition":
		ts, err := t.s.Transitions(ctx, is.Site, is.Key)
		if err != nil {
			return "", err
		}
		id := args.Transition
		for _, tr := range ts {
			if strings.EqualFold(tr.Name, args.Transition) {
				id = tr.ID
			}
		}
		tr, err := t.s.Transition(ctx, is.Site, is.Key, id, args.Fields, by)
		if err != nil {
			return "", err
		}
		t.s.wrote(model.JiraWrite{Site: is.Site, Key: is.Key, Kind: "move", To: tr.To, Chat: g.Chat, Agent: g.Agent})
		return is.Key + " moved to " + tr.To + ".", nil
	}
	return "", fmt.Errorf("no tool %q", tool)
}

// movesText lists moves for the agent: id, name, status, and each field
// with its options.
func movesText(ts []model.JiraTransition) string {
	var b strings.Builder
	for _, tr := range ts {
		fmt.Fprintf(&b, "- %s: %s (to %s)", tr.ID, tr.Name, tr.To)
		for _, f := range tr.Fields {
			fmt.Fprintf(&b, "; field %s %q (%s)", f.ID, f.Name, f.Type)
			if f.Required {
				b.WriteString(" required")
			}
			for _, o := range f.Options {
				fmt.Fprintf(&b, ", option %s %q", o.ID, o.Name)
			}
		}
		b.WriteString("\n")
	}
	return b.String()
}
