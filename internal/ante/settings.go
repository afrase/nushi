package ante

import (
	"encoding/json"
	"path/filepath"
	"time"

	"github.com/afrase/nushi/internal/filelock"
	"github.com/afrase/nushi/internal/jsonsettings"
)

// SettingsFile is your Ante settings: $ANTE_HOME/settings.json.
func SettingsFile() string { return filepath.Join(Home(), "settings.json") }

// EditSettings changes your Ante settings through change (jsonsettings.Edit:
// other keys kept, the file replaced at once with its mode) while holding
// Ante's own lock, settings.json.lock beside it (flock; Ante 0.2.14 waits
// on it before it rewrites the file). A file that isn't JSON is refused,
// unwritten.
func EditSettings(change func(map[string]json.RawMessage) error) error {
	unlock, err := filelock.Lock(SettingsFile()+".lock", 5*time.Second)
	if err != nil {
		return err
	}
	defer unlock()
	file := SettingsFile()
	if resolved, err := filepath.EvalSymlinks(file); err == nil {
		file = resolved
	}
	_, err = jsonsettings.Edit(file, change)
	return err
}
