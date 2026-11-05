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

// Has reports whether Claude keeps session id's transcript in folder's
// history (it writes one once the session has a message).
func Has(projects, id, folder string) bool {
	fi, err := os.Stat(filepath.Join(historyDir(projects, folder), id+".jsonl"))
	return err == nil && fi.Size() > 0
}

// HistoryGone reports that Claude no longer keeps session id's transcript in
// folder's history, for certain: the folder's history folder is there and
// can be read, and the transcript isn't in it (Claude Code deletes those
// older than cleanupPeriodDays when it starts). A history folder that's
// missing or can't be read says nothing: another CLAUDE_CONFIG_DIR, or a
// folder whose name Claude spells otherwise (see sessions.Store.ProjectDir).
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
	return errors.Is(err, fs.ErrNotExist)
}

// historyDir is folder's history folder in projects, named as Claude names
// it (sessions.Store.ProjectDir, whose projects folder is taken by name
// only, as tests pass any folder).
func historyDir(projects, folder string) string {
	return filepath.Join(projects, filepath.Base(sessions.Store{ConfigDir: filepath.Dir(projects)}.ProjectDir(folder)))
}
