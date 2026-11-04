package claudehistory

import (
	"os"
	"path/filepath"
	"testing"
)

// Gone is true only when the folder's history folder can be read and the
// transcript isn't in it.
func TestGone(t *testing.T) {
	projects, folder := t.TempDir(), t.TempDir()
	if local(projects).HistoryGone("s1", folder) {
		t.Error("gone with no history folder")
	}
	dir := historyDir(projects, folder)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if !local(projects).HistoryGone("s1", folder) {
		t.Error("not gone from an empty history folder")
	}
	if err := os.WriteFile(filepath.Join(dir, "s1.jsonl"), []byte("{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if local(projects).HistoryGone("s1", folder) || !local(projects).HistoryGone("s2", folder) {
		t.Error("s1 is there, s2 isn't")
	}
	if local(projects).HistoryGone("../s2", folder) || local(projects).HistoryGone("", folder) {
		t.Error("gone for a bad id")
	}
	if err := os.Chmod(dir, 0); err != nil {
		t.Fatal(err)
	}
	defer os.Chmod(dir, 0o700) //nolint:errcheck // for the cleanup
	if local(projects).HistoryGone("s2", folder) {
		t.Error("gone from a history folder that can't be read")
	}
}

// local is the Local of a projects folder.
func local(projects string) Local { return Local{Projects: projects} }
