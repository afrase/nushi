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

// ContextUsage runs the agent's /context command without a trace and
// returns what it answers. It runs while the chat is idle, in a throwaway
// fork of the session (same history, so the same numbers), which is closed
// and deleted after: Claude keeps /context's answer in a conversation. An
// agent that can't fork isn't asked.
func (s *Service) ContextUsage(ctx context.Context, chatID string) (string, error) {
	c, err := s.chat(chatID)
	if err != nil {
		return "", err
	}
	c.mu.Lock()
	switch {
	case !slices.ContainsFunc(c.commands, func(cmd model.Command) bool { return cmd.Name == "context" }):
		err = errors.New("the agent has no /context command")
	case !c.canFork || c.parent != nil:
		err = errors.New("the agent can't fork this chat to ask")
	case c.busy || c.agent == nil:
		err = errors.New("the chat is busy")
	}
	agent, sid, folder := c.agent, c.sid, c.session.Folder
	c.mu.Unlock()
	if err != nil {
		return "", err
	}
	return c.contextInFork(ctx, agent, sid, folder)
}

// answer is the run's last message: claude-agent-acp 0.94.0 sends
// /context's output twice, as two messages.
func (run *silentRun) answer() (string, error) {
	if len(run.ids) == 0 {
		return "", errors.New("the agent answered nothing")
	}
	return run.text[run.ids[len(run.ids)-1]], nil
}

// contextInFork runs /context in a fork of session sid, whose updates go
// to a silent run (see probe), then closes and deletes the fork.
func (c *chat) contextInFork(ctx context.Context, agent Agent, sid, folder string) (string, error) {
	resp, err := agent.ForkSession(ctx, acp.ForkSessionRequest{SessionID: acp.SessionID(sid), Cwd: folder, MCPServers: []acp.MCPServer{}})
	if err != nil {
		return "", err
	}
	fork := resp.SessionID
	run := &silentRun{text: map[string]string{}}
	c.mu.Lock()
	c.probes[string(fork)] = run
	c.mu.Unlock()
	defer func() {
		throwAway(agent, fork)
		c.mu.Lock()
		delete(c.probes, string(fork))
		c.mu.Unlock()
	}()
	if err := prompt(ctx, agent, fork, "/context"); err != nil {
		return "", err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return run.answer()
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
