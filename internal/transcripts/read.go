package transcripts

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"io/fs"
	"path"
	"regexp"

	"github.com/afrase/nushi/internal/model"
)

var validHash = regexp.MustCompile(`^[0-9a-f]{64}$`)

// Read returns chat's copy as it stands, its images as the chat holds
// them (images.go); none (nil) when it has no copy. Lines that can't be
// read (a crash's last line) are skipped. A file mostly of items written
// again since is written anew.
func (s *Store) Read(chat string) ([]model.Item, error) {
	if err := checkChat(chat); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	t, lines, size, err := s.replayLocked(chat, func(line []byte, _ int64) (change, bool) {
		var r record
		if json.Unmarshal(line, &r) != nil {
			return change{}, false
		}
		c := change{after: r.After, cut: r.Cut, drop: r.Drop}
		if r.Item != nil {
			c.item = &entry{id: r.Item.ID, item: r.Item}
		}
		return c, true
	})
	if t == nil || err != nil {
		return nil, err
	}
	entries := t.entries()
	items := make([]*stored, len(entries))
	out := make([]model.Item, len(entries))
	for i, e := range entries {
		items[i], out[i] = e.item, s.withImagesLocked(chat, e.item)
	}
	if lines > 2*len(out)+16 && size > 1<<20 {
		_ = s.rewriteLocked(chat, items) // best effort: the file reads the same either way
	}
	return out, nil
}

// head is what Find and Heads read of a record first: none of its item's
// text, nor its images' bytes.
type head struct {
	Item  *itemHead `json:"item"`
	After string    `json:"after"`
	Cut   string    `json:"cut"`
	Drop  string    `json:"drop"`
}

// itemHead is what Heads gives of an item.
type itemHead struct {
	ID           string
	Kind         model.ItemKind
	Status       string
	Parent       string
	WorktreePath string
	Pictures     []picture `json:"pictures"`
}

// item is h as a model.Item of only what it has: its images are their
// MimeType and Hash (and size, when the record has it), without Data.
func (h *itemHead) item() model.Item {
	it := model.Item{ID: h.ID, Kind: h.Kind, Status: h.Status, Parent: h.Parent, WorktreePath: h.WorktreePath}
	for _, p := range h.Pictures {
		it.Images = append(it.Images, model.Image{MimeType: p.MimeType, Hash: p.Hash, Size: p.Size, Width: p.Width, Height: p.Height})
	}
	return it
}

// Find returns the items of chat's copy, as it stands, that want picks,
// their images as the chat holds them, each with the id of the item
// before it ("" for the first). want sees an item as Heads has it, and only the items it
// picks are read whole: a long copy costs what they hold and its
// items' ids, not its size (a daemon's start looks through every chat's).
func (s *Store) Find(chat string, want func(model.Item) bool) (items []model.Item, after []string, err error) {
	if err := checkChat(chat); err != nil {
		return nil, nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	t, _, _, err := s.replayLocked(chat, func(line []byte, _ int64) (change, bool) {
		var h head
		if json.Unmarshal(line, &h) != nil {
			return change{}, false
		}
		c := change{after: h.After, cut: h.Cut, drop: h.Drop}
		if h.Item == nil {
			return c, true
		}
		c.item = &entry{id: h.Item.ID}
		if !want(h.Item.item()) {
			return c, true
		}
		var r record
		if json.Unmarshal(line, &r) != nil || r.Item == nil {
			return change{}, false
		}
		c.item.item = r.Item
		return c, true
	})
	if t == nil || err != nil {
		return nil, nil, err
	}
	prev := ""
	for _, e := range t.entries() {
		if e.item != nil {
			items, after = append(items, s.withImagesLocked(chat, e.item)), append(after, prev)
		}
		prev = e.id
	}
	return items, after, nil
}

// replayLocked replays chat's file into its transcript a line at a time,
// each line (and where it starts in the file) made a change by decode
// (false: a line that can't be read, skipped), so no more of the file is
// held at once than its longest line. It returns the transcript (nil when chat has no copy), how many
// records it read and the file's size.
func (s *Store) replayLocked(chat string, decode func(line []byte, at int64) (change, bool)) (*transcript, int, int64, error) {
	f, err := s.root.Open(path.Join(chat, itemsFile))
	if errors.Is(err, fs.ErrNotExist) {
		return nil, 0, 0, nil
	}
	if err != nil {
		return nil, 0, 0, err
	}
	defer func() { _ = f.Close() }()
	t, n, at := &transcript{}, 0, int64(0)
	r := bufio.NewReaderSize(f, 64<<10)
	var long []byte // a line longer than r's buffer, so far
	for {
		line, err := r.ReadSlice('\n')
		if errors.Is(err, bufio.ErrBufferFull) {
			long = append(long, line...)
			continue
		}
		if len(long) > 0 {
			line, long = append(long, line...), long[:0]
		}
		if c, ok := decode(bytes.TrimSuffix(line, []byte("\n")), at); ok {
			n++
			t.apply(c)
		}
		at += int64(len(line))
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, 0, 0, err
		}
	}
	fi, err := f.Stat()
	if err != nil {
		return nil, 0, 0, err
	}
	return t, n, fi.Size(), nil
}
