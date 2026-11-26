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
	"time"

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
	held := s.lock(chat)
	defer held.Unlock()
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
	// A tool call's kind, its MCP tool and the files it names, without its
	// diffs' text: what the chats' writtenBy reads of the items a client
	// hasn't loaded.
	ToolKind           string
	MCPServer, MCPTool string
	Paths              []string
	Diffs              []struct{ Path string }
	// When the daemon saw it, and for a call that launched a workflow the
	// files its agents wrote: what writtenBy places them by. With them the
	// run's id and folder and the worktrees Claude gave its agents: what
	// a chat's related worktrees take of the run (ADR 0081).
	Sent, Started, Ended time.Time
	Workflow             *struct {
		RunID, Folder string
		Written       []model.WrittenFile
		Worktrees     []model.WorkflowWorktree
	}
}

// item is h as a model.Item of only what it has: its images are their
// MimeType and Hash (and size, when the record has it), without Data.
func (h *itemHead) item() model.Item {
	it := model.Item{ID: h.ID, Kind: h.Kind, Status: h.Status, Parent: h.Parent, WorktreePath: h.WorktreePath,
		ToolKind: h.ToolKind, MCPServer: h.MCPServer, MCPTool: h.MCPTool, Paths: h.Paths, Sent: h.Sent, Started: h.Started, Ended: h.Ended}
	if w := h.Workflow; w != nil && (len(w.Written) > 0 || len(w.Worktrees) > 0) {
		it.Workflow = &model.Workflow{RunID: w.RunID, Folder: w.Folder, Written: w.Written, Worktrees: w.Worktrees}
	}
	for _, d := range h.Diffs {
		it.Diffs = append(it.Diffs, model.FileChange{Path: d.Path})
	}
	for _, p := range h.Pictures {
		it.Images = append(it.Images, model.Image{MimeType: p.MimeType, Hash: p.Hash, Size: p.Size, Width: p.Width, Height: p.Height})
	}
	return it
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
