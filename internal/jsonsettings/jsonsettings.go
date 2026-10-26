// Package jsonsettings changes an agent's JSON settings file one key at
// a time (ADR 0051's way): the rest kept, the file replaced at once.
package jsonsettings

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"syscall"

	"github.com/afrase/nushi/internal/atomicfile"
)

// maxFile is the largest settings file read.
const maxFile = 64 << 20

// ReadFile reads a regular file of at most 64 MiB (a link to one
// followed); a fifo or device fails at once rather than waiting.
func ReadFile(path string) ([]byte, error) {
	f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NONBLOCK, 0) //nolint:gosec // an agent's settings; a fifo doesn't wait
	if err != nil {
		return nil, err
	}
	defer f.Close() //nolint:errcheck // read-only
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() || fi.Size() > maxFile {
		return nil, fmt.Errorf("%s isn't a regular file of at most 64 MiB", path)
	}
	b, err := io.ReadAll(io.LimitReader(f, maxFile+1))
	if err == nil && len(b) > maxFile {
		err = fmt.Errorf("%s grew past 64 MiB", path)
	}
	return b, err
}

// Edit reads the JSON settings file at path, changes it through change
// (which gets its settings by key; none for a new file) and writes it
// back: other keys kept, the file replaced at once with its mode, a new
// one made with its folder. created says there was none.
func Edit(path string, change func(map[string]json.RawMessage) error) (created bool, err error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil { //nolint:gosec // an agent's settings folder, as the agent makes it
		return false, err
	}
	return EditIn(filepath.Dir(path), filepath.Base(path), change)
}

// EditIn is Edit for the file name (a relative path) inside the folder
// base, through an os.Root of base: no folder on the way, nor the file,
// can lead out of base, even one swapped for a link meanwhile (a
// repository's .claude or .pig).
func EditIn(base, name string, change func(map[string]json.RawMessage) error) (created bool, err error) {
	root, err := os.OpenRoot(base)
	if err != nil {
		return false, err
	}
	defer root.Close() //nolint:errcheck // nothing written through it
	path := filepath.Join(base, name)
	settings := map[string]json.RawMessage{}
	b, err := readIn(root, name)
	created = os.IsNotExist(err)
	if err == nil {
		err = json.Unmarshal(b, &settings)
	}
	if err != nil && !created {
		return false, fmt.Errorf("reading %s: %w", path, err)
	}
	if settings == nil { // the file holds null
		settings = map[string]json.RawMessage{}
	}
	if err := change(settings); err != nil {
		return false, fmt.Errorf("%s: %w", path, err)
	}
	out, err := json.MarshalIndent(settings, "", "  ")
	if err != nil {
		return false, err
	}
	if err := root.MkdirAll(filepath.Dir(name), 0o755); err != nil {
		return false, err
	}
	mode := os.FileMode(0o644)
	if fi, err := root.Lstat(name); err == nil {
		mode = fi.Mode().Perm()
	}
	return created, atomicfile.ReplaceIn(root, name, append(out, '\n'), mode)
}

// readIn is ReadFile for name inside root.
func readIn(root *os.Root, name string) ([]byte, error) {
	f, err := root.OpenFile(name, os.O_RDONLY|syscall.O_NONBLOCK, 0)
	if err != nil {
		return nil, err
	}
	defer f.Close() //nolint:errcheck // read-only
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() || fi.Size() > maxFile {
		return nil, fmt.Errorf("%s isn't a regular file of at most 64 MiB", name)
	}
	b, err := io.ReadAll(io.LimitReader(f, maxFile+1))
	if err == nil && len(b) > maxFile {
		err = fmt.Errorf("%s grew past 64 MiB", name)
	}
	return b, err
}
