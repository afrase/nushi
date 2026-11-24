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

// eachHour deletes the copies past their days (clearOld) now, as the
// daemon starts, and each hour, and each hour then forgets the chats whose
// sessions their agents deleted (sweep), until the service's life ends.
// Both can remove a chat (expire), so one waits for the other.
func (s *Service) eachHour(days func() int) {
	s.clearOld(days)
	tick := time.NewTicker(time.Hour)
	defer tick.Stop()
	for {
		select {
		case <-tick.C:
		case <-s.ctx.Done():
			return
		}
		s.clearOld(days)
		s.sweep(s.ctx)
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
