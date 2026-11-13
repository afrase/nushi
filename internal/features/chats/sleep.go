package chats

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"time"
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
		c.asleep = true
	}
	c.mu.Unlock()
	if err != nil {
		return err
	}
	s.stop(c)
	c.mu.Lock()
	defer c.mu.Unlock()
	c.statusChangedLocked()
	c.logLocked().Info("chat asleep", "why", "asked")
	c.letGoLocked()
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

// autoSleep puts chats to sleep once they have idled as long as the
// service's prefs say, until the service's life ends.
func (s *Service) autoSleep() {
	tick := time.NewTicker(s.timing.sleepCheck())
	defer tick.Stop()
	for {
		select {
		case <-tick.C:
		case <-s.ctx.Done():
			return
		}
		open := s.openChats()
		if after := s.prefs.SleepAfter(); after > 0 {
			for _, c := range open {
				s.doze(c, after)
			}
		}
	}
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
// (load waits for the old one to end first: retire).
func (s *Service) doze(c *chat, after time.Duration) {
	c.mu.Lock()
	if !c.idleLocked(after) {
		c.mu.Unlock()
		return
	}
	agent := c.agent
	c.asleep, c.retiring = true, agent
	c.agent, c.kept = nil, len(c.items) > 0
	c.statusChangedLocked()
	c.logLocked().Info("chat asleep", "why", "idle", "after", after)
	c.mu.Unlock()
	if err := agent.Stop(s.timing.stopGrace()); err != nil {
		c.log().Warn("stopping the agent to sleep", "err", err)
	}
	c.mu.Lock()
	c.letGoLocked() // once its agent's last updates are in
	c.mu.Unlock()
}

// retire waits for old, the agent the chat fell asleep from (nil: none),
// to have ended before another agent opens its session: two processes
// writing one session corrupt the agent's own history, the source of truth
// (ADR 0047). doze's Stop gives it StopGrace and then kills it; one still
// running at twice that is killed again here (Close, its process group),
// and one that outlives that too keeps the chat from reopening, saying so,
// and is waited for again by the next reopen. A message sent meanwhile
// waits in the queue.
func (c *chat) retire(ctx context.Context, old Agent) error {
	if old == nil {
		return nil
	}
	ended := func(wait time.Duration) (bool, error) {
		select {
		case <-old.Done():
			return true, nil
		case <-ctx.Done():
			return false, ctx.Err()
		case <-time.After(wait):
			return false, nil
		}
	}
	done, err := ended(2 * c.timing.stopGrace())
	if !done && err == nil {
		c.log().Warn("the agent the chat slept from outlived its stop: killing it", "pid", old.Pid())
		_ = old.Close()
		done, err = ended(c.timing.stopGrace())
	}
	switch {
	case err != nil:
		return err
	case !done:
		return fmt.Errorf("the agent this chat slept from is still running (process %d), so its session can't reopen until it ends", old.Pid())
	}
	c.mu.Lock()
	if c.retiring == old {
		c.retiring = nil
	}
	c.mu.Unlock()
	return nil
}

// idleLocked says the chat has been idle for after and that stopping its
// agent loses nothing (quietLocked), with no side chat open.
func (c *chat) idleLocked(after time.Duration) bool {
	return c.parent == nil && c.canSleepLocked() == nil && time.Since(c.active) >= after &&
		len(c.sides) == 0 && c.quietLocked()
}

// quietLocked says stopping the chat's agent loses nothing: no turn runs
// or waits on the user, nothing is queued (the queue lives only in the
// daemon), no background command or subagent runs, and nothing moves,
// rewinds or reopens it.
func (c *chat) quietLocked() bool {
	return !c.busy && c.started.IsZero() && !c.ownTurn && !c.steering && c.sendingNow == 0 &&
		len(c.queue) == 0 && !c.waitsLocked() && len(c.probes) == 0 &&
		!slices.ContainsFunc(c.items, running)
}

// awake wakes a sleeping chat for something that needs its agent, and
// waits until it has reopened (or failed to: the chat says why).
func (s *Service) awake(ctx context.Context, c *chat) error {
	c.mu.Lock()
	if c.asleep {
		c.asleep, c.reopenFailed = false, false
		c.logLocked().Info("chat waking")
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

// awakeChat is chat id, awake (and woken first if it slept).
func (s *Service) awakeChat(ctx context.Context, id string) (*chat, error) {
	c, err := s.chat(id)
	if err != nil {
		return nil, err
	}
	if err := s.awake(ctx, c); err != nil {
		return nil, err
	}
	return c, nil
}

// AgentPids returns the process of each chat's running agent, by chat id
// (side chats share their chat's).
func (s *Service) AgentPids() map[string]int {
	open := s.openChats()
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
	open := s.openChats()
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
