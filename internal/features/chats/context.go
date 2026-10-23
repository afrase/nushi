package chats

import (
	"context"
	"errors"
	"slices"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// silentRun is the agent's reply to a prompt Nushi sends on its own, kept
// out of the transcript: its messages' text, by message id, in order.
type silentRun struct {
	ids  []string
	text map[string]string
	done chan struct{}
}

// ContextUsage runs the agent's /context command without a trace and
// returns what it answers: the prompt and the reply never join the
// transcript, and the chat doesn't turn busy. It runs only while the chat is
// idle, and a prompt sent meanwhile waits for it to end (claude-agent-acp
// answers /context itself, without the model, in a moment).
func (s *Service) ContextUsage(ctx context.Context, chatID string) (string, error) {
	c, err := s.chat(chatID)
	if err != nil {
		return "", err
	}
	c.mu.Lock()
	switch {
	case !slices.ContainsFunc(c.commands, func(cmd model.Command) bool { return cmd.Name == "context" }):
		err = errors.New("the agent has no /context command")
	case c.busy || c.agent == nil || c.silent != nil:
		err = errors.New("the chat is busy")
	}
	if err != nil {
		c.mu.Unlock()
		return "", err
	}
	run := &silentRun{text: map[string]string{}, done: make(chan struct{})}
	c.silent = run
	agent, sid := c.agent, c.sid
	c.mu.Unlock()

	_, err = agent.Prompt(ctx, acp.PromptRequest{SessionID: acp.SessionID(sid),
		Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "/context"}}}})
	c.mu.Lock()
	defer c.mu.Unlock()
	c.silent = nil
	close(run.done)
	if err != nil {
		return "", err
	}
	if len(run.ids) == 0 {
		return "", errors.New("the agent answered nothing")
	}
	// claude-agent-acp 0.94.0 sends the output twice, as two messages.
	return run.text[run.ids[len(run.ids)-1]], nil
}

// silentLocked takes a chunk of the agent's message while a silent run
// goes on; false when there is none.
func (c *chat) silentLocked(m *acp.ContentChunk) bool {
	run := c.silent
	if run == nil || m.Content.Text == nil {
		return false
	}
	id := string(m.MessageID)
	if _, ok := run.text[id]; !ok {
		run.ids = append(run.ids, id)
	}
	run.text[id] += m.Content.Text.Text
	return true
}

// waitSilentLocked waits, with the lock let go meanwhile, until no silent
// run goes on.
func (c *chat) waitSilentLocked() {
	for c.silent != nil {
		done := c.silent.done
		c.mu.Unlock()
		<-done
		c.mu.Lock()
	}
}
