// Package claudehistory reads Claude Code's own record of its sessions:
// Local is claude.Harness with that, for chats on this Mac. Claude keeps
// each session's transcript in its projects folder, under a folder named
// after the session's cwd. This is Claude's private layout (Claude Code
// 2.1.308): see ADR 0014.
package claudehistory

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/afrase/nushi/claudeagent/sessions"
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

// Move moves session id's transcript (and its folder, <id>/) from folder
// from's history into folder to's. One already in to's history that holds
// all of it stays, and the old one goes; nothing to move is no error.
func Move(projects, id, from, to string) error {
	src, dst, err := paths(projects, id, from, to)
	if err != nil || src == dst {
		return err
	}
	old, err := os.ReadFile(src)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if there, err := os.ReadFile(dst); err == nil && !bytes.HasPrefix(there, old) {
		return fmt.Errorf("Claude's history of %s has another session %s", to, id)
	} else if err == nil {
		return os.Remove(src) // a copy made before, which went on since
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o700); err != nil {
		return err
	}
	dir := strings.TrimSuffix(src, ".jsonl")
	if _, err := os.Stat(strings.TrimSuffix(dst, ".jsonl")); errors.Is(err, fs.ErrNotExist) {
		_ = os.Rename(dir, strings.TrimSuffix(dst, ".jsonl")) // when it has one
	}
	return os.Rename(src, dst)
}

// paths returns where session id's transcript is in folder from's history
// and in folder to's.
func paths(projects, id, from, to string) (src, dst string, err error) {
	if id == "" || strings.ContainsAny(id, `/\`) || strings.HasPrefix(id, ".") {
		return "", "", fmt.Errorf("%q is not a session id", id)
	}
	return filepath.Join(historyDir(projects, from), id+".jsonl"), filepath.Join(historyDir(projects, to), id+".jsonl"), nil
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
	if _, _, err := paths(l.Projects, id, folder, folder); err != nil {
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
