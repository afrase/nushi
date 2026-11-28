// Package jsonsettings reads an agent's settings files, and changes a
// JSON one a key at a time (ADR 0051's way): every other byte kept
// (change.go), the file replaced at once.
package jsonsettings

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/regularfile"
)

// maxFile is the largest settings file read.
const maxFile = 64 << 20

// mu is held from a file's read to its write, so two of Nushi's changes
// can't lose one another (an agent's own write still can: it doesn't ask).
var mu sync.Mutex

// ReadFile reads an agent's settings file (JSON, or Codex's TOML, omp's
// YAML, opencode's JSONC): a regular file of at most 64 MiB, a link to one
// followed; a fifo or device fails at once rather than waiting.
func ReadFile(path string) ([]byte, error) { return regularfile.Read(path, maxFile) }

// Read reads the JSON settings file at path into v, through ReadFile; a
// missing one is empty, leaving v as it was. Its error says the file
// "doesn't read", as every agent's Skills page words it (NoSwitch).
func Read(path string, v any) error {
	b, err := ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err == nil {
		err = json.Unmarshal(b, v)
	}
	if err != nil {
		return fmt.Errorf("%s doesn't read: %w", path, err)
	}
	return nil
}

// Edit reads the JSON settings file at path, changes it through change
// (which gets its settings by key; none for a new file) and writes it
// back through atomicfile.Rewrite: only the keys change changed are
// written, every other byte kept (a change the text can't take that way
// is refused, the file left as it was), the file replaced at
// once with its mode, a new one made private with its folder; a link
// (your dotfiles') followed, to change the file it points at. A file you
// locked (read-only), a link to nothing, a loop of links and a folder
// that can't be written are refused in plain words (writable, plain).
// created says there was none and one was made.
func Edit(path string, change func(map[string]json.RawMessage) error) (created bool, err error) {
	mu.Lock()
	defer mu.Unlock()
	b, err := ReadFile(path)
	if loop(err) {
		return false, plain(path, err)
	}
	out, created, err := apply(path, b, err, change)
	if err != nil || bytes.Equal(out, b) && !created {
		return false, err // unchanged: not written
	}
	if err := writable(path); err != nil {
		return false, err
	}
	if err := atomicfile.Rewrite(path, out); err != nil {
		return false, plain(path, err)
	}
	return created, nil
}

// EditIn is Edit for the file name (a relative path) inside the folder
// base, through an os.Root of base: no folder on the way, nor the file,
// can lead out of base, even one swapped for a link meanwhile (a
// repository's .claude or .pig). A link on the way is followed as PiG
// follows it, while it stays in base (linked); os.Root then holds the
// write to base, should a link be swapped in meanwhile.
func EditIn(base, name string, change func(map[string]json.RawMessage) error) (created bool, err error) {
	root, err := os.OpenRoot(base)
	if err != nil {
		return false, err
	}
	defer root.Close() //nolint:errcheck // nothing written through it
	mu.Lock()
	defer mu.Unlock()
	full := filepath.Join(base, name)
	if name, err = linked(base, name); err != nil {
		return false, plain(full, err)
	}
	b, err := regularfile.ReadIn(root, name, maxFile)
	out, created, err := apply(filepath.Join(base, name), b, err, change)
	if err != nil || bytes.Equal(out, b) && !created {
		return false, err // unchanged: not written
	}
	if err := writeIn(root, filepath.Join(base, name), name, out); err != nil {
		return false, plain(full, err)
	}
	return created, nil
}

// apply changes the settings file at path, b as read (readErr: a missing
// file has none), through change, and returns its new text; created says
// it was missing. Only what change changed is written into b (changed);
// a missing file, or one holding null, is written whole.
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
	whole := created || settings == nil // nothing to keep
	if settings == nil {                // the file holds null
		settings = map[string]json.RawMessage{}
	}
	if err := change(settings); err != nil {
		return nil, false, fmt.Errorf("%s: %w", path, err)
	}
	if !whole {
		out, err := changed(b, settings)
		if err != nil {
			return nil, false, fmt.Errorf("%w: change it in %s", err, path)
		}
		return out, false, nil
	}
	var w bytes.Buffer
	enc := json.NewEncoder(&w)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(settings); err != nil {
		return nil, false, err
	}
	return []byte(unescapeHTML(w.String())), created, nil
}

// SetKeyIn is EditIn for one top-level key: change gets its value (nil
// when absent) and returns the new one. For a file the repository may
// commit, where a rewrite of the rest would be a diff nobody asked for
// (every edit keeps the rest's bytes now).
func SetKeyIn(base, name, key string, change func(old json.RawMessage) (json.RawMessage, error)) error {
	_, err := EditIn(base, name, func(m map[string]json.RawMessage) error {
		v, err := change(m[key])
		m[key] = v
		return err
	})
	return err
}

// writeIn replaces name inside root with data at once
// (atomicfile.ReplaceIn), keeping its mode; a new file is 0644 (a
// repository's settings), its folder made 0755 if it's missing. name is
// no link: linked has followed it. A file without its owner's write bit
// is refused, path naming it: the user locked it, and PiG fails there
// too. A folder Nushi can't write in fails (plain words it, in EditIn):
// the new file is made beside the old one, where PiG writes a file that
// is there in place.
func writeIn(root *os.Root, path, name string, data []byte) error {
	mode := os.FileMode(0o644)
	if fi, err := root.Stat(name); err == nil {
		mode = fi.Mode().Perm()
		if mode&0o200 == 0 {
			return readOnly(path)
		}
	}
	if err := root.MkdirAll(filepath.Dir(name), 0o755); err != nil {
		return err
	}
	return atomicfile.ReplaceIn(root, name, data, mode)
}

// linked is the file name inside base is, as the system finds it: a link
// on its way (the file, or a folder such as a linked .pig) followed, the
// folders resolved for real before a link's target is joined, so ".."
// after a linked folder goes where the system goes (PiG writes that
// file). The result, relative to base's real path, must still be inside
// it: one that leads out is refused in plain words, as is a link to
// nothing, no folder made for it (PiG creates the link's target when
// the target's folder is there, and fails when it isn't). A missing file
// whose folders are there is name as resolved, to be made.
func linked(base, name string) (string, error) {
	full := filepath.Join(base, name)
	inside, err := filepath.EvalSymlinks(base)
	if err != nil {
		return "", err
	}
	var target string
	switch fi, err := os.Lstat(full); {
	case err == nil && fi.Mode()&os.ModeSymlink != 0:
		if target, err = filepath.EvalSymlinks(full); errors.Is(err, fs.ErrNotExist) {
			return "", fmt.Errorf("%s is a link to a missing file: Nushi leaves it as it is", full)
		} else if err != nil {
			return "", fmt.Errorf("%s: %w", full, err)
		}
	case err == nil || errors.Is(err, fs.ErrNotExist):
		if target, err = resolved(full); err != nil {
			return "", err
		}
	default:
		return "", err
	}
	rel, err := filepath.Rel(inside, target)
	if err != nil || !filepath.IsLocal(rel) {
		return "", outOfFolder(full)
	}
	return rel, nil
}

// resolved is path, not itself a link, with the deepest folder on its way
// that is there resolved for real; a link to nothing on the way is
// refused.
func resolved(path string) (string, error) {
	dir, rest := filepath.Dir(path), filepath.Base(path)
	for {
		r, err := filepath.EvalSymlinks(dir)
		if err == nil {
			return filepath.Join(r, rest), nil
		}
		if !errors.Is(err, fs.ErrNotExist) {
			return "", err
		}
		if fi, lerr := os.Lstat(dir); lerr == nil && fi.Mode()&os.ModeSymlink != 0 {
			return "", fmt.Errorf("%s is a link to a missing folder: Nushi leaves it as it is", dir)
		}
		if dir == filepath.Dir(dir) {
			return "", err
		}
		dir, rest = filepath.Dir(dir), filepath.Join(filepath.Base(dir), rest)
	}
}

// writable refuses to replace your settings file at path when you locked
// it (no owner's write bit; PiG and the system's own write fail there
// too), through a link or not, or when it or its folder is a link to
// nothing, which Rewrite would otherwise replace with a file or fail on.
// The message names the file the link leads to.
func writable(path string) error {
	if fi, err := os.Lstat(path); err == nil && fi.Mode()&os.ModeSymlink != 0 {
		target, err := filepath.EvalSymlinks(path)
		if errors.Is(err, fs.ErrNotExist) {
			return fmt.Errorf("%s is a link to a missing file: Nushi leaves it as it is", path)
		} else if err != nil {
			return plain(path, err)
		}
		path = target
	}
	if _, err := resolved(path); err != nil {
		return plain(path, err)
	}
	if fi, err := os.Stat(path); err == nil && fi.Mode().Perm()&0o200 == 0 {
		return readOnly(path)
	}
	return nil
}

func readOnly(path string) error {
	return fmt.Errorf("%s is read-only: Nushi leaves it as it is", path)
}

// plain is err, met on the way to path or writing it, in the words the
// other refusals use: a loop of links, a link out of the folder (os.Root's
// refusal of one swapped in since the check), a folder Nushi can't write
// in. Any other error is err.
func plain(path string, err error) error {
	switch {
	case loop(err):
		return fmt.Errorf("%s is a loop of links: Nushi leaves it as it is", path)
	case err != nil && strings.HasSuffix(err.Error(), "path escapes from parent"): // os.Root's, unexported
		return outOfFolder(path)
	case errors.Is(err, fs.ErrPermission):
		return fmt.Errorf("%s can't be written: Nushi leaves it as it is", filepath.Dir(path))
	}
	return err
}

// loop says err is a loop of links: the system's, or EvalSymlinks' own
// (unexported).
func loop(err error) bool {
	return errors.Is(err, syscall.ELOOP) || err != nil && strings.HasSuffix(err.Error(), "EvalSymlinks: too many links")
}

// outOfFolder refuses path, a link that leads out of its folder.
func outOfFolder(path string) error {
	return fmt.Errorf("%s is a link out of its folder: Nushi changes it only inside the folder", path)
}
