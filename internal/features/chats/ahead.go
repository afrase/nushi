package chats

import (
	"cmp"
	"context"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// A chat whose session its agent will delete on its own (Expires: Claude
// Code deletes sessions after cleanupPeriodDays) is shown after that only
// from Nushi's copy of its transcript (ADR 0047). A copy is written only
// while the transcript is loaded, so a chat last used before copies
// existed, or while they were off, and asleep since, would have none when
// the agent deletes its session. The copy-ahead pass makes one for it
// first (ADR 0047's amendment of 2026-11-25): it opens the chat as a
// reopen does (session/load: the agent replays its history; no prompt, no
// model call), the replay becomes the copy as a reopen's does
// (restoreLocked), and the chat is put back to sleep, as found. It runs
// after each sweep, one chat at a time, at most aheadPerHour, the chats
// last used longest ago first: those nearest the agent's cleanup.

// aheadPerHour is how many chats the copy-ahead pass opens an hour at
// most: a backlog of hundreds mustn't start an agent after another for
// the whole hour. A failed load counts.
const aheadPerHour = 3

// aheadRetryMax is the longest the pass waits to try a chat again whose
// load made no copy (it failed, or its replay held nothing a copy keeps):
// it waits an hour after the first try, twice as long after each next,
// up to this. Such chats go after those not tried yet, so a few that never
// copy can't take every hour's turn from the rest.
const aheadRetryMax = 24 * time.Hour

// aheadTry is how often the pass opened a chat and got no copy, and when
// it may try again.
type aheadTry struct {
	n    int
	next time.Time
}

// aheadLoad says a chat's load is the copy-ahead pass's, and how the chat
// is put back after it; what needs the agent meanwhile (a message, Wake, a
// step that wakes it, a show that would have reopened it) makes it
// notAhead, and the chat then stays open as after any reopen.
type aheadLoad uint8

const (
	notAhead    aheadLoad = iota
	aheadAsleep           // it was asleep: a show leaves it so
	aheadIdle             // it wasn't (no copy): a show would have reopened it
)

// wantedLocked says something needs the chat's agent: a load the pass
// began keeps its agent.
func (c *chat) wantedLocked() { c.ahead = notAhead }

// copyAhead makes the copies of the chats that need one (needsCopy), the
// longest unused first, those it tried before last and less often each
// time (aheadTry), aheadPerHour at most, until ctx ends.
func (s *Service) copyAhead(ctx context.Context) {
	if s.copies == nil || !s.copiesOn() || s.resting.Load() ||
		!slices.ContainsFunc(s.kinds, func(k *kind) bool { return k.Expires != "" && k.historyChecker != nil }) {
		return
	}
	stored, err := s.sessions.Sessions()
	if err != nil {
		return
	}
	stored = slices.DeleteFunc(stored, func(sess model.ChatRecord) bool { return !s.needsCopy(sess) })
	tried := make(map[string]aheadTry, len(s.aheadTried)) // the chats that need a copy still
	for _, sess := range stored {
		if t, ok := s.aheadTried[sess.ID]; ok {
			tried[sess.ID] = t
		}
	}
	s.aheadTried = tried
	now := time.Now()
	stored = slices.DeleteFunc(stored, func(sess model.ChatRecord) bool { return now.Before(tried[sess.ID].next) })
	slices.SortStableFunc(stored, func(a, b model.ChatRecord) int {
		return cmp.Or(cmp.Compare(tried[a.ID].n, tried[b.ID].n),
			cmp.Or(a.Updated, a.Created).Compare(cmp.Or(b.Updated, b.Created)))
	})
	opened := 0
	for _, sess := range stored {
		if opened == aheadPerHour || ctx.Err() != nil || !s.copiesOn() {
			return
		}
		if k, _ := s.kindOf(sess.Agent); k.historyChecker.HistoryGone(sess.SessionID, sess.Folder) {
			continue // the sweep's to mark
		}
		start := time.Now()
		if !s.copyOne(ctx, sess.ID) {
			continue
		}
		opened++
		if s.copies.Has(sess.ID) {
			delete(tried, sess.ID)
			continue
		}
		t := tried[sess.ID]
		t.n++
		// A minute's slack: the next hour's pass may begin a little
		// before the hour after this one began.
		t.next = start.Add(min(time.Hour<<(t.n-1), aheadRetryMax) - time.Minute)
		tried[sess.ID] = t
	}
}

// needsCopy says a stored chat has no copy and should: it had messages
// and a session, of an agent that deletes sessions on its own, can reopen
// them and whose files tell when it did; its folder is there; and its
// copy wasn't cleared since it was last used (CopyCleared: what the user
// cleared, by hand or by its age, isn't made again behind their back). An
// archived chat counts: its copy is what it shows.
func (s *Service) needsCopy(sess model.ChatRecord) bool {
	k, err := s.kindOf(sess.Agent)
	return err == nil && k.Name == sess.Agent && k.Expires != "" && k.historyChecker != nil && !k.noLoad.Load() &&
		sess.HasMessages && sess.SessionID != "" && !sess.CopyCleared.After(sess.Updated) &&
		folderGone(sess) == nil && !s.copies.Has(sess.ID)
}

// copyOne opens a chat for its copy and puts it back, and says whether an
// agent was started for it. A chat that ran since the daemon started and
// holds what it showed (outlived) gets that as its copy, with no agent;
// one that holds a queue isn't opened. A chat that runs, is busy, going, opening,
// shown, whose last reopen failed or whose session is gone is left.
//
//nolint:contextcheck // the load runs on the pass's life, the service's
func (s *Service) copyOne(ctx context.Context, id string) bool {
	c, err := s.listed(id)
	if err != nil {
		return false
	}
	c.mu.Lock()
	if c.agent != nil || c.busyLocked() || c.halting || c.opening || c.stopping || c.folder != "" ||
		c.reopenFailed || c.sessionGone || len(c.sides) > 0 || s.viewers != nil && s.viewers.Shown(id) {
		c.mu.Unlock()
		return false
	}
	if c.outlived && len(c.items) > 0 {
		// It ran while copies were off, and holds what it showed: a load
		// wouldn't replay into it (load), so its copy is what it shows.
		c.saveCopyLocked(nil, c.items)
		c.logLocked().Info("chat's copy made", "from", "what it shows")
		c.letGoLocked()
		c.mu.Unlock()
		return false
	}
	if len(c.queue) > 0 { // held (an archived chat's): the agent a load starts would stay for it
		c.mu.Unlock()
		return false
	}
	c.ahead = aheadIdle
	if c.asleep {
		c.ahead = aheadAsleep
	}
	c.beginOpLocked(opReopen) // what comes meanwhile waits for it, as for any reopen
	c.statusChangedLocked()
	c.logLocked().Info("chat opening", "for", "its transcript's copy")
	c.mu.Unlock()

	lctx, cancel := context.WithTimeout(ctx, reopenTimeout)
	start := time.Now()
	_, err = s.load(lctx, c)
	cancel()
	gone := err != nil && c.isGone(err)

	c.mu.Lock()
	var agent Agent
	log := c.logLocked().With("took", time.Since(start).Round(time.Millisecond))
	switch {
	case err != nil:
		log.Warn("chat not opened for its copy; it stays as it was", "err", err)
		c.asleep = c.ahead == aheadAsleep
	case c.ahead != notAhead && len(c.queue) == 0:
		agent = c.disconnectLocked()
		c.asleep = c.ahead == aheadAsleep || s.dormant(c.record, c.kind, true)
		log.Info("chat asleep again", "copied", s.copies.Has(c.id))
	default:
		log.Info("chat's copy made; chat stays open", "why", "it was wanted meanwhile")
	}
	c.ahead = notAhead
	c.endOpLocked()
	c.mu.Unlock()
	c.stopAgent(agent)
	c.mu.Lock()
	c.letGoLocked()
	c.mu.Unlock()
	if gone {
		s.expire(ctx, c, "the agent says so")
	}
	return true
}
