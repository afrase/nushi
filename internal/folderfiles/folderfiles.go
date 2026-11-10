// Package folderfiles reads what a folder brings an agent, for the trust
// card (ADRs 0023, 0029): each file whole, hashed, shown whole, and the
// key "Start anyway" keeps it under. Links aren't followed, nor fifos
// waited on: such a file has no hash, so a folder with one can't be
// remembered (the card fails closed). The one link with a hash is
// WalkLinked's, into what the card already shows. A walk reads only so
// much (maxFiles, maxBytes): a folder with more can't be remembered
// either.
package folderfiles

import (
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"syscall"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/regularfile"
)

// File is one of a folder's files: what the card shows (all of it when
// that is at most Shown bytes, where a link leads, or why Sum is nil) and
// the SHA-256 of all of it.
type File struct {
	Path string
	Text []byte
	Sum  []byte // nil when it can't be hashed (a link, not a regular file, unreadable, past what a walk reads)
	Size int64  // the bytes read of a regular file: with a Sum, all of it
	Link bool   // a link: Text says where it leads, and Sum, if any, is of that
}

// A walk reads at most maxFiles files, folders and links, and maxBytes of
// the files. What a folder brings an agent is small: opencode's own
// repository's .opencode, a full one, is 42 files and 272 KiB at 2.2.6.
// The caps are a hundred times that and more, so no folder made by hand
// meets them, and a folder made to (a million files, a file of many
// gigabytes) can't hold the daemon: 64 MiB hashes in a fraction of a
// second, and is the most a walk keeps in memory, as every file of at
// most Shown bytes is kept whole for the card. A tree of dependencies
// inside such a folder (a node_modules) may pass them, and asks every
// time, as a card of thousands of files would have to anyway.
const (
	maxFiles = 4096
	maxBytes = 64 << 20
)

// Walk returns the files in each of roots (a folder or a file; those that
// don't exist are left out), empty ones left out too. agent names who
// follows a link, for the card. No link has a sum. Past maxFiles or
// maxBytes the walk stops: its last row says the rest wasn't read and has
// no sum, so Key is "".
func Walk(roots []string, agent string) []File { return walk(roots, agent, nil) }

// WalkLinked is Walk for a card that shows all the agent loads through a
// link kept inside the folder (a skill in .claude/skills that is a link
// to the one in .agents/skills): a link that leads to a root that isn't
// itself a link, or into one, has a sum. What it leads to is listed and
// summed under its real path, so the link's sum is of where it leads, its
// text and the path that resolves to: a link pointed elsewhere asks
// again, also when it is a link further on that changed. Every other link
// stays without a sum: where it leads, the card doesn't show.
func WalkLinked(roots []string, agent string) []File {
	var listed []string
	for _, root := range roots {
		if fi, err := os.Lstat(root); err != nil || fi.Mode()&fs.ModeSymlink != 0 {
			continue
		}
		if resolved, err := filepath.EvalSymlinks(root); err == nil {
			listed = append(listed, resolved)
		}
	}
	return walk(roots, agent, listed)
}

// walk is Walk, and WalkLinked with listed: the real paths of the roots
// that aren't links.
func walk(roots []string, agent string, listed []string) []File {
	w := walker{agent: agent, listed: listed}
	for _, root := range roots {
		if fi, err := os.Lstat(root); err == nil && !w.visit(root, fi.Mode()) {
			break
		}
	}
	return w.out
}

// walker is one walk: what it found, and how much it read for it.
type walker struct {
	agent  string
	listed []string
	out    []File
	files  int   // files, folders and links met
	bytes  int64 // read of the files
}

// visit adds what is at path, which is of mode's type, and for a folder
// everything in it, in the order of the names. It is false once the walk
// has stopped at a cap.
func (w *walker) visit(path string, mode fs.FileMode) bool {
	if w.files == maxFiles {
		return w.stop(path)
	}
	w.files++
	switch {
	case mode&fs.ModeSymlink != 0:
		w.out = append(w.out, link(path, w.agent, w.listed))
	case mode.IsDir():
		entries, err := readDir(path, maxFiles-w.files+1)
		if err != nil {
			w.out = append(w.out, File{Path: path, Text: []byte(err.Error())})
		}
		for _, e := range entries {
			if !w.visit(filepath.Join(path, e.Name()), e.Type()) {
				return false
			}
		}
	case mode.IsRegular():
		f, fits := hash(path, maxBytes-w.bytes)
		if !fits {
			return w.stop(path)
		}
		w.bytes += f.Size
		if f.Size > 0 || f.Sum == nil {
			w.out = append(w.out, f)
		}
	default:
		w.out = append(w.out, File{Path: path, Text: []byte("not a regular file")})
	}
	return true
}

// stop ends the walk at path, the first thing past a cap: a row without a
// sum says so, so the folder isn't remembered.
func (w *walker) stop(path string) bool {
	w.out = append(w.out, File{Path: path, Text: fmt.Appendf(nil,
		"not read, nor what comes after it: Nushi reads at most %d files and %d MiB of what a folder brings", maxFiles, maxBytes>>20)})
	return false
}

// readDir is the folder at path's entries by name, n of them at most, so
// that a folder of a million costs no more than the walk may still read:
// with more than n, which n they are is the folder's own order, and the
// walk stops among them. A link or a fifo put there since the walk saw a
// folder is neither followed nor waited on.
func readDir(path string, n int) ([]fs.DirEntry, error) {
	f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NONBLOCK|syscall.O_NOFOLLOW|syscall.O_DIRECTORY, 0) //nolint:gosec // a folder of the walk, opened for its names
	if err != nil {
		return nil, err
	}
	defer f.Close() //nolint:errcheck // read-only
	entries, err := f.ReadDir(n)
	if errors.Is(err, io.EOF) { // an empty folder
		err = nil
	}
	slices.SortFunc(entries, func(a, b fs.DirEntry) int { return strings.Compare(a.Name(), b.Name()) })
	return entries, err
}

// link is the link at path: without a sum, unless it leads into one of
// listed (WalkLinked).
func link(path, agent string, listed []string) File {
	target, _ := os.Readlink(path)
	f := File{Path: path, Link: true, Text: []byte("a link to " + target + ", which " + agent + " follows")}
	if len(listed) == 0 {
		return f
	}
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil { // it leads nowhere, or in a circle
		return f
	}
	for _, root := range listed {
		if rel, err := filepath.Rel(root, resolved); err == nil && filepath.IsLocal(rel) {
			sum := sha256.Sum256([]byte(target + "\x00" + resolved))
			f.Text = []byte("a link to " + target + ", which " + agent + " follows to " + resolved + ", shown here")
			f.Sum = sum[:]
			break
		}
	}
	return f
}

// hash reads the regular file at path, without following a link or
// waiting on a fifo: its SHA-256 and its size, whole, and its text when
// that is at most Shown bytes. It reads at most limit bytes: a longer
// file doesn't fit, and of one whose size says so nothing is read.
func hash(path string, limit int64) (file File, fits bool) {
	f, fi, err := regularfile.Open(path, false)
	if errors.Is(err, regularfile.ErrNotRegular) {
		return File{Path: path, Text: []byte("not a regular file")}, true
	}
	if err != nil {
		return File{Path: path, Text: []byte(err.Error())}, true
	}
	defer f.Close() //nolint:errcheck // read-only
	if fi.Size() > limit {
		return File{}, false
	}
	h := sha256.New()
	var text head
	// One byte more than fits tells a file that grew past it.
	n, err := io.Copy(io.MultiWriter(h, &text), io.LimitReader(f, limit+1))
	switch {
	case n > limit:
		return File{}, false
	case err != nil:
		return File{Path: path, Text: []byte(err.Error()), Size: n}, true
	}
	return File{Path: path, Text: text.b, Sum: h.Sum(nil), Size: n}, true
}

// head keeps what is written to it while that is at most Shown bytes, and
// nothing of more: the card shows a file whole or not at all.
type head struct {
	b    []byte
	over bool
}

func (h *head) Write(p []byte) (int, error) {
	if h.over = h.over || len(h.b)+len(p) > Shown; h.over {
		h.b = nil
	} else {
		h.b = append(h.b, p...)
	}
	return len(p), nil
}

// Key is what "Start anyway" for agent is kept under: the folder and a
// hash of every file the card shows, each whole, so a folder below it, or
// a file added or changed since, asks again, and trusting a folder for one
// agent doesn't trust it for another. It is "" when a file has no hash.
func Key(agent, folder string, files []File) string {
	h := sha256.New()
	for _, f := range files {
		if f.Sum == nil {
			return ""
		}
		_, _ = fmt.Fprintf(h, "%s\x00%x\x00", f.Path, f.Sum) // a hash doesn't fail
	}
	return fmt.Sprintf("%s:%s#%x", agent, git.RealPath(folder), h.Sum(nil))
}

// Run is how the card shows a file: whole, under what (such as "Read by
// Codex"); for one over Shown, where it is; for one without a hash, why
// Nushi asks every time.
func Run(f File, what string) model.FolderRun {
	switch {
	case f.Sum == nil:
		return model.FolderRun{File: f.Path, What: "Nushi can't vouch for this, so it asks every time", Command: string(f.Text)}
	case f.Size > Shown:
		return model.FolderRun{File: f.Path, What: what, Command: "too large to show: read " + f.Path}
	}
	return model.FolderRun{File: f.Path, What: what, Command: string(f.Text)}
}

// Shown is the most of a file the trust card shows: all of it, or nothing
// but where it is, never a part that would look like all of it.
const Shown = 256 << 10
