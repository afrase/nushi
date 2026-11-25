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

// A session that entered a worktree has its transcript in that worktree's
// history folder, not in the folder's it started in (docs/facts/claude.md):
// it isn't gone, and neither is one that can't be told of because another
// history folder can't be read. One that is in no history folder is.
func TestGoneNotWhenTheTranscriptMoved(t *testing.T) {
	projects, folder, worktree := t.TempDir(), t.TempDir(), t.TempDir()
	home, moved := historyDir(projects, folder), historyDir(projects, worktree)
	for _, dir := range []string{home, moved} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(moved, "s1.jsonl"), []byte("{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if local(projects).HistoryGone("s1", folder) {
		t.Error("gone, though the worktree's history folder has the transcript")
	}
	if !local(projects).HistoryGone("s2", folder) {
		t.Error("not gone, though no history folder has the transcript")
	}
	if err := os.Chmod(moved, 0); err != nil {
		t.Fatal(err)
	}
	defer os.Chmod(moved, 0o700) //nolint:errcheck // for the cleanup
	if local(projects).HistoryGone("s2", folder) {
		t.Error("gone, though another history folder can't be read")
	}
}

// local is the Local of a projects folder.
func local(projects string) Local { return Local{Projects: projects} }

// With no Projects of its own, Local reads Claude's projects folder from
// the daemon's environment each time, not once at start: a
// CLAUDE_CONFIG_DIR the login shell exports after the daemon started
// (applied to the daemon's own when Settings › Agents reads it again) is
// where it looks next, as the agents started after then write there.
func TestTheProjectsFolderFollowsTheEnvironment(t *testing.T) {
	folder := t.TempDir()
	first, second := t.TempDir(), t.TempDir()
	for _, config := range []string{first, second} {
		if err := os.MkdirAll(historyDir(filepath.Join(config, "projects"), folder), 0o700); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(historyDir(filepath.Join(first, "projects"), folder), "s1.jsonl"), []byte("{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	var l Local
	t.Setenv("CLAUDE_CONFIG_DIR", first)
	if l.HistoryGone("s1", folder) || !l.HistoryGone("s2", folder) {
		t.Error("the first folder has s1, not s2")
	}
	t.Setenv("CLAUDE_CONFIG_DIR", second)
	if !l.HistoryGone("s1", folder) {
		t.Error("not gone: the projects folder is still the first")
	}
}
