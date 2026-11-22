package store

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"time"
)

// setAside moves path, a file that doesn't parse (readErr), beside it as
// <name>.unreadable-<time>, byte for byte, so nothing written later
// replaces bytes Nushi couldn't read; the log says so, never what the file
// holds. A name already taken, or a rename that fails, is an error, and
// the file stays.
func setAside(path string, readErr error) error {
	name := filepath.Base(path)
	aside := path + ".unreadable-" + time.Now().Format("2006-01-02T15-04-05.000000")
	if _, err := os.Lstat(aside); err == nil {
		return fmt.Errorf("%s doesn't read, and %s is taken", name, filepath.Base(aside))
	}
	if err := os.Rename(path, aside); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return fmt.Errorf("%s doesn't read and can't be set aside: %w", name, err)
	}
	attrs := []any{"file", name, "as", filepath.Base(aside)}
	if syntax := (*json.SyntaxError)(nil); errors.As(readErr, &syntax) {
		attrs = append(attrs, "at", syntax.Offset)
	}
	slog.Warn("set aside a file that doesn't parse", attrs...)
	return nil
}
