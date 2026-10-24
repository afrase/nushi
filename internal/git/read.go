package git

import (
	"context"
	"fmt"
	"io"
	"os"
	"syscall"
)

// worktree reads a file as git sees it, at most maxText+1 bytes of it: a
// symlink is its target's path. Anything but a regular file (a folder, a
// fifo, a device) isn't read.
func worktree(path string) ([]byte, error) {
	fi, err := os.Lstat(path)
	switch {
	case err != nil:
		return nil, err
	case fi.Mode()&os.ModeSymlink != 0:
		target, err := os.Readlink(path)
		return []byte(target), err
	case !fi.Mode().IsRegular():
		return nil, fmt.Errorf("%s is not a file", path)
	}
	// Not following a link, nor waiting on a fifo, put there since.
	f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() {
		return nil, fmt.Errorf("%s is not a file", path)
	}
	return io.ReadAll(io.LimitReader(f, maxText+1))
}

// show returns a file of commit rev (its path relative to folder), at most
// maxText+1 bytes of it.
func show(ctx context.Context, folder, rev, path string) ([]byte, error) {
	var out capped
	_, err := runTo(ctx, folder, nil, &out, "show", "--no-textconv", rev+":./"+path)
	return out.b, err
}

// capped keeps the first maxText+1 bytes written to it and drops the rest.
type capped struct{ b []byte }

func (c *capped) Write(p []byte) (int, error) {
	if room := maxText + 1 - len(c.b); room > 0 {
		c.b = append(c.b, p[:min(room, len(p))]...)
	}
	return len(p), nil
}
