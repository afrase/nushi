package regularfile

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// files makes a folder with a file of each kind: a regular file, a
// link to it, a link to /dev/zero, a fifo and a folder.
func files(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "file"), "text")
	testcheck.NoErr(t, os.Symlink("file", filepath.Join(dir, "link")))
	testcheck.NoErr(t, os.Symlink("/dev/zero", filepath.Join(dir, "zero")))
	testcheck.NoErr(t, syscall.Mkfifo(filepath.Join(dir, "fifo"), 0o600))
	testcheck.NoErr(t, os.Mkdir(filepath.Join(dir, "folder"), 0o700))
	return dir
}

// Only a regular file is read, a link to one only when followed; nothing
// waits on the fifo or reads /dev/zero; a file over the most is refused.
func TestRead(t *testing.T) {
	dir := files(t)
	root, err := os.OpenRoot(dir)
	testcheck.NoErr(t, err)
	defer root.Close() //nolint:errcheck // read-only
	open := func(name string, follow bool) ([]byte, error) {
		f, fi, err := Open(filepath.Join(dir, name), follow)
		if err != nil {
			return nil, err
		}
		defer f.Close() //nolint:errcheck // read-only
		return ReadAll(f, fi, 100)
	}
	openIn := func(name string, follow bool) ([]byte, error) {
		f, fi, err := OpenIn(root, name, follow)
		if err != nil {
			return nil, err
		}
		defer f.Close() //nolint:errcheck // read-only
		return ReadAll(f, fi, 100)
	}
	for _, c := range []struct {
		name string
		read func() ([]byte, error)
		want string
		err  error
	}{
		{"a file", func() ([]byte, error) { return Read(filepath.Join(dir, "file"), 100) }, "text", nil},
		{"a link, followed", func() ([]byte, error) { return Read(filepath.Join(dir, "link"), 100) }, "text", nil},
		{"/dev/zero through a link", func() ([]byte, error) { return Read(filepath.Join(dir, "zero"), 100) }, "", ErrNotRegular},
		{"a fifo", func() ([]byte, error) { return Read(filepath.Join(dir, "fifo"), 100) }, "", ErrNotRegular},
		{"a folder", func() ([]byte, error) { return Read(filepath.Join(dir, "folder"), 100) }, "", ErrNotRegular},
		{"nothing", func() ([]byte, error) { return Read(filepath.Join(dir, "none"), 100) }, "", fs.ErrNotExist},
		{"too large", func() ([]byte, error) { return Read(filepath.Join(dir, "file"), 3) }, "", ErrTooLarge},
		{"a file, not following", func() ([]byte, error) { return open("file", false) }, "text", nil},
		{"a link, not followed", func() ([]byte, error) { return open("link", false) }, "", ErrNotRegular},
		{"a fifo, not following", func() ([]byte, error) { return open("fifo", false) }, "", ErrNotRegular},
		{"in root: a file", func() ([]byte, error) { return ReadIn(root, "file", 100) }, "text", nil},
		{"in root: a link inside it", func() ([]byte, error) { return ReadIn(root, "link", 100) }, "text", nil},
		{"in root: a link out of it", func() ([]byte, error) { return ReadIn(root, "zero", 100) }, "", nil},
		{"in root: a fifo", func() ([]byte, error) { return ReadIn(root, "fifo", 100) }, "", ErrNotRegular},
		{"in root: too large", func() ([]byte, error) { return ReadIn(root, "file", 3) }, "", ErrTooLarge},
		{"in root: a link, not followed", func() ([]byte, error) { return openIn("link", false) }, "", ErrNotRegular},
		{"in root: a file, not following", func() ([]byte, error) { return openIn("file", false) }, "text", nil},
	} {
		b, err := c.read()
		switch {
		case c.want != "" && (err != nil || string(b) != c.want):
			t.Errorf("%s: %q, %v; want %q", c.name, b, err, c.want)
		case c.want == "" && err == nil:
			t.Errorf("%s: read %q", c.name, b)
		case c.err != nil && !errors.Is(err, c.err):
			t.Errorf("%s: %v, want %v", c.name, err, c.err)
		}
	}
}

// A file that grows past the most after its stat is refused, not cut.
func TestGrowsPast(t *testing.T) {
	path := filepath.Join(t.TempDir(), "file")
	testcheck.Write(t, path, "text")
	f, fi, err := Open(path, false)
	testcheck.NoErr(t, err)
	defer f.Close() //nolint:errcheck // read-only
	testcheck.Write(t, path, "text and more")
	if b, err := ReadAll(f, fi, 5); !errors.Is(err, ErrTooLarge) {
		t.Fatalf("%q, %v", b, err)
	}
}

// The error says the most read.
func TestTooLargeSays(t *testing.T) {
	for limit, want := range map[int64]string{64 << 20: "64 MiB", 4 << 10: "4 KiB", 100: "100 bytes", 1<<20 + 1: "1048577 bytes"} {
		if got := tooLargeError(limit).Error(); !strings.HasSuffix(got, " "+want) {
			t.Errorf("%d: %s", limit, got)
		}
	}
}
