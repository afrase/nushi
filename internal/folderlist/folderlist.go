// Package folderlist lists a folder inside a chat's folder for the Files
// pane: its entries, folders first, each with its kind, size, time and
// whether git ignores it, then again whenever it changes. The path comes
// from a client (the phone's through the relay), so it is checked and
// read through os.Root: neither a ".." nor a link leads outside the
// chat's folder, a link that would is shown and not followed, and .git is
// never listed nor entered.
package folderlist

import (
	"cmp"
	"context"
	"errors"
	"io"
	"io/fs"
	"os"
	"path"
	"slices"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/git"
)

// The bounds of a listing.
const (
	// DefaultLimit is the most entries a folder sends when the request
	// names none; MaxLimit the most it may name. The rest is counted.
	DefaultLimit = 500
	MaxLimit     = 2000
	// MaxDepth is the most levels one request lists.
	MaxDepth = 3
	// readCap is the most entries read of one folder: past it the rest
	// isn't counted either, so a folder of millions stays fast.
	readCap = 50_000
	// maxEntries is the most entries one listing sends over all its
	// folders: depth stops descending past it.
	maxEntries = 5000
	// maxPath bounds a path asked for, past what macOS would open.
	maxPath = 4096
)

// The refusals, each fixed text: an API error is logged, and a path a
// client sends stays out of the log.
var (
	ErrPath   = errors.New("the path must be a folder's, relative to the chat's folder, without .. or .git")
	ErrFolder = errors.New("that isn't a folder inside the chat's folder")
)

// Kind is what an entry is.
type Kind string

// The kinds. A link inside the chat's folder takes its target's kind; one
// that leads out, loops or leads nowhere is a Link, never followed.
const (
	Folder Kind = "folder"
	File   Kind = "file"
	Link   Kind = "link"
	Other  Kind = "other" // a fifo, a device, a socket
)

// Entry is one of a folder's entries.
type Entry struct {
	Name     string
	Kind     Kind
	Size     int64 // a file's
	Modified time.Time
	Ignored  bool // git ignores it
	Linked   bool // a link, followed inside the chat's folder
}

// Listing is one folder's entries: folders first, then the rest, each by
// name; at most the limit of them, More counting those left out.
type Listing struct {
	Path    string // relative to the chat's folder, "" for itself
	Entries []Entry
	More    int
	Missing bool // the folder isn't there (any more)

	at time.Time // the folder's own time before it was read
}

// Options are what a request asks for.
type Options struct {
	Depth   int  // levels: 1 (or 0) lists the folder; 2 its folders too
	Ignored bool // what git ignores is listed, marked, not left out
	Limit   int  // entries a folder sends; 0 for DefaultLimit
}

func (o Options) bounded() Options {
	o.Depth = min(max(o.Depth, 1), MaxDepth)
	if o.Limit <= 0 {
		o.Limit = DefaultLimit
	}
	o.Limit = min(o.Limit, MaxLimit)
	return o
}

// Clean checks a path a client asked for: "" or "." is the folder itself;
// else relative, "/"-separated, without "..", an empty part, NUL or a
// .git part. It returns it as os.Root takes it.
func Clean(rel string) (string, error) {
	if rel == "" || rel == "." {
		return ".", nil
	}
	// fs.ValidPath refuses "..", "." and empty parts and a leading or
	// trailing "/".
	if len(rel) > maxPath || !utf8.ValidString(rel) || !fs.ValidPath(rel) || strings.ContainsRune(rel, 0) {
		return "", ErrPath
	}
	for part := range strings.SplitSeq(rel, "/") {
		if strings.EqualFold(part, ".git") { // APFS is case-insensitive
			return "", ErrPath
		}
	}
	return rel, nil
}

// List lists rel (Clean's) inside root and, to o.Depth, the folders it
// sends. A path that isn't a folder, or leads out of root, is ErrFolder;
// one that isn't there is a Listing that says so.
func List(ctx context.Context, root, rel string, o Options) ([]Listing, error) {
	r, err := os.OpenRoot(root)
	if err != nil {
		return nil, err
	}
	defer r.Close() //nolint:errcheck // read-only
	return list(ctx, r, root, rel, o.bounded())
}

func list(ctx context.Context, r *os.Root, root, rel string, o Options) ([]Listing, error) {
	first, err := one(ctx, r, root, rel, o)
	if err != nil {
		return nil, err
	}
	out, level, sent := []Listing{first}, []Listing{first}, len(first.Entries)
	for depth := 2; depth <= o.Depth && sent < maxEntries; depth++ {
		var next []Listing
		for _, l := range level {
			for _, e := range l.Entries {
				// A linked folder is listed when it's opened: a link back
				// up would list the same folders again.
				if e.Kind != Folder || e.Linked || sent >= maxEntries {
					continue
				}
				sub, err := one(ctx, r, root, join(l.Path, e.Name), o)
				if err != nil {
					continue
				}
				sent += len(sub.Entries)
				next = append(next, sub)
			}
		}
		out = append(out, next...)
		level = next
	}
	return out, nil
}

// one lists one folder.
func one(ctx context.Context, r *os.Root, root, rel string, o Options) (Listing, error) {
	l := Listing{Path: strings.TrimPrefix(rel, ".")}
	fi, err := r.Stat(rel)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		l.Missing = true
		return l, nil
	case err != nil || !fi.IsDir() || isGit(r, fi):
		return l, ErrFolder
	}
	l.at = fi.ModTime()
	dir, err := r.Open(rel)
	if err != nil {
		return l, ErrFolder
	}
	read, err := dir.ReadDir(readCap)
	_ = dir.Close()
	if err != nil && !errors.Is(err, io.EOF) {
		return l, err
	}
	entries := make([]Entry, 0, len(read))
	asked := make([]string, 0, len(read))
	for _, d := range read {
		name := d.Name()
		if strings.EqualFold(name, ".git") || !utf8.ValidString(name) {
			continue // a name a client can't be sent
		}
		p := join(l.Path, name)
		info, err := d.Info()
		e := entry(r, p, name, info, err)
		if e.Linked && e.Kind == Folder {
			if fi, err := r.Stat(p); err == nil && isGit(r, fi) {
				continue // .git by another name
			}
		}
		entries = append(entries, e)
		if e.Kind == Folder {
			p += "/" // a pattern for folders alone matches it
		}
		asked = append(asked, p)
	}
	ignored := git.IgnoredOf(ctx, root, asked)
	kept := entries[:0]
	for i, e := range entries {
		e.Ignored = ignored[asked[i]]
		if !e.Ignored || o.Ignored {
			kept = append(kept, e)
		}
	}
	slices.SortFunc(kept, byKindThenName)
	l.Entries = kept[:min(len(kept), o.Limit)]
	l.More = len(kept) - len(l.Entries)
	return l, nil
}

// isGit says the folder fi is root's .git, reached through a link.
func isGit(r *os.Root, fi fs.FileInfo) bool {
	g, err := r.Lstat(".git")
	return err == nil && os.SameFile(fi, g)
}

// entry is the entry at rel inside r, info its Lstat (err its error): a
// link followed only inside r.
func entry(r *os.Root, rel, name string, info fs.FileInfo, err error) Entry {
	e := Entry{Name: name, Kind: Other}
	if err != nil {
		return e
	}
	e.Modified = info.ModTime()
	if info.Mode()&fs.ModeSymlink != 0 {
		// os.Root follows it inside r alone: a link out, a loop or a
		// dangling one fails.
		target, err := r.Stat(rel)
		if err != nil {
			e.Kind = Link
			return e
		}
		info, e.Linked, e.Modified = target, true, target.ModTime()
	}
	switch {
	case info.IsDir():
		e.Kind = Folder
	case info.Mode().IsRegular():
		e.Kind, e.Size = File, info.Size()
	}
	return e
}

// byKindThenName puts folders first, then by name as Finder does, its
// case aside.
func byKindThenName(a, b Entry) int {
	if (a.Kind == Folder) != (b.Kind == Folder) {
		if a.Kind == Folder {
			return -1
		}
		return 1
	}
	return cmp.Or(strings.Compare(strings.ToLower(a.Name), strings.ToLower(b.Name)), strings.Compare(a.Name, b.Name))
}

// join is rel/name, "/"-separated, for a name at the top too.
func join(rel, name string) string {
	if rel == "" || rel == "." {
		return name
	}
	return path.Join(rel, name)
}
