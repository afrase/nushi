package chats

import (
	"context"
	"errors"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// silentRun is the agent's reply to a prompt Nushi sends on its own in a
// throwaway fork (a commit message's), kept out of the transcript: its
// messages' text, by message id, in order.
type silentRun struct {
	ids  []string
	text map[string]string
	// tool, if set, ends the run at the agent's first tool call
	// (commit_message.go).
	tool       func()
	toolCalled bool
}

// ContextUsage asks the agent what fills the chat's context
// (ContextAsker), leaving no trace: no turn, no fork. It asks while the
// chat is idle, of a side chat's session too (ADR 0017).
func (s *Service) ContextUsage(ctx context.Context, chatID string) (model.ContextUsage, error) {
	c, err := s.awakeChat(ctx, chatID)
	if err != nil {
		return model.ContextUsage{}, err
	}
	c.mu.Lock()
	err = c.canAskContextLocked()
	switch {
	case err != nil:
	case c.busyLocked():
		err = errors.New(c.stillLocked())
	case c.agent == nil:
		err = errors.New("the agent isn't running")
	}
	agent, sid := c.agent, c.sid
	c.mu.Unlock()
	if err != nil {
		return model.ContextUsage{}, err
	}
	ctx, cancel := context.WithTimeout(ctx, time.Minute) // an agent alive but silent
	defer cancel()
	return c.kind.contextAsker.Context(ctx, agent.Call, sid)
}

// canAskContextLocked says why the agent can't be asked what fills the
// chat's context, or nil: it needs a way to ask (ContextAsker).
func (c *chat) canAskContextLocked() error {
	if c.kind.contextAsker == nil {
		return errors.New("the agent can't say what fills its context")
	}
	return nil
}

func (run *silentRun) add(m *acp.ContentChunk) {
	id := string(m.MessageID)
	if _, ok := run.text[id]; !ok {
		run.ids = append(run.ids, id)
	}
	run.text[id] += m.Content.Text.Text
}

// prompt sends text to session sid and waits for the turn to end.
func prompt(ctx context.Context, agent Agent, sid acp.SessionID, text string) error {
	wait, err := agent.StartPrompt(ctx, &acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{{Text: &acp.TextContent{Text: text}}}})
	if err == nil {
		_, err = wait(ctx)
	}
	return err
}
