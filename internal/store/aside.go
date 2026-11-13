package store

import (
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"time"
)

// unparsed is a file that was read but isn't the JSON it should be: a
// hand edit's typo, or a file cut short.
type unparsed struct{ err error }

func (u *unparsed) Error() string { return u.err.Error() }
func (u *unparsed) Unwrap() error { return u.err }

// clearForWrite makes way for a write of path that replaces a file whose
// read failed with readErr (nil: it read, or there was none). A file that
// doesn't parse is set aside, beside it as <name>.unreadable-<time>, so
// the write never replaces bytes Nushi couldn't read and nothing in them
// is lost; one that can't be read at all refuses the write, saying so.
func clearForWrite(path string, readErr error) error {
	if readErr == nil {
		return nil
	}
	name := filepath.Base(path)
	if u := (*unparsed)(nil); !errors.As(readErr, &u) {
		return fmt.Errorf("%s can't be read, so it isn't written over: %w", name, readErr)
	}
	aside := path + ".unreadable-" + time.Now().Format("2006-01-02T15-04-05.000000")
	if _, err := os.Lstat(aside); err == nil {
		return fmt.Errorf("%s doesn't read, and %s is taken", name, filepath.Base(aside))
	}
	if err := os.Rename(path, aside); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return fmt.Errorf("%s doesn't read (%w) and can't be set aside: %w", name, readErr, err)
	}
	slog.Warn("set aside a file that doesn't read", "file", name, "as", filepath.Base(aside), "err", readErr)
	return nil
}
