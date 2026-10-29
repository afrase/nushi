// Package jsonsettings changes an agent's JSON settings file one key at
// a time (ADR 0051's way): the rest kept, the file replaced at once.
package jsonsettings

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"syscall"

	"github.com/afrase/nushi/internal/atomicfile"
)

// maxFile is the largest settings file read.
const maxFile = 64 << 20

// mu is held from a file's read to its write, so two of Nushi's changes
// can't lose one another (an agent's own write still can: it doesn't ask).
var mu sync.Mutex

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
// back through atomicfile.Rewrite: other keys kept, the file replaced at
// once with its mode, a new one made private with its folder; a link
// (your dotfiles') followed, to change the file it points at. created
// says there was none.
func Edit(path string, change func(map[string]json.RawMessage) error) (created bool, err error) {
	mu.Lock()
	defer mu.Unlock()
	b, err := ReadFile(path)
	out, created, err := apply(path, b, err, change)
	if err != nil {
		return false, err
	}
	return created, atomicfile.Rewrite(path, out)
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
	mu.Lock()
	defer mu.Unlock()
	b, err := readIn(root, name)
	out, created, err := apply(filepath.Join(base, name), b, err, change)
	if err != nil {
		return false, err
	}
	return created, writeIn(root, name, out)
}

// apply changes the settings file at path, b as read (readErr: a missing
// file has none), through change, and returns its new text; created says
// it was missing.
func apply(path string, b []byte, readErr error, change func(map[string]json.RawMessage) error) (out []byte, created bool, err error) {
	settings := map[string]json.RawMessage{}
	created = os.IsNotExist(readErr)
	err = readErr
	if err == nil {
		err = json.Unmarshal(b, &settings)
	}
	if err != nil && !created {
		return nil, false, fmt.Errorf("reading %s: %w", path, err)
	}
	if settings == nil { // the file holds null
		settings = map[string]json.RawMessage{}
	}
	if err := change(settings); err != nil {
		return nil, false, fmt.Errorf("%s: %w", path, err)
	}
	out, err = json.MarshalIndent(settings, "", "  ")
	if err != nil {
		return nil, false, err
	}
	return append(out, '\n'), created, nil
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

// writeIn replaces name inside root with data at once
// (atomicfile.ReplaceIn), keeping its mode; a new file is 0644 (a
// repository's settings), its folder made 0755 if it's missing.
func writeIn(root *os.Root, name string, data []byte) error {
	if err := root.MkdirAll(filepath.Dir(name), 0o755); err != nil {
		return err
	}
	mode := os.FileMode(0o644)
	if fi, err := root.Lstat(name); err == nil {
		mode = fi.Mode().Perm()
	}
	return atomicfile.ReplaceIn(root, name, data, mode)
}
