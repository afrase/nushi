package chats

import (
	"cmp"
	"crypto/rand"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/model"
)

// A device's files (the phone's, which aren't on the Mac) come whole with a
// message. Each is saved in the chat's uploads folder, in a folder of its
// own so it keeps its name, and goes to the agent as a link to that copy,
// as a file on the Mac does (ADR 0091). The folder is the daemon's, outside
// any repository; the chat's deletion takes it, and a chat keeps at most
// maxChatUploads of them, the oldest going first, apart from those of the
// messages still in its queue.
const (
	// MaxUpload is the most one uploaded file may weigh.
	MaxUpload = 8 << 20
	// MaxUploads is the most files one message may upload.
	MaxUploads = 10
)

// maxChatUploads is what a chat's uploads keep in all, its queue's apart
// (a variable for the tests).
var maxChatUploads int64 = 100 << 20

// checkUploads refuses m's uploads before anything is saved: too many, one
// too large, or a daemon that takes none.
func (s *Service) checkUploads(m model.Message) error {
	if len(m.Uploads) == 0 {
		return nil
	}
	if len(m.Uploads) > MaxUploads {
		return fmt.Errorf("a message takes at most %d files", MaxUploads)
	}
	for _, u := range m.Uploads {
		if len(u.Data) > MaxUpload {
			return fmt.Errorf("%s is too large to send: at most %d MB a file", uploadName(u.Name), MaxUpload>>20)
		}
	}
	if s.uploads == "" {
		return errors.New("this daemon doesn't take files sent whole")
	}
	return nil
}

// saveUploadsLocked writes m's uploads into the chat's uploads folder and
// adds their paths to its files; when one can't be saved, none is. It runs
// under the chat's lock once the chat takes the message (prompt), so a
// refused message leaves nothing behind, and Delete, which halts the chat
// first, finds every one.
func (s *Service) saveUploadsLocked(c *chat, m *model.Message) error {
	if len(m.Uploads) == 0 {
		return nil
	}
	if err := s.checkUploads(*m); err != nil {
		return err
	}
	dir := filepath.Join(s.uploads, c.id)
	var saved []string
	for _, u := range m.Uploads {
		own := filepath.Join(dir, rand.Text()[:12])
		err := os.MkdirAll(own, 0o700)
		path := filepath.Join(own, uploadName(u.Name))
		if err == nil {
			saved = append(saved, path) // its folder goes on a failure, whatever is in it
			err = atomicfile.Replace(path, u.Data, 0o600)
		}
		if err != nil {
			s.dropUploads(c.id, saved)
			return fmt.Errorf("saving %s: %w", uploadName(u.Name), err)
		}
	}
	m.Files = append(m.Files, saved...)
	m.Uploads = nil
	pruneUploads(dir, maxChatUploads, append(c.queuedUploadsLocked(), saved...))
	return nil
}

// dropUploads takes saved uploads of the chat's (each in a folder of its
// own) that went to no agent.
func (s *Service) dropUploads(chatID string, paths []string) {
	dir := filepath.Join(s.uploads, chatID)
	for _, p := range paths {
		if own := filepath.Dir(p); filepath.Dir(own) == dir {
			_ = os.RemoveAll(own) // best effort: the chat's deletion takes the rest
		}
	}
}

// queuedUploadsLocked is the files of the messages in the chat's queue:
// what pruning leaves, as the agent hasn't had them yet.
func (c *chat) queuedUploadsLocked() []string {
	var files []string
	for _, m := range c.queue {
		files = append(files, m.Files...)
	}
	return files
}

// uploadName is a sent file's name as saved: its last part only, without
// control characters or bidi marks (an override, U+202E, makes "a", then
// "fdp.sh", show as "ash.pdf"), at most 120 bytes with its extension kept;
// "file" when nothing is left.
func uploadName(name string) string {
	name = name[strings.LastIndexAny(name, `/\`)+1:]
	name = strings.Map(func(r rune) rune {
		if unicode.IsControl(r) || unicode.Is(unicode.Bidi_Control, r) || r == ':' {
			return -1
		}
		return r
	}, name)
	name = strings.TrimSpace(name)
	if name == "" || name == "." || name == ".." {
		return "file"
	}
	if len(name) > 120 {
		ext := filepath.Ext(name)
		if len(ext) > 20 {
			ext = ""
		}
		stem := name[:120-len(ext)]
		for !utf8.ValidString(stem) {
			stem = stem[:len(stem)-1]
		}
		name = stem + ext
	}
	return name
}

// pruneUploads removes the oldest uploads in dir (each a folder of one file)
// until what is left weighs at most most, apart from those of keep's files,
// which stay whatever they weigh.
func pruneUploads(dir string, most int64, keep []string) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	type upload struct {
		path string
		size int64
		mod  int64
	}
	var all []upload
	var total int64
	for _, e := range entries {
		own := filepath.Join(dir, e.Name())
		files, err := os.ReadDir(own)
		if err != nil || len(files) == 0 {
			continue
		}
		fi, err := files[0].Info()
		if err != nil {
			continue
		}
		total += fi.Size()
		if !slices.ContainsFunc(keep, func(f string) bool { return filepath.Dir(f) == own }) {
			all = append(all, upload{own, fi.Size(), fi.ModTime().UnixNano()})
		}
	}
	slices.SortFunc(all, func(a, b upload) int { return cmp.Compare(a.mod, b.mod) })
	for _, u := range all {
		if total <= most {
			return
		}
		if os.RemoveAll(u.path) == nil {
			total -= u.size
		}
	}
}

// removeUploads takes a deleted chat's uploads.
func (s *Service) removeUploads(chatID string) error {
	if s.uploads == "" {
		return nil
	}
	return os.RemoveAll(filepath.Join(s.uploads, chatID))
}
