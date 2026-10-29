// Package regularfile opens and reads only regular files, and at most so
// much of one: a path someone else chose (a repository's settings, a file
// a model names) can't make Nushi wait on a fifo, open a device or fill
// memory from one such as /dev/zero.
package regularfile

import (
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"syscall"
)

var (
	// ErrNotRegular is a folder, a fifo, a device, or a link not followed.
	ErrNotRegular = errors.New("not a regular file")
	// ErrTooLarge is a file over the most read of it.
	ErrTooLarge = errors.New("too large")
)

// Open opens the regular file at path for reading, and returns it with
// its stat (the open file's). A link is followed only with follow. Only
// what is a regular file before the open is opened (never a fifo or a
// device), and the open checks again: a fifo put there since doesn't
// wait, nor is a link put there since followed without follow.
func Open(path string, follow bool) (*os.File, fs.FileInfo, error) {
	stat, flag := os.Stat, os.O_RDONLY|syscall.O_NONBLOCK
	if !follow {
		stat, flag = os.Lstat, flag|syscall.O_NOFOLLOW
	}
	if err := regular(path, stat); err != nil {
		return nil, nil, err
	}
	f, err := os.OpenFile(path, flag, 0) //nolint:gosec // only a regular file is kept
	if !follow && errors.Is(err, syscall.ELOOP) {
		return nil, nil, notRegular(path)
	}
	if err != nil {
		return nil, nil, err
	}
	return checked(f, path)
}

// OpenIn is Open for name inside root: nothing on its way leads out of
// root, and with follow a link inside it is followed.
func OpenIn(root *os.Root, name string, follow bool) (*os.File, fs.FileInfo, error) {
	stat := root.Stat
	if !follow {
		stat = root.Lstat
	}
	if err := regular(name, stat); err != nil {
		return nil, nil, err
	}
	// os.Root follows a link whatever the flags: one put there since
	// the Lstat still can't lead out of root.
	f, err := root.OpenFile(name, os.O_RDONLY|syscall.O_NONBLOCK, 0)
	if err != nil {
		return nil, nil, err
	}
	return checked(f, name)
}

// Read reads the regular file at path (a link to one followed) whole:
// ErrTooLarge when it's over limit bytes.
func Read(path string, limit int64) ([]byte, error) {
	f, fi, err := Open(path, true)
	if err != nil {
		return nil, err
	}
	defer f.Close() //nolint:errcheck // read-only
	return ReadAll(f, fi, limit)
}

// ReadIn is Read for name inside root.
func ReadIn(root *os.Root, name string, limit int64) ([]byte, error) {
	f, fi, err := OpenIn(root, name, true)
	if err != nil {
		return nil, err
	}
	defer f.Close() //nolint:errcheck // read-only
	return ReadAll(f, fi, limit)
}

// ReadAll reads f, opened by Open or OpenIn with fi its stat, whole:
// ErrTooLarge when fi says it's over limit bytes, or it grew past limit
// while read (it isn't cut).
func ReadAll(f *os.File, fi fs.FileInfo, limit int64) ([]byte, error) {
	if fi.Size() > limit {
		return nil, &fs.PathError{Op: "read", Path: f.Name(), Err: tooLargeError(limit)}
	}
	b, err := io.ReadAll(io.LimitReader(f, limit+1))
	if err == nil && int64(len(b)) > limit {
		return nil, &fs.PathError{Op: "read", Path: f.Name(), Err: tooLargeError(limit)}
	}
	return b, err
}

// regular says why path, as stat sees it, isn't a regular file, if it
// isn't.
func regular(path string, stat func(string) (fs.FileInfo, error)) error {
	fi, err := stat(path)
	if err == nil && !fi.Mode().IsRegular() {
		err = notRegular(path)
	}
	return err
}

// checked keeps f, opened as path, if it's a regular file.
func checked(f *os.File, path string) (*os.File, fs.FileInfo, error) {
	fi, err := f.Stat()
	if err == nil && !fi.Mode().IsRegular() {
		err = notRegular(path)
	}
	if err != nil {
		_ = f.Close()
		return nil, nil, err
	}
	return f, fi, nil
}

func notRegular(path string) error {
	return &fs.PathError{Op: "open", Path: path, Err: ErrNotRegular}
}

// tooLargeError is ErrTooLarge with the most read: "larger than 64 MiB".
type tooLargeError int64

func (e tooLargeError) Error() string {
	n := int64(e)
	switch {
	case n >= 1<<20 && n%(1<<20) == 0:
		return fmt.Sprintf("larger than %d MiB", n>>20)
	case n >= 1<<10 && n%(1<<10) == 0:
		return fmt.Sprintf("larger than %d KiB", n>>10)
	}
	return fmt.Sprintf("larger than %d bytes", n)
}

func (tooLargeError) Is(err error) bool { return err == ErrTooLarge }
