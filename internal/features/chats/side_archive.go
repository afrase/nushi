package chats

import (
	"context"
	"errors"
	"fmt"
	"slices"
)

// A side chat's × archives it (ADR 0115): one with messages is kept as a
// chat of its own (KeepSide's), archived at once, so nothing said in it is
// lost; Undo (RestoreSide) makes it its chat's side chat again. Both are
// the daemon's, so every client that ends a side chat does the same.

// ArchiveSide ends a side chat as its × does: one with messages is kept
// as an archived chat (see keepSide), a running turn stopped first; one
// without is closed (CloseSide), with nothing kept. It returns the
// archived chat's id, "" when nothing was kept.
func (s *Service) ArchiveSide(ctx context.Context, id string) (string, error) {
	s.mu.Lock()
	side := s.chats[id]
	s.mu.Unlock()
	if side == nil || side.parent == nil {
		return "", fmt.Errorf("no side chat %q", id)
	}
	side.mu.Lock()
	said := side.record.HasMessages
	side.mu.Unlock()
	if !said {
		return "", s.CloseSide(id)
	}
	return s.keepSide(ctx, id, true)
}

// RestoreSide makes an archived side chat (ArchiveSide's) its chat's side
// chat again and returns the side chat's id: the chat's agent forks the
// archived chat's session, the side chat starts with its transcript, mode
// and picks, and the archived chat goes (its record, copy and uploads,
// and its session through the chat's agent, as a side chat's). Refused
// when the chat it came from was deleted or archived, or has a side chat
// open.
func (s *Service) RestoreSide(ctx context.Context, id string) (string, error) {
	a, err := s.stored(id)
	if err != nil {
		return "", err
	}
	a.mu.Lock()
	rec, items := a.record, slices.Clone(a.items)
	a.mu.Unlock()
	if !rec.Archived || rec.SideOf == nil {
		return "", fmt.Errorf("%q isn't an archived side chat", id)
	}
	from, err := s.find(rec.SideOf.Chat)
	if err != nil {
		return "", errors.New("the chat it came from was deleted")
	}
	from.mu.Lock()
	archived, going := from.record.Archived, from.halting
	from.mu.Unlock()
	switch {
	case archived:
		return "", errors.New("the chat it came from is archived")
	case going:
		return "", errors.New("the chat it came from is being deleted")
	}
	p, err := s.awakeChat(ctx, rec.SideOf.Chat)
	if err != nil {
		return "", err
	}
	// A side chat keeps no copy: its images hold their bytes.
	if err := a.itemsWithBytes(items); err != nil {
		return "", fmt.Errorf("couldn't bring the side chat back: %w", err)
	}
	// Nothing else may take it meanwhile: a delete, an unarchive, an Undo.
	if _, err := s.halt(id); err != nil {
		return "", err
	}
	n := min(rec.SideOf.Base, len(items))
	sideID, err := s.openSide(ctx, p, &sideSource{sid: rec.SessionID, base: items[:n], items: items[n:], mode: rec.Mode, picks: rec.Picks})
	if err != nil {
		a.mu.Lock()
		a.halting = false
		a.mu.Unlock()
		return "", err
	}
	s.dropArchivedSide(p, a, rec.SessionID)
	return sideID, nil
}

// dropArchivedSide removes an archived side chat brought back: its record
// (a removed event), uploads and copy, and its session, of which the side
// chat is a fork, through the chat's agent as a side chat's (throwAway).
// What fails is logged: the side chat is back either way.
func (s *Service) dropArchivedSide(p, a *chat, sid string) {
	if err := s.removeUploads(a.id); err != nil {
		a.log().Warn("removing an archived side chat's uploads", "err", err)
	}
	if err := s.forget(a); err != nil {
		a.log().Warn("removing an archived side chat brought back", "err", err)
		return
	}
	if s.copies != nil {
		if err := s.copies.Delete(a.id); err != nil {
			a.log().Warn("removing an archived side chat's copy", "err", err)
		}
	}
	a.log().Info("archived side chat brought back", "to", p.id)
	p.mu.Lock()
	agent := p.agent
	p.throwawayLocked([]string{sid}, false)
	p.mu.Unlock()
	if agent != nil { // else the chat's next agent deletes it (discard)
		s.throwAway(p, agent, sid)
	}
}
