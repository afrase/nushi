// Package filesave writes a file the user edited in the Mac's preview
// (ADR 0096): only where the preview reads it, only a regular file with
// one link and at most MaxSize, and only while it is still as the app last
// read it. A file that changed since is left as it is, and its bytes go
// back for the app to merge.
package filesave

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sync"
	"syscall"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/regularfile"
)

// MaxSize is the largest file edited, before and after.
const MaxSize = 1 << 20

var (
	// ErrNotRegular is a folder, a fifo, a device, or a link that leads
	// nowhere.
	ErrNotRegular = errors.New("not a regular file")
	// ErrLinked is a file with more than one hard link: a new file renamed
	// over it would part it from the others.
	ErrLinked = errors.New("the file has other hard links")
	// ErrTooLarge is a file, or new bytes, over MaxSize.
	ErrTooLarge = fmt.Errorf("larger than %d MiB", MaxSize>>20)
	// ErrOutside is a path, or a link's target, outside the folder.
	ErrOutside = errors.New("outside the folder")
	// ErrReadOnly is a file the daemon's user doesn't own or has no write
	// bit on: a new file renamed over it would get past its permissions.
	ErrReadOnly = errors.New("the file is read-only")
)

// Result is how a save went: Saved, with the file's sum, or not, with the
// file as it is now (Data and Sum, or Missing).
type Result struct {
	Saved   bool
	Sum     string // the file's sha256 now, hex; "" when Missing
	Data    []byte // the file now, when not Saved
	Missing bool
	Path    string // the file written, links followed (absolute)
}

// Sum is data's sha256 in hex, as Result and the preview's watch say it.
func Sum(data []byte) string {
	s := sha256.Sum256(data)
	return hex.EncodeToString(s[:])
}

// Editable says a file the preview read, with links and size, may be
// saved: a regular file with one link, at most MaxSize, that Writable.
func Editable(size int64, links uint64, mode fs.FileMode, owner uint32) bool {
	return size <= MaxSize && links == 1 && Writable(mode, owner)
}

// Writable says a file of mode and owner (a uid) may be saved: the daemon's
// user owns it and has its write bit. A save renames a new file over the
// old one, which only the folder's permissions would otherwise limit.
func Writable(mode fs.FileMode, owner uint32) bool {
	return int64(owner) == int64(os.Getuid()) && mode.Perm()&0o200 != 0
}

// Saver saves files one at a time. One lock for every file: a path's
// spelling doesn't name one file (APFS ignores case and normalization),
// and saves are few, small and quick.
type Saver struct {
	mu sync.Mutex
}

// Save writes data to rel inside root (as filewatch reads it: a link
// followed only to a target inside root) if the file is still base, its
// sha256 in hex, or isn't there, with mustNotExist. A file that already
// holds data is Saved without a write; one that changed otherwise is
// returned as it is now. The file keeps its permission bits; a new one is
// 0644. A file not Writable is ErrReadOnly.
func (s *Saver) Save(root, rel string, data []byte, base string, mustNotExist bool) (Result, error) {
	if len(data) > MaxSize {
		return Result{}, ErrTooLarge
	}
	folder, name, err := resolve(root, rel)
	if err != nil {
		return Result{}, err
	}
	path := filepath.Join(folder, name)
	s.mu.Lock()
	defer s.mu.Unlock()
	r, err := os.OpenRoot(folder)
	if err != nil {
		return Result{}, err
	}
	defer r.Close() //nolint:errcheck // nothing written through it
	now, mode, err := current(r, name)
	if err != nil {
		return Result{}, err
	}
	switch {
	case now != nil && bytes.Equal(now, data):
		return Result{Saved: true, Sum: Sum(data), Path: path}, nil
	case now == nil && !mustNotExist:
		return Result{Missing: true, Path: path}, nil
	case now != nil && (mustNotExist || Sum(now) != base):
		return Result{Sum: Sum(now), Data: now, Path: path}, nil
	}
	if err := atomicfile.ReplaceIn(r, name, data, mode); err != nil {
		return Result{}, fmt.Errorf("write %s: %w", filepath.Base(name), err)
	}
	return Result{Saved: true, Sum: Sum(data), Path: path}, nil
}

// current reads name inside r: nil when it isn't there, with the mode a
// new file takes, or its bytes and its mode. A folder, a fifo or a device
// is ErrNotRegular, a file with other hard links ErrLinked, one not
// Writable ErrReadOnly.
func current(r *os.Root, name string) ([]byte, os.FileMode, error) {
	fi, err := r.Lstat(name)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, 0o644, nil
	}
	if err != nil {
		return nil, 0, err
	}
	if !fi.Mode().IsRegular() {
		return nil, 0, ErrNotRegular
	}
	f, fi, err := regularfile.OpenIn(r, name, false)
	if errors.Is(err, regularfile.ErrNotRegular) {
		return nil, 0, ErrNotRegular
	}
	if err != nil {
		return nil, 0, err
	}
	defer f.Close() //nolint:errcheck // read-only
	st, ok := fi.Sys().(*syscall.Stat_t)
	if !ok {
		return nil, 0, ErrReadOnly
	}
	if st.Nlink > 1 {
		return nil, 0, ErrLinked
	}
	if !Writable(fi.Mode(), st.Uid) {
		return nil, 0, ErrReadOnly
	}
	b, err := regularfile.ReadAll(f, fi, MaxSize)
	if errors.Is(err, regularfile.ErrTooLarge) {
		return nil, 0, ErrTooLarge
	}
	if err != nil {
		return nil, 0, err
	}
	return b, fi.Mode().Perm(), nil
}

// resolve finds the file rel inside root names, every link followed: its
// folder's real path and its name there, which must be inside root's real
// path. A file that isn't there is named in its folder, which must be. A
// link that leads nowhere is ErrNotRegular.
func resolve(root, rel string) (folder, name string, err error) {
	folder, err = filepath.EvalSymlinks(root)
	if err != nil {
		return "", "", err
	}
	path := filepath.Join(root, rel)
	target, err := filepath.EvalSymlinks(path)
	if errors.Is(err, fs.ErrNotExist) {
		if fi, lerr := os.Lstat(path); lerr == nil && fi.Mode()&fs.ModeSymlink != 0 {
			return "", "", ErrNotRegular
		}
		dir, derr := filepath.EvalSymlinks(filepath.Dir(path))
		if derr != nil {
			return "", "", derr
		}
		target, err = filepath.Join(dir, filepath.Base(path)), nil
	}
	if err != nil {
		return "", "", err
	}
	name, err = filepath.Rel(folder, target)
	if err != nil || !filepath.IsLocal(name) {
		return "", "", ErrOutside
	}
	return folder, name, nil
}
