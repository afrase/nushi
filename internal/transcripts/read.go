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

// Read returns chat's copy as it stands, its images read back; none (nil)
// when it has no copy. Lines that can't be read (a crash's last line) are
// skipped. A file mostly of items written again since is written anew.
func (s *Store) Read(chat string) ([]model.Item, error) {
	if err := checkChat(chat); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	t, lines, size, err := s.replayLocked(chat, func(line []byte) (change, bool) {
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

// head is what Find reads of a record first: none of its item's text.
type head struct {
	Item *struct {
		ID     string
		Kind   model.ItemKind
		Status string
	} `json:"item"`
	After string `json:"after"`
	Cut   string `json:"cut"`
	Drop  string `json:"drop"`
}

// Find returns the items of chat's copy, as it stands, that want picks,
// their images read back, each with the id of the item before it ("" for
// the first). want sees an item's ID, Kind and Status only, and only the
// items it picks are read whole: a long copy costs what they hold and its
// items' ids, not its size (a daemon's start looks through every chat's).
func (s *Store) Find(chat string, want func(model.Item) bool) (items []model.Item, after []string, err error) {
	if err := checkChat(chat); err != nil {
		return nil, nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	t, _, _, err := s.replayLocked(chat, func(line []byte) (change, bool) {
		var h head
		if json.Unmarshal(line, &h) != nil {
			return change{}, false
		}
		c := change{after: h.After, cut: h.Cut, drop: h.Drop}
		if h.Item == nil {
			return c, true
		}
		c.item = &entry{id: h.Item.ID}
		if !want(model.Item{ID: h.Item.ID, Kind: h.Item.Kind, Status: h.Item.Status}) {
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
// each line made a change by decode (false: a line that can't be read,
// skipped), so no more of the file is held at once than its longest
// line. It returns the transcript (nil when chat has no copy), how many
// records it read and the file's size.
func (s *Store) replayLocked(chat string, decode func([]byte) (change, bool)) (*transcript, int, int64, error) {
	f, err := s.root.Open(path.Join(chat, itemsFile))
	if errors.Is(err, fs.ErrNotExist) {
		return nil, 0, 0, nil
	}
	if err != nil {
		return nil, 0, 0, err
	}
	defer func() { _ = f.Close() }()
	t, n := &transcript{}, 0
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
		if c, ok := decode(bytes.TrimSuffix(line, []byte("\n"))); ok {
			n++
			t.apply(c)
		}
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

// withImagesLocked is st as an item, its images read back from their
// files.
func (s *Store) withImagesLocked(chat string, st *stored) model.Item {
	it := st.Item
	for _, p := range st.Pictures {
		if !validHash.MatchString(p.Hash) {
			continue
		}
		if data, err := s.root.ReadFile(path.Join(chat, imagesDir, p.Hash)); err == nil {
			it.Images = append(it.Images, model.Image{MimeType: p.MimeType, Data: data, Hash: p.Hash})
		}
	}
	return it
}
