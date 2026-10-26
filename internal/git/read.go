package git

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"github.com/afrase/nushi/internal/model"
)

// File reads one of folder's files as it is now, as a change that changes
// nothing (status "unchanged", the text on both sides; Skipped "binary" or
// "too large" as Changes says). path must be inside folder, and not
// through a link that leads out of it; a link itself, or anything but a
// regular file, isn't read.
func File(folder, path string) (model.FileChange, error) {
	if !filepath.IsLocal(path) {
		return model.FileChange{}, fmt.Errorf("%q is not inside the folder", path)
	}
	root, err := os.OpenRoot(folder)
	if err != nil {
		return model.FileChange{}, err
	}
	defer root.Close() //nolint:errcheck // read-only
	if fi, err := root.Lstat(path); err != nil {
		return model.FileChange{}, err
	} else if !fi.Mode().IsRegular() {
		return model.FileChange{}, fmt.Errorf("%s is not a file", path)
	}
	f, err := root.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
	if err != nil {
		return model.FileChange{}, err
	}
	defer f.Close() //nolint:errcheck // read-only
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() {
		return model.FileChange{}, fmt.Errorf("%s is not a file", path)
	}
	b, err := io.ReadAll(io.LimitReader(f, maxText+1))
	if err != nil {
		return model.FileChange{}, err
	}
	c := model.FileChange{Path: filepath.ToSlash(filepath.Clean(path)), Status: "unchanged"}
	switch {
	case bytes.IndexByte(b, 0) >= 0:
		c.Skipped = "binary"
	case len(b) > maxText:
		c.Skipped = "too large"
	default:
		c.Old, c.New = string(b), string(b)
	}
	return c, nil
}

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
	defer f.Close() //nolint:errcheck // read-only
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

// blobs reads files of commits through one git cat-file, rather than a
// git show for each: a branch's hundreds of files took seconds.
type blobs struct {
	folder string
	cmd    *exec.Cmd
	in     io.WriteCloser
	out    *bufio.Reader
}

// openBlobs starts the cat-file lazily, on the first read.
func openBlobs(folder string) *blobs { return &blobs{folder: folder} }

// read is show through the cat-file. A path with a newline, which the
// cat-file's lines can't hold, goes through show.
func (b *blobs) read(ctx context.Context, rev, path string) ([]byte, error) {
	if strings.ContainsAny(rev+path, "\n") {
		return show(ctx, b.folder, rev, path)
	}
	if b.cmd == nil {
		if err := b.start(ctx); err != nil {
			return nil, err
		}
	}
	if _, err := io.WriteString(b.in, rev+":./"+path+"\n"); err != nil {
		return nil, err
	}
	head, err := b.out.ReadString('\n')
	if err != nil {
		return nil, err
	}
	// "<oid> blob <size>", then the contents and a newline; else
	// "<name> missing" (or "ambiguous").
	f := strings.Fields(head)
	if len(f) != 3 || f[1] != "blob" {
		return nil, fmt.Errorf("%s:%s: %s", rev, path, strings.TrimSpace(head))
	}
	size, err := strconv.Atoi(f[2])
	if err != nil {
		return nil, err
	}
	var out capped
	if _, err := io.CopyN(&out, b.out, int64(size)+1); err != nil {
		return nil, err
	}
	out.b = out.b[:min(len(out.b), size)] // not the newline after it
	return out.b, nil
}

func (b *blobs) start(ctx context.Context) error {
	b.cmd = command(ctx, b.folder, nil, "cat-file", "--batch")
	in, err := b.cmd.StdinPipe()
	if err != nil {
		return err
	}
	out, err := b.cmd.StdoutPipe()
	if err != nil {
		return err
	}
	if err := b.cmd.Start(); err != nil {
		return err
	}
	b.in, b.out = in, bufio.NewReaderSize(out, 64<<10)
	return nil
}

// close ends the cat-file, if it started.
func (b *blobs) close() {
	if b.cmd == nil {
		return
	}
	_ = b.in.Close()
	_ = b.cmd.Wait()
}

// capped keeps the first maxText+1 bytes written to it and drops the rest.
type capped struct{ b []byte }

func (c *capped) Write(p []byte) (int, error) {
	if room := maxText + 1 - len(c.b); room > 0 {
		c.b = append(c.b, p[:min(room, len(p))]...)
	}
	return len(p), nil
}
