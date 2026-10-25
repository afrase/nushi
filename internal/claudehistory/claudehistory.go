// Package claudehistory puts a copy of a Claude Code session's transcript
// into another folder's history, where claude-agent-acp's session/fork looks
// for it. Claude keeps each session's transcript in its projects folder,
// under a folder named after the session's cwd. This is Claude's private
// layout (Claude Code 2.1.308, claude-agent-acp 0.94.0): see ADR 0014.
package claudehistory

import (
	"bytes"
	"cmp"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"unicode/utf16"
)

// Projects returns Claude's projects folder: $CLAUDE_CONFIG_DIR/projects,
// or ~/.claude/projects.
func Projects() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(cmp.Or(os.Getenv("CLAUDE_CONFIG_DIR"), filepath.Join(home, ".claude")), "projects"), nil
}

// Copy copies session id's transcript (<id>.jsonl) from folder from's
// history into folder to's, and returns a function that removes the copy
// again. The original stays. When both folders have the same history
// folder there is nothing to copy (or remove); a transcript already in to's
// history is never replaced, unless it is the start of this one: a copy a
// move left when the daemon died before removing it.
func Copy(projects, id, from, to string) (remove func() error, err error) {
	none := func() error { return nil }
	src, dst, err := paths(projects, id, from, to)
	if err != nil || src == dst {
		return none, err
	}
	b, err := os.ReadFile(src)
	if err != nil {
		return nil, fmt.Errorf("Claude's history of the session isn't where Nushi looks for it: %w", err)
	}
	if there, err := os.ReadFile(dst); !errors.Is(err, fs.ErrNotExist) && (err != nil || !bytes.HasPrefix(b, there)) {
		return nil, fmt.Errorf("Claude's history of %s already has session %s", to, id)
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o700); err != nil {
		return nil, err
	}
	tmp := dst + ".nushi-tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return nil, err
	}
	if err := os.Rename(tmp, dst); err != nil {
		return nil, err
	}
	return func() error { return os.Remove(dst) }, nil
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
		os.Rename(dir, strings.TrimSuffix(dst, ".jsonl")) // when it has one
	}
	return os.Rename(src, dst)
}

// paths returns where session id's transcript is in folder from's history
// and in folder to's.
func paths(projects, id, from, to string) (src, dst string, err error) {
	if id == "" || strings.ContainsAny(id, `/\`) || strings.HasPrefix(id, ".") {
		return "", "", fmt.Errorf("%q is not a session id", id)
	}
	return filepath.Join(projects, dirName(from), id+".jsonl"), filepath.Join(projects, dirName(to), id+".jsonl"), nil
}

// Has reports whether Claude keeps session id's transcript in folder's
// history (it writes one once the session has a message).
func Has(projects, id, folder string) bool {
	fi, err := os.Stat(filepath.Join(projects, dirName(folder), id+".jsonl"))
	return err == nil && fi.Size() > 0
}

// dirName is the name Claude gives a folder's history: the folder's real
// path with each UTF-16 unit that isn't an ASCII letter or digit replaced by
// "-", and past 200 characters cut short and followed by a hash of the path.
// Claude also puts the path in Unicode NFC first; that isn't done here, so
// a path with decomposed accents gets another name than Claude's.
func dirName(folder string) string {
	if resolved, err := filepath.EvalSymlinks(folder); err == nil {
		folder = resolved
	}
	var b strings.Builder
	var hash int32 // JavaScript's usual string hash: h*31 + unit, in 32 bits
	for _, u := range utf16.Encode([]rune(folder)) {
		hash = hash*31 + int32(u)
		if u < 128 && ('a' <= u && u <= 'z' || 'A' <= u && u <= 'Z' || '0' <= u && u <= '9') {
			b.WriteByte(byte(u))
		} else {
			b.WriteByte('-')
		}
	}
	name := b.String()
	if len(name) <= 200 {
		return name
	}
	h := int64(hash)
	if h < 0 {
		h = -h
	}
	return name[:200] + "-" + strconv.FormatInt(h, 36)
}
