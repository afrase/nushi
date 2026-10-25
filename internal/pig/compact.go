package pig

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"time"
	"unicode"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/toolcall"
)

// ownCommands are PiG's terminal commands that RPC mode has as commands of
// its own, offered as slash commands: /compact (`compact`, what follows
// being what the summary should keep) and /name (`set_session_name`).
var ownCommands = []acp.AvailableCommand{
	{Name: "compact", Description: "Summarize the conversation to free context", Input: &acp.AvailableCommandInput{Unstructured: &acp.UnstructuredCommandInput{Hint: "what to keep"}}},
	{Name: "name", Description: "Name the session", Input: &acp.AvailableCommandInput{Unstructured: &acp.UnstructuredCommandInput{Hint: "name"}}},
}

// ownCommand reads a prompt that is one of ownCommands: its name, and what
// follows it.
func ownCommand(text string) (name, arg string, ok bool) {
	rest, ok := strings.CutPrefix(strings.TrimSpace(text), "/")
	if !ok {
		return "", "", false
	}
	i := strings.IndexFunc(rest, unicode.IsSpace)
	if i < 0 {
		i = len(rest)
	}
	name = rest[:i]
	for _, c := range ownCommands {
		if c.Name == name {
			return name, strings.TrimSpace(rest[i:]), true
		}
	}
	return "", "", false
}

// runOwn runs one of ownCommands as a turn, after the running one. pig
// starts no run for it, so Stop ends it at once (and pig's abort cancels a
// compaction). A compaction that fails says why in its tool call.
func (s *session) runOwn(ctx context.Context, name, arg string) (*acp.PromptResponse, error) {
	t, err := s.nextTurn(ctx)
	if err != nil {
		return nil, err
	}
	compacted := make(chan struct{})
	if name == "compact" {
		s.mu.Lock()
		t.compactEnd = compacted
		s.mu.Unlock()
	}
	go func() {
		var err error
		switch {
		case name == "compact":
			cmd := map[string]any{"type": "compact"}
			if arg != "" {
				cmd["customInstructions"] = arg
			}
			err = s.p.call(ctx, cmd, nil)
		case arg == "":
			err = errors.New("give the name after /name")
		default:
			err = s.p.call(ctx, map[string]any{"type": "set_session_name", "name": arg}, nil)
		}
		if err != nil && name == "compact" {
			// pig writes compaction_end before its answer, but the answer
			// comes back at once while events wait in line for the pump.
			select {
			case <-compacted:
				err = nil // the compaction's call says why
			case <-s.ended:
			case <-time.After(2 * time.Second):
			}
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		if err != nil {
			s.endLocked(t, nil, err)
			return
		}
		s.endLocked(t, &acp.PromptResponse{StopReason: "end_turn"}, nil)
	}()
	res := <-t.result
	return res.resp, res.err
}

// compactTitle is how a compaction shows, as Claude's does: a tool call.
const compactTitle = "Compact conversation"

// compactionLocked shows a compaction, PiG's own or asked for, as a tool
// call that holds the summary once it's done; after one, how full the
// context is comes from PiG's estimate until the model answers again.
func (s *session) compactionLocked(typ string, raw json.RawMessage) []acp.SessionUpdate {
	if typ == "compaction_start" {
		s.compaction = "compaction-" + strconv.FormatInt(time.Now().UnixMilli(), 10)
		call := acp.ToolCall{ToolCallID: acp.ToolCallID(s.compaction), Title: compactTitle, Kind: "think", Status: "in_progress"}
		return []acp.SessionUpdate{{SessionUpdate: "tool_call", ToolCall: &call}}
	}
	var e struct {
		Result *struct {
			Summary string `json:"summary"`
			After   int64  `json:"estimatedTokensAfter"`
		} `json:"result"`
		Aborted bool   `json:"aborted"`
		Error   string `json:"errorMessage"`
	}
	_ = json.Unmarshal(raw, &e)
	if t := s.turn; t != nil && t.compactEnd != nil {
		close(t.compactEnd)
		t.compactEnd = nil
	}
	u := acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(s.compaction), Status: "failed"}
	switch {
	case e.Result != nil:
		u.Status, u.Content = "completed", toolcall.Text(e.Result.Summary)
		s.estimate = e.Result.After
		go s.b.usage(s)
	case e.Aborted:
		u.Content = toolcall.Text("Compaction cancelled")
	default:
		u.Content = toolcall.Text(e.Error)
	}
	return []acp.SessionUpdate{toolcall.Update(u)}
}

// compacted is a compaction in a replay: done, with its summary.
func compacted(e entry) acp.SessionUpdate {
	call := acp.ToolCall{ToolCallID: acp.ToolCallID("compaction-" + e.ID), Title: compactTitle, Kind: "think", Status: "completed",
		Content: toolcall.Text(e.Summary)}
	return acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &call}
}
