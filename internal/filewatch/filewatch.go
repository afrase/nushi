// Package filewatch reads a file inside one of a few folders (a chat's
// folder and its worktree) and reads it again whenever it changes: the
// preview of what an agent wrote. Reads go through os.Root, so neither a
// ".." nor a link can lead outside the folder.
package filewatch

import (
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"syscall"
	"time"
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

// Exists says rel inside root is a regular file, reached without leaving
// root.
func Exists(root, rel string) bool {
	r, err := os.OpenRoot(root)
	if err != nil {
		return false
	}
	defer r.Close() //nolint:errcheck // read-only
	fi, err := r.Stat(rel)
	return err == nil && fi.Mode().IsRegular()
}

// Read reads rel inside root. A missing file or one that isn't a regular
// file is Missing; a path that leads outside root is an error.
func Read(root, rel string) (File, error) {
	f := File{Path: filepath.Join(root, rel)}
	r, err := os.OpenRoot(root)
	if err != nil {
		return f, err
	}
	defer r.Close() //nolint:errcheck // read-only
	// Only a regular file is opened (never a fifo or a device), and the
	// open checks again.
	fi, err := r.Stat(rel)
	if errors.Is(err, fs.ErrNotExist) || err == nil && !fi.Mode().IsRegular() {
		f.Missing = true
		return f, nil
	}
	if err != nil {
		return f, err
	}
	file, err := r.OpenFile(rel, os.O_RDONLY|syscall.O_NONBLOCK, 0)
	if errors.Is(err, fs.ErrNotExist) {
		f.Missing = true
		return f, nil
	}
	if err != nil {
		return f, err
	}
	defer file.Close() //nolint:errcheck // read-only
	fi, err = file.Stat()
	if err != nil {
		return f, err
	}
	if !fi.Mode().IsRegular() {
		f.Missing = true
		return f, nil
	}
	f.Size = fi.Size()
	if f.Size > MaxSize {
		f.TooLarge = true
		return f, nil
	}
	b, err := io.ReadAll(io.LimitReader(file, MaxSize+1))
	if err != nil {
		return f, err
	}
	if len(b) > MaxSize { // it grew while read
		f.Size, f.TooLarge = int64(len(b)), true
		return f, nil
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
