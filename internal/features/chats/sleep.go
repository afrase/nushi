package chats

import (
	"context"
	"errors"
	"log/slog"
	"maps"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// A chat sleeps when its agent was stopped to free its memory: it stays
// where it is, its transcript too, and whatever needs the agent wakes it,
// through session/load as after a daemon restart. Only an agent that can
// reopen sessions sleeps.

// Sleep stops a chat's agent as Archive does (a running turn is stopped,
// side chats end), keeping the chat as it is.
func (s *Service) Sleep(chatID string) error {
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	err = c.canSleepLocked()
	if err == nil {
		c.asleep, c.before = true, slices.Clone(c.config)
	}
	c.mu.Unlock()
	if err != nil {
		return err
	}
	s.stop(c)
	c.mu.Lock()
	defer c.mu.Unlock()
	c.statusChangedLocked()
	return nil
}

func (c *chat) canSleepLocked() error {
	switch {
	case c.agent == nil:
		return errors.New("the chat's agent isn't running")
	case !c.canLoad:
		return errors.New("the agent can't reopen its sessions, so it can't sleep")
	case c.reopeningLocked():
		return errReopening
	}
	return c.closedLocked()
}

// SleepPrefs keeps how long a chat idles before its agent sleeps.
type SleepPrefs interface {
	SleepAfter() time.Duration // 0: never
	SetSleepAfter(time.Duration) error
}

// sleepCheck is how often idle chats are looked for.
var sleepCheck = time.Minute

// AutoSleep puts chats to sleep once they have idled as long as prefs say,
// from now on, until Close.
func (s *Service) AutoSleep(prefs SleepPrefs) {
	s.prefs = prefs
	go func() {
		tick := time.NewTicker(sleepCheck)
		defer tick.Stop()
		for range tick.C {
			s.mu.Lock()
			closing, open := s.closing, slices.Collect(maps.Values(s.chats))
			s.mu.Unlock()
			if closing {
				return
			}
			if after := prefs.SleepAfter(); after > 0 {
				for _, c := range open {
					s.doze(c, after)
				}
			}
		}
	}()
}

// SleepAfter is how long a chat idles before its agent sleeps; 0: never.
func (s *Service) SleepAfter() time.Duration {
	if s.prefs == nil {
		return 0
	}
	return s.prefs.SleepAfter()
}

// SetSleepAfter sets how long a chat idles before its agent sleeps.
func (s *Service) SetSleepAfter(d time.Duration) error {
	if s.prefs == nil {
		return errors.New("chats don't sleep here")
	}
	return s.prefs.SetSleepAfter(d)
}

// doze puts a chat to sleep if nothing happened in it for after and
// nothing would be lost (see idleLocked). Its agent is let go under the
// lock, so a message that comes while it stops wakes the chat on a new one
// (load waits for the old one to end first).
func (s *Service) doze(c *chat, after time.Duration) {
	c.mu.Lock()
	if !c.idleLocked(after) {
		c.mu.Unlock()
		return
	}
	agent := c.agent
	c.asleep, c.before, c.retired = true, slices.Clone(c.config), agent.Done()
	c.agent, c.kept = nil, len(c.items) > 0
	c.statusChangedLocked()
	c.mu.Unlock()
	if err := agent.Stop(stopGrace); err != nil {
		c.log().Warn("stopping the agent to sleep", "err", err)
	}
}

// idleLocked says the chat has been idle for after and that stopping its
// agent loses nothing: no turn runs or waits on the user, nothing is
// queued, no background command or subagent runs, no side chat is open,
// and nothing moves, rewinds or reopens it.
func (c *chat) idleLocked(after time.Duration) bool {
	return c.parent == nil && c.canSleepLocked() == nil && time.Since(c.active) >= after &&
		!c.busy && c.started.IsZero() && !c.ownTurn && !c.steering && c.sendingNow == 0 &&
		len(c.queue) == 0 && len(c.waiting)+len(c.questions) == 0 && len(c.sides) == 0 && len(c.probes) == 0 &&
		!slices.ContainsFunc(c.items, func(it model.Item) bool {
			return it.Shell != nil && it.Shell.State == "running" || it.Subagent != nil && it.Subagent.State == "running"
		})
}

// awake wakes a sleeping chat for something that needs its agent, and
// waits until it has reopened (or failed to: the chat says why).
func (s *Service) awake(ctx context.Context, c *chat) error {
	c.mu.Lock()
	if c.asleep {
		c.asleep, c.reopenFailed = false, false
		s.reopenLocked(c)
	}
	woke := c.woke
	c.mu.Unlock()
	if woke != nil {
		select {
		case <-woke:
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	return nil
}

// restoreConfig sets a woken chat's options back to what they were before
// it slept (the model, the effort), where the agent reopened the session
// with others; startMode sees to the mode.
func (c *chat) restoreConfig(ctx context.Context, agent Agent, sid string, before []model.ConfigOption) {
	for _, o := range before {
		c.mu.Lock()
		i := slices.IndexFunc(c.config, func(n model.ConfigOption) bool { return n.ID == o.ID })
		set := o.Category != "mode" && i >= 0 && c.config[i].Current != o.Current &&
			(c.config[i].Type == "boolean" || slices.ContainsFunc(c.config[i].Values, func(v model.ConfigValue) bool { return v.Value == o.Current }))
		c.mu.Unlock()
		if set {
			if err := c.setConfig(ctx, agent, sid, o.ID, o.Current); err != nil {
				c.log().Warn("setting an option back after sleeping", "option", o.ID, "err", err)
			}
		}
	}
}

// AgentPids returns the process of each chat's running agent, by chat id
// (side chats share their chat's).
func (s *Service) AgentPids() map[string]int {
	s.mu.Lock()
	open := slices.Collect(maps.Values(s.chats))
	s.mu.Unlock()
	pids := map[string]int{}
	for _, c := range open {
		c.mu.Lock()
		if c.agent != nil && c.parent == nil && c.agent.Pid() > 0 {
			pids[c.id] = c.agent.Pid()
		}
		c.mu.Unlock()
	}
	return pids
}

// awakeOf returns the chats of the agent named agent whose agent runs
// (side chats are their chat's).
func (s *Service) awakeOf(agent string) []string {
	s.mu.Lock()
	open := slices.Collect(maps.Values(s.chats))
	s.mu.Unlock()
	var ids []string
	for _, c := range open {
		c.mu.Lock()
		if c.agent != nil && c.parent == nil && c.kind.Name == agent {
			ids = append(ids, c.id)
		}
		c.mu.Unlock()
	}
	return ids
}

// Awake counts the chats of the agent named agent whose agent runs.
func (s *Service) Awake(agent string) int { return len(s.awakeOf(agent)) }

// SleepAgent puts every awake chat of the agent named agent to sleep, as
// Sleep does, before its program changes; one that can't sleep (it's
// reopening) is left.
func (s *Service) SleepAgent(agent string) {
	for _, id := range s.awakeOf(agent) {
		if err := s.Sleep(id); err != nil {
			slog.Warn("chat not put to sleep", "chat", id, "err", err)
		}
	}
}
