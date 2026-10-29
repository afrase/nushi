package chats

import (
	"slices"

	"github.com/afrase/nushi/internal/model"
)

// Pin sets the pinned chats, top first: each of chatIDs is pinned at its
// place (ChatRecord.Pin, from 1), every other chat unpinned. An archived
// chat, one not known, a side chat and a repeat are left out, without an
// error. Each chat whose place changed is saved, which tells the clients.
func (s *Service) Pin(chatIDs []string) error {
	s.pinMu.Lock() // one whole order at a time
	defer s.pinMu.Unlock()
	stored, err := s.sessions.Sessions()
	if err != nil {
		return err
	}
	place := map[string]int{}
	for _, id := range chatIDs {
		i := slices.IndexFunc(stored, func(sess model.ChatRecord) bool { return sess.ID == id })
		if _, seen := place[id]; !seen && i >= 0 && !stored[i].Archived {
			place[id] = len(place) + 1
		}
	}
	for _, sess := range stored {
		if sess.Pin == place[sess.ID] {
			continue
		}
		c, err := s.stored(sess.ID)
		if err != nil {
			continue // gone meanwhile
		}
		c.mu.Lock()
		c.saveLocked(func(s *model.ChatRecord) {
			if !s.Archived || place[s.ID] == 0 {
				s.Pin = place[s.ID]
			}
		})
		c.mu.Unlock()
	}
	return nil
}
