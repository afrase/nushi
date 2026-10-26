// Package atomicfile replaces a file at once: readers see the old file or
// the new, never half of one.
package atomicfile

import (
	"crypto/rand"
	"os"
	"path/filepath"
)

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
