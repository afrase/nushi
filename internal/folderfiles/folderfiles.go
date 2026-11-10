// Package folderfiles reads what a folder brings an agent, for the trust
// card (ADRs 0023, 0029): each file whole, hashed, shown whole, and the
// key "Start anyway" keeps it under. Links aren't followed, nor fifos
// waited on: such a file has no hash, so a folder with one can't be
// remembered (the card fails closed). The one link with a hash is
// WalkLinked's, into what the card already shows.
package folderfiles

import (
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/regularfile"
)

// File is one of a folder's files: what the card shows (its first Shown+1
// bytes, where a link leads, or why Sum is nil) and the SHA-256 of all of
// it.
type File struct {
	Path string
	Text []byte
	Sum  []byte // nil when it can't be hashed (a link, not a regular file, unreadable)
	Link bool   // a link: Text says where it leads, and Sum, if any, is of that
}

// Walk returns the files in each of roots (a folder or a file; those that
// don't exist are left out), empty ones left out too. agent names who
// follows a link, for the card. No link has a sum.
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
	var out []File
	for _, root := range roots {
		fi, err := os.Lstat(root)
		switch {
		case err != nil:
			continue
		case fi.Mode()&fs.ModeSymlink != 0:
			out = append(out, link(root, agent, listed))
			continue
		case !fi.IsDir():
			if f := Hash(root); len(f.Text) > 0 || f.Sum == nil {
				out = append(out, f)
			}
			continue
		}
		_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			switch {
			case err != nil:
				out = append(out, File{Path: path, Text: []byte(err.Error())})
			case d.Type()&fs.ModeSymlink != 0:
				out = append(out, link(path, agent, listed))
			case d.Type().IsRegular():
				if f := Hash(path); len(f.Text) > 0 || f.Sum == nil {
					out = append(out, f)
				}
			case !d.IsDir():
				out = append(out, File{Path: path, Text: []byte("not a regular file")})
			}
			return nil
		})
	}
	return out
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

// Hash reads a regular file, without following a link or waiting on a
// fifo: its SHA-256, whole, and its first Shown+1 bytes.
func Hash(path string) File {
	f, _, err := regularfile.Open(path, false)
	if errors.Is(err, regularfile.ErrNotRegular) {
		return File{Path: path, Text: []byte("not a regular file")}
	}
	if err != nil {
		return File{Path: path, Text: []byte(err.Error())}
	}
	defer f.Close() //nolint:errcheck // read-only
	h := sha256.New()
	var head capped
	if _, err := io.Copy(io.MultiWriter(h, &head), f); err != nil {
		return File{Path: path, Text: []byte(err.Error())}
	}
	return File{Path: path, Text: head.b, Sum: h.Sum(nil)}
}

// capped keeps the first Shown+1 bytes written to it.
type capped struct{ b []byte }

func (c *capped) Write(p []byte) (int, error) {
	if room := Shown + 1 - len(c.b); room > 0 {
		c.b = append(c.b, p[:min(room, len(p))]...)
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
// Codex"), or, for one without a hash, why Nushi asks every time.
func Run(f File, what string) model.FolderRun {
	if f.Sum == nil {
		return model.FolderRun{File: f.Path, What: "Nushi can't vouch for this, so it asks every time", Command: string(f.Text)}
	}
	return model.FolderRun{File: f.Path, What: what, Command: Whole(f.Path, f.Text)}
}

// Shown is the most of a file the trust card shows: all of it, or nothing
// but where it is, never a part that would look like all of it.
const Shown = 256 << 10

// Whole is a file's text for the card: all of it, or where it is.
func Whole(path string, b []byte) string {
	if len(b) > Shown {
		return "too large to show: read " + path
	}
	return string(b)
}
