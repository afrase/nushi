// Package claudehistory reads Claude Code's own record of its sessions:
// Local is claude.Harness with that, for chats on this Mac. Claude keeps
// each session's transcript in its projects folder, under a folder named
// after the session's cwd. This is Claude's private layout (Claude Code
// 2.1.308): see ADR 0014.
package claudehistory

import (
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/afrase/claude-acp-go/claudeagent/sessions"

	"github.com/afrase/nushi/internal/claude"
)

// Local is claude.Harness with what reads Claude's files and processes on
// this Mac, its projects folder being Projects. It lives here as this
// package needs claude, for its config folder. Tests use claude.Harness alone.
type Local struct {
	claude.Harness
	Projects string
	// Workflows keeps what was read of the workflows being followed; nil
	// reads each whole every time.
	Workflows *Runs
}

// Projects returns Claude's projects folder, in its config folder
// (claude.ConfigDir); an error when there's no home folder.
func Projects() (string, error) {
	if _, err := os.UserHomeDir(); err != nil {
		return "", err
	}
	return filepath.Join(claude.ConfigDir(), "projects"), nil
}

// transcriptPath returns where session id's transcript is in folder's
// history; an error for an id that would name another path.
func transcriptPath(projects, id, folder string) (string, error) {
	if id == "" || strings.ContainsAny(id, `/\`) || strings.HasPrefix(id, ".") {
		return "", fmt.Errorf("%q is not a session id", id)
	}
	return filepath.Join(historyDir(projects, folder), id+".jsonl"), nil
}

// HistoryGone reports that Claude no longer keeps session id's transcript,
// for certain: folder's history folder is there and can be read, the
// transcript isn't in it (Claude Code deletes those older than
// cleanupPeriodDays when it starts), and it is in no other folder's
// history either (elsewhere). A history folder that's missing or can't be
// read says nothing: another CLAUDE_CONFIG_DIR, or a folder whose name
// Claude spells otherwise (see sessions.Store.ProjectDir).
func (l Local) HistoryGone(id, folder string) bool {
	if _, err := transcriptPath(l.Projects, id, folder); err != nil {
		return false
	}
	dir := historyDir(l.Projects, folder)
	f, err := os.Open(dir)
	if err != nil {
		return false
	}
	defer f.Close() //nolint:errcheck // read-only
	if fi, err := f.Stat(); err != nil || !fi.IsDir() {
		return false
	}
	if _, err := f.Readdirnames(1); err != nil && !errors.Is(err, io.EOF) {
		return false
	}
	_, err = os.Lstat(filepath.Join(dir, id+".jsonl"))
	return errors.Is(err, fs.ErrNotExist) && !l.elsewhere(id, dir)
}

// elsewhere says a history folder other than home holds session id's
// transcript, or that it can't be told (the projects folder or one of its
// history folders can't be read). Claude moves a session's transcript to
// the history folder of a worktree the session enters (its EnterWorktree
// tool) and back when it leaves (docs/facts/claude.md), so the folder a
// chat started in lacks it while the session lives. Asked only once home
// lacks the transcript: a look at each history folder, reading none.
func (l Local) elsewhere(id, home string) bool {
	entries, err := os.ReadDir(l.Projects)
	if err != nil {
		return true
	}
	for _, e := range entries {
		dir := filepath.Join(l.Projects, e.Name())
		if !e.IsDir() || dir == home {
			continue
		}
		if _, err := os.Lstat(filepath.Join(dir, id+".jsonl")); !errors.Is(err, fs.ErrNotExist) {
			return true // it is there, or the folder can't be looked in
		}
	}
	return false
}

// historyDir is folder's history folder in projects, named as Claude names
// it (sessions.Store.ProjectDir, whose projects folder is taken by name
// only, as tests pass any folder).
func historyDir(projects, folder string) string {
	return filepath.Join(projects, filepath.Base(sessions.Store{ConfigDir: filepath.Dir(projects)}.ProjectDir(folder)))
}
