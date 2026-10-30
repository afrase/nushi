// Ported from the Claude Agent SDK for Python (commit 27858cbb,
// src/claude_agent_sdk/_internal/sessions.py), MIT License,
// Copyright (c) 2025 Anthropic, PBC: see ../NOTICE. Modified: restructured
// as Go, the functions a Store's methods; folder names are counted and
// hashed by UTF-16 unit, as the CLI does.

// Package sessions reads and changes the Claude CLI's session transcripts on
// disk: listing sessions, one session's details and messages, its subagents'
// messages, forking and deleting. A Store holds them.
//
// The CLI keeps each session as <config>/projects/<folder>/<id>.jsonl, the
// folder named after the session's working directory, and its subagents'
// transcripts under <folder>/<id>/subagents/. The layout is the CLI's own and
// undocumented; Anthropic's Agent SDKs read and write it the same way, and
// this package is a port of the Python SDK's helpers.
package sessions

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf16"
)

// maxName is the longest folder name the CLI keeps whole; a longer one is
// cut there and given a hash of the path.
const maxName = 200

// ErrInvalidID is the error for an id that isn't a session's: the CLI
// names sessions by UUID, so no session has it.
var ErrInvalidID = errors.New("not a session id")

var idRE = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// checkID refuses anything but a UUID, which is what the CLI names
// sessions; it also keeps a path out of a file name.
func checkID(id string) error {
	if !idRE.MatchString(id) {
		return fmt.Errorf("%q: %w", id, ErrInvalidID)
	}
	return nil
}

// newUUID returns a random (version 4) UUID, as the CLI names sessions and
// records.
func newUUID() string {
	var b [16]byte
	_, _ = rand.Read(b[:]) // never fails (crypto/rand)
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	h := hex.EncodeToString(b[:])
	return h[:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:]
}

// notFound is the error for a session or subagent that isn't on disk; it
// matches fs.ErrNotExist.
func notFound(what string) error {
	return fmt.Errorf("%s: %w", what, fs.ErrNotExist)
}

// Store is the CLI's session transcripts in one config folder. The zero
// Store is the CLI's default folder.
//
// Its methods that read or change one session take the session's id, then
// the working directory to look from: its project folder first, then its
// git repository's other worktrees' (the CLI resumes a session from any of
// them); "" looks in every project folder.
type Store struct {
	// ConfigDir is the CLI's config folder; "" is $CLAUDE_CONFIG_DIR, else
	// ~/.claude.
	ConfigDir string
}

// projects returns the projects folder in the config folder.
func (s Store) projects() (string, error) {
	configDir := s.ConfigDir
	if configDir == "" {
		configDir = os.Getenv("CLAUDE_CONFIG_DIR")
	}
	if configDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("finding Claude's config folder: %w", err)
		}
		configDir = filepath.Join(home, ".claude")
	}
	return filepath.Join(configDir, "projects"), nil
}

// ProjectDir returns the folder in which the CLI keeps the transcripts of
// sessions run in cwd: cwd's real path with every UTF-16 unit that isn't an
// ASCII letter or digit replaced by "-", and past 200 characters cut and
// followed by a base-36 hash of the path. It returns "" when ConfigDir is ""
// and there is no home folder.
//
// The CLI also puts the path in Unicode NFC first; ProjectDir doesn't (the
// standard library has no NFC), so a path spelled with decomposed accents
// gets another name. The CLI's own builds may hash a long path otherwise
// (the Python SDK says Bun's hash); reads here then find the folder by its
// first 200 characters.
func (s Store) ProjectDir(cwd string) string {
	projects, err := s.projects()
	if err != nil {
		return ""
	}
	return filepath.Join(projects, folderName(canonical(cwd)))
}

// canonical is path as the CLI names it: absolute, links resolved.
func canonical(path string) string {
	if abs, err := filepath.Abs(path); err == nil {
		path = abs
	}
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		return resolved
	}
	return path
}

// folderName is the name of path's project folder (see ProjectDir).
func folderName(path string) string {
	units := utf16.Encode([]rune(path))
	b := make([]byte, len(units))
	var hash int32 // JavaScript's string hash: h*31 + unit, kept to 32 bits
	for i, u := range units {
		hash = hash*31 + int32(u)
		if 'a' <= u && u <= 'z' || 'A' <= u && u <= 'Z' || '0' <= u && u <= '9' {
			b[i] = byte(u)
		} else {
			b[i] = '-'
		}
	}
	if len(b) <= maxName {
		return string(b)
	}
	h := int64(hash)
	if h < 0 {
		h = -h
	}
	return string(b[:maxName]) + "-" + strconv.FormatInt(h, 36)
}

// findProjectDir returns path's project folder in projects. A long path's
// folder is also found by its first 200 characters, since the CLI's hash
// can differ from folderName's.
func findProjectDir(projects, path string) (string, bool) {
	name := folderName(path)
	if fi, err := os.Stat(filepath.Join(projects, name)); err == nil && fi.IsDir() {
		return filepath.Join(projects, name), true
	}
	if len(name) <= maxName {
		return "", false
	}
	for _, dir := range subdirs(projects) {
		if strings.HasPrefix(dir, name[:maxName]+"-") {
			return filepath.Join(projects, dir), true
		}
	}
	return "", false
}

// subdirs lists the folders in dir by name; none when it can't be read.
func subdirs(dir string) []string {
	entries, _ := os.ReadDir(dir)
	var out []string
	for _, e := range entries {
		if e.IsDir() {
			out = append(out, e.Name())
		}
	}
	return out
}

// worktrees lists the worktrees of the git repository dir is in, the main
// one first; none outside a repository or without git. A session started in
// one worktree is found from another, as the CLI's own resume does. It is a
// variable so tests can stand in for git.
var worktrees = func(dir string) []string {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	// Listing runs no hook or filter; fsmonitor is off so the repository's
	// config can't start a program either.
	cmd := exec.CommandContext(ctx, "git", "-c", "core.fsmonitor=false", "worktree", "list", "--porcelain")
	cmd.Dir = dir
	out, err := cmd.Output()
	if err != nil {
		return nil
	}
	return parseWorktrees(string(out))
}

// parseWorktrees reads the paths out of `git worktree list --porcelain`.
func parseWorktrees(out string) []string {
	var paths []string
	for line := range strings.SplitSeq(out, "\n") {
		if path, ok := strings.CutPrefix(line, "worktree "); ok {
			paths = append(paths, path)
		}
	}
	return paths
}

// candidates returns the project folders where a session of cwd may be, in
// the order to look: cwd's own, then its repository's other worktrees'; with
// no cwd, every project folder.
func candidates(projects, cwd string) []string {
	if cwd == "" {
		dirs := subdirs(projects)
		for i, d := range dirs {
			dirs[i] = filepath.Join(projects, d)
		}
		return dirs
	}
	dir := canonical(cwd)
	var out []string
	if pd, ok := findProjectDir(projects, dir); ok {
		out = append(out, pd)
	}
	for _, wt := range worktrees(dir) {
		if wt == dir {
			continue
		}
		if pd, ok := findProjectDir(projects, wt); ok {
			out = append(out, pd)
		}
	}
	return out
}

// find returns the path of session id's transcript, looking where
// candidates says. Only a file with something in it counts, as the CLI
// writes an empty one in some folders.
func (s Store) find(id, cwd string) (string, error) {
	if err := checkID(id); err != nil {
		return "", err
	}
	projects, err := s.projects()
	if err != nil {
		return "", err
	}
	for _, dir := range candidates(projects, cwd) {
		path := filepath.Join(dir, id+".jsonl")
		if fi, err := os.Stat(path); err == nil && fi.Mode().IsRegular() && fi.Size() > 0 {
			return path, nil
		}
	}
	return "", notFound("session " + id)
}
