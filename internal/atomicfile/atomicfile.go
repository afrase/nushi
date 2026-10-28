// Package atomicfile replaces a file at once: readers see the old file or
// the new, never half of one.
package atomicfile

import (
	"crypto/rand"
	"os"
	"path/filepath"
)

// Rewrite replaces an agent's settings file at path with data (Replace):
// an existing file keeps its mode, and a new one is the owner's alone
// (0600), its folder made 0700 if it's missing too. A link at path is
// replaced, not followed: resolve one first to change what it points at.
func Rewrite(path string, data []byte) error {
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
	f, err := os.CreateTemp(filepath.Dir(path), ".nushi-*")
	if err != nil {
		return err
	}
	_, err = f.Write(data)
	if err == nil {
		err = f.Chmod(mode)
	}
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Rename(f.Name(), path)
	}
	if err != nil {
		_ = os.Remove(f.Name()) // the write's error is the one to return
	}
	return err
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
	_, err = f.Write(data)
	if err == nil {
		err = f.Chmod(mode)
	}
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = root.Rename(tmp, name)
	}
	if err != nil {
		_ = root.Remove(tmp) // the write's error is the one to return
	}
	return err
}
