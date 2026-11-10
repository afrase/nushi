package chats

import (
	"context"
	"errors"
	"slices"

	"github.com/afrase/nushi/internal/model"
)

// offered is cmds, the commands the agent lists or listed last, without
// those it can't run for Nushi (CommandHider).
func (k *kind) offered(cmds []model.Command) []model.Command {
	if k.commandHider == nil {
		return cmds
	}
	return slices.DeleteFunc(slices.Clone(cmds), func(c model.Command) bool { return k.commandHider.HidesCommand(c.Name) })
}

// withTerminalCommands is cmds, the commands the agent lists, with those of
// its terminal Nushi runs in its place (TerminalCommands) that it doesn't.
func (k *kind) withTerminalCommands(cmds []model.Command) []model.Command {
	if k.terminalCmds == nil {
		return cmds
	}
	out := slices.Clone(cmds)
	for _, tc := range k.terminalCmds.TerminalCommands() {
		if !slices.ContainsFunc(out, func(c model.Command) bool { return c.Name == tc.Name }) {
			out = append(out, tc)
		}
	}
	return out
}

// RunsCommand says Prompt runs m in the agent's place, as a command of its
// terminal (TerminalCommands), rather than sending it as it is: no user
// message of its text shows.
func (s *Service) RunsCommand(chatID string, m model.Message) bool {
	_, _, ok := s.terminalCommandOf(chatID, m)
	return ok
}

// terminalCommandOf reads m as a command of the chat's agent's terminal
// that Nushi runs; a message to a subagent never is one.
func (s *Service) terminalCommandOf(chatID string, m model.Message) (*chat, model.OptionCommand, bool) {
	if m.To != "" {
		return nil, model.OptionCommand{}, false
	}
	c, err := s.chat(chatID)
	if err != nil || c.kind.terminalCmds == nil {
		return nil, model.OptionCommand{}, false
	}
	cmd, ok := c.kind.terminalCmds.TerminalCommand(m.Text)
	return c, cmd, ok
}

// terminalCommand runs m, a prompt that is one of the agent's terminal's
// commands (TerminalCommands), here, for every client alike: it sets the
// option as the chat's menu does (SetConfig: the agent's own call, and a
// mode remembered for the agent), leaves the command's notice, then sends
// the prompt that follows the command as any message, with m's files and
// images. With the option set already, the prompt goes alone, and a
// command with none only gets its notice. An agent without the option gets
// m as it is.
func (s *Service) terminalCommand(ctx context.Context, c *chat, m model.Message, cmd model.OptionCommand, how Send) error {
	rest := m
	rest.Text = cmd.Prompt
	sends := rest.Text != "" || len(rest.Files) > 0 || len(rest.Images) > 0
	c.mu.Lock()
	err := s.refusesLocked(c)
	if err == nil && sends && how == SendIdle && c.busy && !c.reopeningLocked() { // as prompt would, before the option changes
		err = errors.New("the agent is still working on the last prompt")
	}
	c.mu.Unlock()
	if err == nil {
		err = s.awake(ctx, c)
	}
	if err != nil {
		return err
	}
	c.mu.Lock()
	i := slices.IndexFunc(c.config, func(o model.ConfigOption) bool { return o.Category == cmd.Category })
	var opt model.ConfigOption
	if i >= 0 {
		opt = c.config[i]
	}
	already := i >= 0 && opt.Current == cmd.Value
	if already && !sends {
		c.noticeLocked("command", cmd.Already)
	}
	c.mu.Unlock()
	switch {
	case i < 0:
		return s.prompt(ctx, c.id, m, how)
	case !already:
		if err := s.SetConfig(ctx, c.id, opt.ID, cmd.Value); err != nil {
			return err
		}
		c.mu.Lock()
		c.noticeLocked("command", cmd.Set)
		c.mu.Unlock()
	}
	if !sends {
		return nil
	}
	return s.prompt(ctx, c.id, rest, how)
}
