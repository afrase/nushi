package chats

import "time"

// The service's housekeeping runs in two loops on its life (ctx), which
// Close ends and waits for: what each minute is for (chats sleeping,
// transcripts let go) is never held up by what each hour is for (old
// copies cleared, gone sessions swept), whose git runs and deletes can
// take a while.

// eachMinute records what the agents run (record.go), puts the chats that
// idled long enough to sleep (doze), then lets go of the items of those no
// client shows (letGoLocked), each minute until the service's life ends.
func (s *Service) eachMinute() {
	tick := time.NewTicker(time.Minute)
	defer tick.Stop()
	for {
		select {
		case <-tick.C:
		case <-s.ctx.Done():
			return
		}
		s.recordAgents()
		open := s.openChats()
		if after := s.SleepAfter(); after > 0 {
			for _, c := range open {
				s.doze(c, after)
			}
		}
		for _, c := range open {
			c.mu.Lock()
			c.letGoLocked()
			c.mu.Unlock()
		}
	}
}

// eachHour deletes the copies past their days (clearOld), then marks the
// chats whose sessions their agents deleted (sweep), then makes the
// copies of a few chats that have none before their agent deletes their
// sessions (copyAhead), as the daemon starts and each hour after, until
// the service's life ends: a chat whose agent lost its session while the
// daemon was down is marked at once. Each waits for the one before: a
// chat swept is not opened for its copy, and a copy cleared for its age
// is cleared before the pass looks.
func (s *Service) eachHour(days func() int) {
	tick := time.NewTicker(time.Hour)
	defer tick.Stop()
	for {
		s.clearOld(days)
		s.sweep(s.ctx)
		s.copyAhead(s.ctx)
		select {
		case <-tick.C:
		case <-s.ctx.Done():
			return
		}
	}
}

// clearOld deletes the copies last written more than days() ago (nil or
// 0: none, as with no copies).
func (s *Service) clearOld(days func() int) {
	if s.copies == nil || days == nil {
		return
	}
	if d := days(); d > 0 {
		s.clearOlder(time.Duration(d) * 24 * time.Hour)
	}
}
