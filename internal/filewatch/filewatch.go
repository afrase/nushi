// Package filewatch reads a file inside one of a few folders (a chat's
// folder and its worktree) and reads it again whenever it changes: the
// preview of what an agent wrote. Reads go through os.Root, so neither a
// ".." nor a link can lead outside the folder.
package filewatch

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/regularfile"
)

// MaxSize is the largest file sent whole; a larger one is only named.
const MaxSize = 5 << 20

// File is a file as it is now.
type File struct {
	Path     string // absolute
	Data     []byte // nil when TooLarge or Missing
	Size     int64
	TooLarge bool
	Missing  bool // not there, or not a regular file
}

// Locate finds which of roots (absolute folders) holds path (absolute, or
// relative to the first root), and path relative to it. A path outside
// every root is refused; links are checked when the file is read.
func Locate(roots []string, path string) (root, rel string, err error) {
	if len(roots) == 0 {
		return "", "", errors.New("no folder to read from")
	}
	if !filepath.IsAbs(path) {
		path = filepath.Join(roots[0], path)
	}
	path = filepath.Clean(path)
	for _, r := range roots {
		// The agent may name the folder by its real path (/private/tmp
		// for /tmp).
		resolved, err := filepath.EvalSymlinks(r)
		if err != nil {
			resolved = r
		}
		for _, r := range []string{r, resolved} {
			if rel, err := filepath.Rel(r, path); err == nil && rel != "." && filepath.IsLocal(rel) {
				return r, rel, nil
			}
		}
	}
	return "", "", fmt.Errorf("%s is outside the chat's folder", path)
}

// Allowed is where a chat's preview may read path from: inside one of
// roots, as Locate finds it, or, outside them, a file wrote says one of
// the chat's tool calls worked on (an agent's notes in its own folder),
// which it is asked with the path absolute. Links are checked when the
// file is read.
func Allowed(roots []string, path string, wrote func(path string) bool) (root, rel string, err error) {
	root, rel, err = Locate(roots, path)
	if err != nil {
		p := filepath.Clean(path)
		if !filepath.IsAbs(p) || !wrote(p) {
			return "", "", err
		}
		root, rel = filepath.Dir(p), filepath.Base(p)
	}
	return root, rel, nil
}

// artifacts are the extensions of files made to be looked at: those the
// app's isArtifact takes (app/lib/preview.dart), which offer Preview on a
// tool row. Both sides' tests read testdata/artifacts.json, so a type
// added to one and not the other fails.
var artifacts = map[string]bool{
	"md": true, "markdown": true,
	"png": true, "jpg": true, "jpeg": true, "gif": true, "webp": true,
	"html": true, "htm": true, "svg": true, "pdf": true, "csv": true,
	"mmd": true, "mermaid": true,
}

// Artifact says path is of a type the preview shows as an artifact.
func Artifact(path string) bool {
	return artifacts[strings.ToLower(strings.TrimPrefix(filepath.Ext(path), "."))]
}

// Check says rel inside root can show: nil for a regular file reached,
// links followed, without leaving root; fs.ErrNotExist when it isn't
// there, regularfile.ErrNotRegular for a folder, a fifo or a device, and
// another error for a link leading out.
func Check(root, rel string) error {
	r, err := os.OpenRoot(root)
	if err != nil {
		return err
	}
	defer r.Close() //nolint:errcheck // read-only
	fi, err := r.Stat(rel)
	if err != nil {
		return err
	}
	if !fi.Mode().IsRegular() {
		return regularfile.ErrNotRegular
	}
	return nil
}

// Exists says rel inside root is a regular file, reached without leaving
// root.
func Exists(root, rel string) bool { return Check(root, rel) == nil }

// Read reads rel inside root. A missing file or one that isn't a regular
// file is Missing; a path that leads outside root is an error.
func Read(root, rel string) (File, error) {
	f := File{Path: filepath.Join(root, rel)}
	r, err := os.OpenRoot(root)
	if err != nil {
		return f, err
	}
	defer r.Close() //nolint:errcheck // read-only
	file, fi, err := regularfile.OpenIn(r, rel, true)
	if errors.Is(err, fs.ErrNotExist) || errors.Is(err, regularfile.ErrNotRegular) {
		f.Missing = true
		return f, nil
	}
	if err != nil {
		return f, err
	}
	defer file.Close() //nolint:errcheck // read-only
	b, err := regularfile.ReadAll(file, fi, MaxSize)
	if errors.Is(err, regularfile.ErrTooLarge) { // or it grew past while read
		f.Size, f.TooLarge = max(fi.Size(), MaxSize+1), true
		return f, nil
	}
	if err != nil {
		return f, err
	}
	f.Data, f.Size = b, int64(len(b))
	return f, nil
}

// stamp is what says a file changed: its size and time, or that it's gone.
type stamp struct {
	size  int64
	mod   time.Time
	there bool
}

func stampOf(root, rel string) stamp {
	r, err := os.OpenRoot(root)
	if err != nil {
		return stamp{}
	}
	defer r.Close() //nolint:errcheck // read-only
	fi, err := r.Stat(rel)
	if err != nil {
		return stamp{}
	}
	return stamp{size: fi.Size(), mod: fi.ModTime(), there: true}
}

// Watch sends rel inside root, then again each time it changes (looked at
// every every), until ctx ends (nil) or send fails or the file can't be
// read (that error).
func Watch(ctx context.Context, root, rel string, every time.Duration, send func(File) error) error {
	last := stampOf(root, rel)
	f, err := Read(root, rel)
	if err != nil {
		return err
	}
	if err := send(f); err != nil {
		return err
	}
	tick := time.NewTicker(every)
	defer tick.Stop()
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-tick.C:
		}
		now := stampOf(root, rel)
		if now == last {
			continue
		}
		last = now
		f, err := Read(root, rel)
		if err != nil {
			return err
		}
		if err := send(f); err != nil {
			return err
		}
	}
}
