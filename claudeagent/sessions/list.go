// Ported from the Claude Agent SDK for Python (commit 27858cbb,
// src/claude_agent_sdk/_internal/sessions.py), MIT License,
// Copyright (c) 2025 Anthropic, PBC: see ../NOTICE. Modified: restructured
// as Go, the functions a Store's methods.

package sessions

import (
	"io"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"time"
)

// liteRead is how much of a transcript's start and end List reads: its
// details sit in the first records and the last ones.
const liteRead = 64 << 10

// Info is what List and Get tell of a session, read from the first and last
// 64 KiB of its transcript and from the file.
type Info struct {
	// ID is the session's id, the transcript's name.
	ID string
	// Summary names the session: its custom title, else the last prompt
	// or summary the CLI recorded, else its first prompt.
	Summary string
	// CustomTitle is the title set for the session (by the user or a fork),
	// else the one the CLI generated; "" when there is none.
	CustomTitle string
	// FirstPrompt is the first prompt the user typed, on one line and at
	// most 200 characters; a slash command's name when there is no other.
	FirstPrompt string
	// GitBranch is the branch recorded last.
	GitBranch string
	// Cwd is the session's working directory as recorded, else the folder
	// it was listed for.
	Cwd string
	// Tag is the session's last tag; "" when it has none.
	Tag string
	// LastModified is when the transcript was last written.
	LastModified time.Time
	// Created is the time of its first record; zero when none has one.
	Created time.Time
	// Size is the transcript's size in bytes.
	Size int64
}

// List returns the sessions of cwd and of its git repository's other
// worktrees, newest first; with no cwd, every project's. It skips
// subagents' transcripts and ones with nothing to name them by. offset
// sessions are skipped and at most limit returned (0 = all). Folders that
// can't be read are skipped.
func (s Store) List(cwd string, limit, offset int) ([]Info, error) {
	projects, err := s.projects()
	if err != nil {
		return nil, err
	}
	var infos []Info
	if cwd == "" {
		for _, dir := range subdirs(projects) {
			infos = append(infos, readProject(filepath.Join(projects, dir), "")...)
		}
		infos = newestByID(infos)
	} else {
		infos = listProject(projects, canonical(cwd))
	}
	slices.SortStableFunc(infos, func(a, b Info) int { return b.LastModified.Compare(a.LastModified) })
	infos = infos[min(max(offset, 0), len(infos)):]
	if limit > 0 && limit < len(infos) {
		infos = infos[:limit]
	}
	return infos, nil
}

// listProject lists the sessions of dir and of its repository's worktrees.
func listProject(projects, dir string) []Info {
	wts := worktrees(dir)
	own, ok := findProjectDir(projects, dir)
	if len(wts) <= 1 {
		if !ok {
			return nil
		}
		return readProject(own, dir)
	}
	// dir itself first: a folder inside a worktree isn't one of the
	// worktrees' names.
	var infos []Info
	seen := map[string]bool{}
	if ok {
		seen[filepath.Base(own)] = true
		infos = readProject(own, dir)
	}
	// The longest names first, so a worktree inside another gets its own.
	type tree struct{ path, name string }
	trees := make([]tree, len(wts))
	for i, wt := range wts {
		trees[i] = tree{wt, folderName(wt)}
	}
	slices.SortStableFunc(trees, func(a, b tree) int { return len(b.name) - len(a.name) })
	for _, folder := range subdirs(projects) {
		if seen[folder] {
			continue
		}
		for _, wt := range trees {
			if folder == wt.name || len(wt.name) > maxName && strings.HasPrefix(folder, wt.name[:maxName]+"-") {
				seen[folder] = true
				infos = append(infos, readProject(filepath.Join(projects, folder), wt.path)...)
				break
			}
		}
	}
	return newestByID(infos)
}

// newestByID keeps the newest of each session listed in more than one
// folder.
func newestByID(infos []Info) []Info {
	at := map[string]int{}
	var out []Info
	for _, info := range infos {
		i, ok := at[info.ID]
		switch {
		case !ok:
			at[info.ID] = len(out)
			out = append(out, info)
		case info.LastModified.After(out[i].LastModified):
			out[i] = info
		}
	}
	return out
}

// readProject reads the details of each session in a project folder; cwd
// is the folder's working directory, when known.
func readProject(dir, cwd string) []Info {
	entries, _ := os.ReadDir(dir)
	var infos []Info
	for _, e := range entries {
		id, ok := strings.CutSuffix(e.Name(), ".jsonl")
		if !ok || checkID(id) != nil {
			continue
		}
		l, ok := readLite(filepath.Join(dir, e.Name()))
		if !ok {
			continue
		}
		if info, ok := l.info(id, cwd); ok {
			infos = append(infos, info)
		}
	}
	return infos
}

// Get returns the details of session id; an error matching fs.ErrNotExist
// when it isn't there, is a subagent's, or has nothing to name it by.
func (s Store) Get(id, cwd string) (*Info, error) {
	path, err := s.find(id, cwd)
	if err != nil {
		return nil, err
	}
	l, ok := readLite(path)
	if !ok {
		return nil, notFound("session " + id)
	}
	if cwd != "" {
		cwd = canonical(cwd)
	}
	info, ok := l.info(id, cwd)
	if !ok {
		return nil, notFound("session " + id + "'s details")
	}
	return &info, nil
}

// lite is a transcript's start and end, its size and when it was written.
type lite struct {
	head, tail string
	size       int64
	modified   time.Time
}

// readLite reads path's first and last 64 KiB; false for an empty file or
// one that can't be read.
func readLite(path string) (lite, bool) {
	f, err := os.Open(path)
	if err != nil {
		return lite{}, false
	}
	defer f.Close() //nolint:errcheck // read-only
	fi, err := f.Stat()
	if err != nil || !fi.Mode().IsRegular() {
		return lite{}, false
	}
	buf := make([]byte, liteRead)
	n, _ := io.ReadFull(f, buf)
	if n == 0 {
		return lite{}, false
	}
	l := lite{head: strings.ToValidUTF8(string(buf[:n]), "�"), size: fi.Size(), modified: fi.ModTime()}
	l.tail = l.head
	if fi.Size() > liteRead {
		n, _ = f.ReadAt(buf, fi.Size()-liteRead)
		l.tail = strings.ToValidUTF8(string(buf[:n]), "�")
	}
	return l, true
}

// info reads a session's details from its transcript's start and end;
// false for a subagent's transcript or one with nothing to name it by.
func (l lite) info(id, cwd string) (Info, bool) {
	first, _, _ := strings.Cut(l.head, "\n")
	if strings.Contains(first, `"isSidechain":true`) || strings.Contains(first, `"isSidechain": true`) {
		return Info{}, false
	}
	info := Info{ID: id, Size: l.size, LastModified: l.modified}
	info.CustomTitle = firstOf(
		lastString(l.tail, "customTitle"), lastString(l.head, "customTitle"),
		lastString(l.tail, "aiTitle"), lastString(l.head, "aiTitle"))
	info.FirstPrompt = firstPrompt(l.head)
	info.Summary = firstOf(info.CustomTitle, lastString(l.tail, "lastPrompt"), lastString(l.tail, "summary"), info.FirstPrompt)
	if info.Summary == "" {
		return Info{}, false
	}
	info.GitBranch = firstOf(lastString(l.tail, "gitBranch"), firstString(l.head, "gitBranch"))
	info.Cwd = firstOf(firstString(l.head, "cwd"), cwd)
	// Only a tag record's tag: a tool call's input may say "tag" too.
	for _, line := range slices.Backward(strings.Split(l.tail, "\n")) {
		if strings.HasPrefix(line, `{"type":"tag"`) {
			info.Tag = lastString(line, "tag")
			break
		}
	}
	if ts := firstString(l.head, "timestamp"); ts != "" {
		info.Created = parseTime(ts)
	}
	return info, true
}

// parseTime reads a time as the CLI writes them (JavaScript's
// toISOString); zero when it can't.
func parseTime(s string) time.Time {
	t, _ := time.Parse(time.RFC3339Nano, s)
	return t
}

// firstOf returns the first of values that isn't "".
func firstOf(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}
