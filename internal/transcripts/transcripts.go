// Package transcripts keeps Nushi's own read-only copy of each chat's
// transcript (ADR 0047): a folder per chat in the data folder, holding an
// append-only file of the transcript's items as they were shown, and their
// images beside it. Nothing in it goes to an agent.
package transcripts

import (
	"bufio"
	"bytes"
	"cmp"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path"
	"regexp"
	"slices"
	"sync"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/model"
)

const (
	itemsFile = "items.jsonl" // a chat's records, one JSON object a line
	imagesDir = "images"      // its images, each named by its SHA-256
)

// Store keeps the copies in one folder. Every path it opens is in that
// folder (an os.Root: no link leads out of it), and every name it makes
// comes from a chat id it checked or an image's hash.
type Store struct {
	mu       sync.Mutex
	root     *os.Root
	repaired map[string]bool // chats whose file's end was checked in this run
}

// Open opens the store in dir, made 0700 if it isn't there, and removes
// what a crash left half-written (the temporary file of an image or of a
// copy written anew: atomicfile's, or one named as before step 443).
func Open(dir string) (*Store, error) {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	if err := os.Chmod(dir, 0o700); err != nil { //nolint:gosec // a folder: 0700 is owner-only
		return nil, err
	}
	root, err := os.OpenRoot(dir)
	if err != nil {
		return nil, err
	}
	s := &Store{root: root, repaired: map[string]bool{}}
	var half []string
	for _, p := range []string{"*/.nushi-*", "*/" + imagesDir + "/.nushi-*", "*/" + imagesDir + "/*.tmp*", "*/" + itemsFile + ".tmp"} {
		m, _ := fs.Glob(root.FS(), p)
		half = append(half, m...)
	}
	for _, t := range half {
		_ = root.Remove(t) // best effort: the next Open tries again
	}
	return s, nil
}

// Close lets go of the store's folder.
func (s *Store) Close() error { return s.root.Close() }

var validChat = regexp.MustCompile(`^[A-Za-z0-9_-]{1,64}$`)

func checkChat(chat string) error {
	if !validChat.MatchString(chat) {
		return fmt.Errorf("a transcript copy named %q", chat)
	}
	return nil
}

// record is one line of a chat's file: an item (new, placed after the item
// After, or the whole of one written before), a cut (the item and every
// item after it go: a rewind), or a drop (that item goes).
type record struct {
	Item  *stored `json:"item,omitempty"`
	After string  `json:"after,omitempty"`
	Cut   string  `json:"cut,omitempty"`
	Drop  string  `json:"drop,omitempty"`
}

// stored is an item as written: its images are files beside it, named in
// Pictures.
type stored struct {
	model.Item
	Pictures []picture `json:"pictures,omitempty"`
}

type picture struct {
	MimeType string `json:"mime"`
	Hash     string `json:"hash"`
}

// Append adds items to chat's copy, or replaces an item written before.
// after[i] is the id of the item before items[i] in the transcript, ""
// for the first: an item written late still takes its place. The records
// go in one write; a crash in the middle of it leaves a last line without
// its end, which reading skips and the next write cuts off.
func (s *Store) Append(chat string, items []model.Item, after []string) error {
	if len(items) == 0 {
		return nil
	}
	recs := make([]record, len(items))
	for i := range items {
		recs[i] = record{After: after[i]}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, it := range items {
		st, err := s.storeImagesLocked(chat, it)
		if err != nil {
			return err
		}
		recs[i].Item = st
	}
	return s.appendLocked(chat, recs)
}

// Cut takes item and every item after it out of chat's copy, as a rewind
// does the transcript.
func (s *Store) Cut(chat, item string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.hasLocked(chat) {
		return nil
	}
	return s.appendLocked(chat, []record{{Cut: item}})
}

// Drop takes one item out of chat's copy (a message the agent never got).
func (s *Store) Drop(chat, item string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.hasLocked(chat) {
		return nil
	}
	return s.appendLocked(chat, []record{{Drop: item}})
}

func (s *Store) appendLocked(chat string, recs []record) error {
	if err := checkChat(chat); err != nil {
		return err
	}
	var buf bytes.Buffer
	for _, r := range recs {
		b, err := json.Marshal(r)
		if err != nil {
			return err
		}
		buf.Write(b)
		buf.WriteByte('\n')
	}
	if err := s.root.MkdirAll(chat, 0o700); err != nil {
		return err
	}
	name := path.Join(chat, itemsFile)
	if !s.repaired[chat] {
		if err := s.repairLocked(name); err != nil {
			return err
		}
		s.repaired[chat] = true
	}
	f, err := s.root.OpenFile(name, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0o600)
	if err != nil {
		return err
	}
	_, err = f.Write(buf.Bytes())
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return err
}

// repairLocked cuts off a last line a crash left without its end, so the
// next record starts a line of its own.
func (s *Store) repairLocked(name string) error {
	b, err := s.root.ReadFile(name)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil || len(b) == 0 || b[len(b)-1] == '\n' {
		return err
	}
	f, err := s.root.OpenFile(name, os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	err = f.Truncate(int64(bytes.LastIndexByte(b, '\n') + 1))
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return err
}

// storeImagesLocked writes an item's images beside chat's file (each once,
// by its hash) and returns the item as written.
func (s *Store) storeImagesLocked(chat string, it model.Item) (*stored, error) {
	st := &stored{Item: it}
	st.Images = nil
	for _, img := range it.Images {
		sum := sha256.Sum256(img.Data)
		hash := hex.EncodeToString(sum[:])
		if err := s.writeImageLocked(chat, hash, img.Data); err != nil {
			return nil, err
		}
		st.Pictures = append(st.Pictures, picture{MimeType: img.MimeType, Hash: hash})
	}
	return st, nil
}

// writeImageLocked writes an image under its hash, whole or not at all
// (atomicfile.ReplaceIn): one there is never written again, so it must
// never be there empty.
func (s *Store) writeImageLocked(chat, hash string, data []byte) error {
	if err := checkChat(chat); err != nil {
		return err
	}
	dir := path.Join(chat, imagesDir)
	name := path.Join(dir, hash)
	if _, err := s.root.Lstat(name); err == nil {
		return nil
	}
	if err := s.root.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	return atomicfile.ReplaceIn(s.root, name, data, 0o600)
}

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
	b, err := s.root.ReadFile(path.Join(chat, itemsFile))
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var t transcript
	lines := 0
	sc := bufio.NewScanner(bytes.NewReader(b))
	sc.Buffer(nil, len(b)+1)
	for sc.Scan() {
		var r record
		if json.Unmarshal(sc.Bytes(), &r) != nil {
			continue
		}
		lines++
		t.apply(r)
	}
	items := t.items()
	out := make([]model.Item, len(items))
	for i, st := range items {
		out[i] = st.Item
		for _, p := range st.Pictures {
			if !validHash.MatchString(p.Hash) {
				continue
			}
			if data, err := s.root.ReadFile(path.Join(chat, imagesDir, p.Hash)); err == nil {
				out[i].Images = append(out[i].Images, model.Image{MimeType: p.MimeType, Data: data})
			}
		}
	}
	if lines > 2*len(out)+16 && len(b) > 1<<20 {
		_ = s.rewriteLocked(chat, items) // best effort: the file reads the same either way
	}
	return out, nil
}

// Replace writes chat's copy anew as items, in order.
func (s *Store) Replace(chat string, items []model.Item) error {
	if err := checkChat(chat); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	st := make([]stored, len(items))
	for i, it := range items {
		p, err := s.storeImagesLocked(chat, it)
		if err != nil {
			return err
		}
		st[i] = *p
	}
	return s.rewriteLocked(chat, st)
}

// rewriteLocked replaces chat's file with items' records, atomically and
// durably (the file may be the only history left of the chat), and
// removes the images no item names any more.
func (s *Store) rewriteLocked(chat string, items []stored) error {
	var buf bytes.Buffer
	used := map[string]bool{}
	for i := range items {
		r := record{Item: &items[i]}
		if i > 0 {
			r.After = items[i-1].ID
		}
		b, err := json.Marshal(r)
		if err != nil {
			return err
		}
		buf.Write(b)
		buf.WriteByte('\n')
		for _, p := range items[i].Pictures {
			used[p.Hash] = true
		}
	}
	if err := s.root.MkdirAll(chat, 0o700); err != nil {
		return err
	}
	if err := atomicfile.ReplaceIn(s.root, path.Join(chat, itemsFile), buf.Bytes(), 0o600); err != nil {
		return err
	}
	s.repaired[chat] = true
	pics, _ := fs.ReadDir(s.root.FS(), path.Join(chat, imagesDir))
	for _, p := range pics {
		if !used[p.Name()] {
			_ = s.root.Remove(path.Join(chat, imagesDir, p.Name())) // best effort: Delete takes it anyway
		}
	}
	return nil
}

// Delete removes chat's copy, images and all.
func (s *Store) Delete(chat string) error {
	if err := checkChat(chat); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.repaired, chat)
	return s.root.RemoveAll(chat)
}

// Has says whether chat has a copy.
func (s *Store) Has(chat string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.hasLocked(chat)
}

func (s *Store) hasLocked(chat string) bool {
	if checkChat(chat) != nil {
		return false
	}
	_, err := s.root.Lstat(path.Join(chat, itemsFile))
	return err == nil
}

// List returns every chat's copy, largest first. Links are counted as
// themselves, never followed.
func (s *Store) List() ([]model.TranscriptCopy, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	dirs, err := fs.ReadDir(s.root.FS(), ".")
	if err != nil {
		return nil, err
	}
	var out []model.TranscriptCopy
	for _, d := range dirs {
		if !d.IsDir() || checkChat(d.Name()) != nil {
			continue
		}
		c := model.TranscriptCopy{Chat: d.Name()}
		_ = fs.WalkDir(s.root.FS(), d.Name(), func(_ string, e fs.DirEntry, err error) error {
			if err != nil || e.IsDir() {
				return nil //nolint:nilerr // what can't be read isn't counted
			}
			if fi, err := e.Info(); err == nil {
				c.Bytes += fi.Size()
				if e.Name() == itemsFile {
					c.Modified = fi.ModTime()
				}
			}
			return nil
		})
		out = append(out, c)
	}
	slices.SortFunc(out, func(a, b model.TranscriptCopy) int {
		return cmp.Or(cmp.Compare(b.Bytes, a.Bytes), b.Modified.Compare(a.Modified))
	})
	return out, nil
}
