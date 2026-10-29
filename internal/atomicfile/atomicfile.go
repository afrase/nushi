// Package atomicfile replaces a file at once and durably: readers see the
// old file or the new, never half of one, and after a crash it is one of
// them, never an empty file (the new file's data is on disk before the
// rename, and the rename is synced too).
package atomicfile

import (
	"bytes"
	"crypto/rand"
	"io"
	"os"
	"path/filepath"
)

// Rewrite replaces an agent's settings file at path with data (Replace):
// an existing file keeps its mode, and a new one is the owner's alone
// (0600), its folder made 0700 if it's missing too. A link at path is
// followed (your dotfiles'): the file it points at is replaced, the link
// kept. One that leads nowhere is replaced itself.
func Rewrite(path string, data []byte) error {
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		path = resolved
	}
	mode := os.FileMode(0o600)
	if fi, err := os.Stat(path); err == nil {
		mode = fi.Mode().Perm()
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	return Replace(path, data, mode)
}

// Replace writes data to path through a new temporary file beside it
// (a fresh name, never an existing file or symlink), then renames it over
// path.
func Replace(path string, data []byte, mode os.FileMode) error {
	return ReplaceFrom(path, bytes.NewReader(data), mode)
}

// ReplaceFrom is Replace with what r reads, streamed.
func ReplaceFrom(path string, r io.Reader, mode os.FileMode) error {
	f, err := os.CreateTemp(filepath.Dir(path), ".nushi-*")
	if err != nil {
		return err
	}
	err = write(f, r, mode)
	if err == nil {
		err = os.Rename(f.Name(), path)
	}
	if err != nil {
		_ = os.Remove(f.Name()) // the write's error is the one to return
		return err
	}
	if dir, err := os.Open(filepath.Dir(path)); err == nil {
		syncDir(dir)
	}
	return nil
}

// ReplaceIn is Replace for name inside root: neither it nor a folder on
// its way can lead out of root (a link there that does is refused), so a
// folder swapped for a link meanwhile can't send the write elsewhere.
func ReplaceIn(root *os.Root, name string, data []byte, mode os.FileMode) error {
	tmp := filepath.Join(filepath.Dir(name), ".nushi-"+rand.Text())
	f, err := root.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_EXCL, mode)
	if err != nil {
		return err
	}
	err = write(f, bytes.NewReader(data), mode)
	if err == nil {
		err = root.Rename(tmp, name)
	}
	if err != nil {
		_ = root.Remove(tmp) // the write's error is the one to return
		return err
	}
	if dir, err := root.Open(filepath.Dir(name)); err == nil {
		syncDir(dir)
	}
	return nil
}

// write fills the temporary file f from r with mode, on disk before it's
// closed (F_FULLFSYNC on macOS): renamed before then, a crash could leave
// an empty file in the old one's place.
func write(f *os.File, r io.Reader, mode os.FileMode) error {
	_, err := io.Copy(f, r)
	if err == nil {
		err = f.Chmod(mode)
	}
	if err == nil {
		err = f.Sync()
	}
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return err
}

// syncDir puts a rename in dir on disk, best effort: the rename is done
// either way.
func syncDir(dir *os.File) {
	_ = dir.Sync()
	_ = dir.Close()
}
