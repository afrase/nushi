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
	settings := map[string]json.RawMessage{}
	b, err := ReadFile(path)
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
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil { //nolint:gosec // a .claude folder, as Claude makes it
		return false, err
	}
	mode := os.FileMode(0o644)
	if fi, err := os.Lstat(path); err == nil {
		mode = fi.Mode().Perm()
	}
	return created, atomicfile.Replace(path, append(out, '\n'), mode)
}
