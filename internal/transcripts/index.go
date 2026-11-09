package transcripts

import (
	"encoding/json"
	"errors"
	"io/fs"
	"path"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// A chat that let go of its items reads its pages from its copy (the
// chats' letgo.go, ADR 0103): the heads of every item to find where a page starts,
// then the page's items whole. A copy's index is those heads and where
// each item's last record is in its file, so a page costs its own lines,
// not a pass over the file. The store keeps the indexes of the last few
// chats read so, each as long as its file stays as it was.

// keptIndexes is how many chats' indexes the store keeps.
const keptIndexes = 2

// index is a copy's heads (Heads) and where each one's last record is,
// as of the file's size and time.
type index struct {
	heads []itemHead
	spans []span
	pos   map[string]int // heads' indexes by id
	size  int64
	mod   time.Time
}

type span struct{ at, n int64 }

// errNoCopy is a chat without a copy, which has no index.
var errNoCopy = errors.New("no transcript copy")

// indexLocked returns chat's index, kept or made now; errNoCopy when it
// has no copy.
func (s *Store) indexLocked(chat string) (*index, error) {
	fi, err := s.root.Stat(path.Join(chat, itemsFile))
	if errors.Is(err, fs.ErrNotExist) {
		return nil, errNoCopy
	}
	if err != nil {
		return nil, err
	}
	if i := slices.IndexFunc(s.indexed, func(c string) bool { return c == chat }); i >= 0 {
		if ix := s.indexes[chat]; ix.size == fi.Size() && ix.mod.Equal(fi.ModTime()) {
			s.indexed = append(slices.Delete(s.indexed, i, i+1), chat)
			return ix, nil
		}
		s.forgetIndexLocked(chat)
	}
	t, _, _, err := s.replayLocked(chat, func(line []byte, at int64) (change, bool) {
		var h head
		if json.Unmarshal(line, &h) != nil {
			return change{}, false
		}
		c := change{after: h.After, cut: h.Cut, drop: h.Drop}
		if h.Item != nil {
			c.item = &entry{id: h.Item.ID, head: h.Item, at: at, n: int64(len(line))}
		}
		return c, true
	})
	if err != nil {
		return nil, err
	}
	if t == nil { // gone since its Stat
		return nil, errNoCopy
	}
	entries := t.entries()
	ix := &index{heads: make([]itemHead, len(entries)), spans: make([]span, len(entries)), pos: make(map[string]int, len(entries)), size: fi.Size(), mod: fi.ModTime()}
	for i, e := range entries {
		ix.heads[i], ix.spans[i], ix.pos[e.id] = *e.head, span{e.at, e.n}, i
	}
	if len(s.indexed) >= keptIndexes {
		s.forgetIndexLocked(s.indexed[0])
	}
	s.indexes[chat], s.indexed = ix, append(s.indexed, chat)
	return ix, nil
}

// forgetIndexLocked drops chat's index: its file changed.
func (s *Store) forgetIndexLocked(chat string) {
	delete(s.indexes, chat)
	s.indexed = slices.DeleteFunc(s.indexed, func(c string) bool { return c == chat })
}

// Heads returns chat's copy as it stands with only each item's ID, Kind,
// Status, Parent and WorktreePath, and its images' MimeType and Hash (no
// Data); none (nil) when it has no copy. It reads no item's text, so a
// long copy costs its items' heads, not its size; the store keeps them
// (the index) for Pick.
func (s *Store) Heads(chat string) ([]model.Item, error) {
	if err := checkChat(chat); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	ix, err := s.indexLocked(chat)
	if errors.Is(err, errNoCopy) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	out := make([]model.Item, len(ix.heads))
	for i := range ix.heads {
		out[i] = ix.heads[i].item()
	}
	return out, nil
}

// Pick returns the items of chat's copy whose ids are ids, whole, their
// images as the chat holds them, in the copy's order: only their own
// records are read.
func (s *Store) Pick(chat string, ids []string) ([]model.Item, error) {
	if err := checkChat(chat); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	ix, err := s.indexLocked(chat)
	if errors.Is(err, errNoCopy) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var at []int
	for _, id := range ids {
		if i, ok := ix.pos[id]; ok {
			at = append(at, i)
		}
	}
	slices.Sort(at)
	f, err := s.root.Open(path.Join(chat, itemsFile))
	if err != nil {
		return nil, err
	}
	defer func() { _ = f.Close() }()
	out := make([]model.Item, 0, len(at))
	var buf []byte
	for _, i := range at {
		sp := ix.spans[i]
		buf = slices.Grow(buf[:0], int(sp.n))[:sp.n]
		if _, err := f.ReadAt(buf, sp.at); err != nil {
			return nil, err
		}
		var r record
		if err := json.Unmarshal(buf, &r); err != nil || r.Item == nil {
			return nil, errors.Join(errors.New("a transcript copy's record moved"), err)
		}
		out = append(out, s.withImagesLocked(chat, r.Item))
	}
	return out, nil
}
