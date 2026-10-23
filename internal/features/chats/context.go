package chats

import (
	"context"
	"errors"
	"slices"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// silentRun is the agent's reply to a prompt Nushi sends on its own in a
// throwaway fork, kept out of the transcript: its messages' text, by
// message id, in order.
type silentRun struct {
	ids  []string
	text map[string]string
}

// ContextUsage runs the agent's command that says what fills its context
// (Dialect.ContextCommand, Claude's /context) without a trace, and returns
// what it answers. It runs while the chat is idle, in a throwaway fork of
// the session (same history, so the same numbers), which is deleted after:
// the agent may keep the answer in a conversation. An agent that can't
// fork isn't asked.
func (s *Service) ContextUsage(ctx context.Context, chatID string) (model.ContextUsage, error) {
	c, err := s.chat(chatID)
	if err != nil {
		return model.ContextUsage{}, err
	}
	cmd := c.dialect.ContextCommand
	c.mu.Lock()
	switch {
	case cmd == "" || !slices.ContainsFunc(c.commands, func(m model.Command) bool { return m.Name == cmd }):
		err = errors.New("the agent can't say what fills its context")
	case !c.canFork || c.parent != nil:
		err = errors.New("the agent can't fork this chat to ask")
	case c.busy || c.agent == nil:
		err = errors.New("the chat is busy")
	}
	agent, sid, folder := c.agent, c.sid, c.session.Folder
	c.mu.Unlock()
	if err != nil {
		return model.ContextUsage{}, err
	}
	fork, _, err := forkSession(ctx, agent, sid, folder, nil)
	if err != nil {
		return model.ContextUsage{}, err
	}
	run := &silentRun{text: map[string]string{}}
	c.mu.Lock()
	c.probes[fork] = run
	c.mu.Unlock()
	defer func() {
		c.throwAway(agent, fork)
		c.mu.Lock()
		delete(c.probes, fork)
		c.mu.Unlock()
	}()
	if err := prompt(ctx, agent, acp.SessionID(fork), "/"+cmd); err != nil {
		return model.ContextUsage{}, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(run.ids) == 0 {
		return model.ContextUsage{}, errors.New("the agent answered nothing")
	}
	var messages []string
	for _, id := range run.ids {
		messages = append(messages, run.text[id])
	}
	return c.dialect.ReadContext(messages), nil
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
	wait, err := agent.StartPrompt(acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}}})
	if err == nil {
		_, err = wait(ctx)
	}
	return err
}
