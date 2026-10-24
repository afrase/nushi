// Package claudetrust tells whether Claude Code trusts a folder, and what a
// folder brings along for Claude to run there. It only reads Claude's files
// (Claude Code 2.1.309; see ADR 0023 and Claude's permissions docs, "What
// runs before you trust a folder"):
//   - trust is projects[<key>].hasTrustDialogAccepted in ~/.claude.json,
//     where the key is the repository's root (its main checkout, for a
//     worktree), or the folder outside git, which then covers the folders
//     under it;
//   - an SDK session (Nushi's) never asks, and runs a repository's hooks,
//     env block and helper commands, its skills' hooks, and its .mcp.json
//     servers whether the folder is trusted or not.
package claudetrust

import (
	"bufio"
	"bytes"
	"cmp"
	"encoding/json"
	"fmt"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/model"
)

// Trust reads Claude Code's trust and settings files.
type Trust struct{}

// Key is the folder Claude keys a folder's trust on (real paths): its
// repository's main checkout, or the folder itself outside git. It is read
// from the files rather than asked of git, which a repository's own config
// (core.worktree) can steer: the nearest folder up with a .git folder is a
// main checkout; one with a .git file is a worktree of the repository it
// names only when that repository names it back. Anything else, or a
// repository that sets core.worktree, keys on the folder itself.
func (Trust) Key(folder string) string {
	_, key := repoOf(real(folder))
	return key
}

func real(path string) string {
	if r, err := filepath.EvalSymlinks(path); err == nil {
		return r
	}
	return path
}

// repoOf returns the root of folder's work tree ("" outside git) and the
// folder its trust is keyed on (see Key).
func repoOf(folder string) (top, key string) {
	for top = folder; ; top = filepath.Dir(top) {
		if _, err := os.Lstat(filepath.Join(top, ".git")); err == nil {
			break
		}
		if top == filepath.Dir(top) {
			return "", folder
		}
	}
	dotgit := filepath.Join(top, ".git")
	if fi, err := os.Lstat(dotgit); err == nil && fi.IsDir() {
		if worktreeSet(filepath.Join(dotgit, "config")) {
			return top, folder
		}
		return top, top
	}
	b, _ := os.ReadFile(dotgit)
	gitdir, ok := strings.CutPrefix(strings.TrimSpace(string(b)), "gitdir: ")
	if !ok {
		return top, folder
	}
	if !filepath.IsAbs(gitdir) {
		gitdir = filepath.Join(top, gitdir)
	}
	gitdir = real(gitdir)
	back, _ := os.ReadFile(filepath.Join(gitdir, "gitdir"))
	common := filepath.Dir(filepath.Dir(gitdir)) // <common>/worktrees/<name>
	if real(strings.TrimSpace(string(back))) != real(dotgit) || filepath.Base(filepath.Dir(gitdir)) != "worktrees" ||
		filepath.Base(common) != ".git" || worktreeSet(filepath.Join(common, "config")) {
		return top, folder
	}
	return top, filepath.Dir(common)
}

// worktreeSet says whether a repository's config file sets core.worktree
// (includes followed); git's own environment is left out.
func worktreeSet(config string) bool {
	cmd := exec.Command("git", "config", "--file", config, "--includes", "--get", "core.worktree")
	cmd.Env = slices.DeleteFunc(os.Environ(), func(e string) bool { return strings.HasPrefix(e, "GIT_") })
	return cmd.Run() == nil
}

// Trusted says whether folder is trusted: by Claude (its trust dialog was
// accepted there), or by one of also, keys Nushi was told to trust.
func (Trust) Trusted(folder string, also []string) (bool, error) {
	var cfg struct {
		Projects map[string]struct {
			Accepted bool `json:"hasTrustDialogAccepted"`
		} `json:"projects"`
	}
	b, err := claudemcp.ReadFile(claudemcp.ConfigFile())
	if err == nil {
		err = json.Unmarshal(b, &cfg)
	}
	if err != nil && !os.IsNotExist(err) {
		return false, fmt.Errorf("reading Claude's config: %w", err)
	}
	ok := func(dir string) bool { return cfg.Projects[dir].Accepted || slices.Contains(also, dir) }
	folder = real(folder)
	top, key := repoOf(folder)
	if ok(key) {
		return true, nil
	}
	if top != "" { // in a repository only its key counts
		return false, nil
	}
	// Outside git, a folder above counts too, but never the home folder or
	// /: trusting your home would trust every download under it (Claude
	// keeps home trust for one session only).
	home := real(homeDir())
	for dir := filepath.Dir(folder); dir != home && dir != filepath.Dir(dir); dir = filepath.Dir(dir) {
		if ok(dir) {
			return true, nil
		}
	}
	return false, nil
}

func homeDir() string {
	home, _ := os.UserHomeDir()
	return home
}

// Runs lists what folder brings for Claude to run: its .mcp.json servers
// (in it or a folder above, and not turned off), and the hooks, env block
// and helper commands in its .claude/settings.json and settings.local.json
// and its skills' hooks, in the folder and at its repository's root.
func (Trust) Runs(folder string) ([]model.FolderRun, error) {
	servers, unread, err := claudemcp.Claude{}.Read(folder)
	if err != nil {
		return nil, err
	}
	var out []model.FolderRun
	// Nushi can't tell what one it can't read runs, but Claude might read
	// it (or read it later): it shows, and the card still asks.
	for _, u := range unread {
		what := u.Err.Error()
		if b, err := claudemcp.ReadFile(u.Path); err == nil {
			what = string(b[:min(len(b), 4<<10)])
		}
		out = append(out, model.FolderRun{File: u.Path, What: "MCP servers Nushi couldn't read", Command: what})
	}
	for _, s := range servers {
		if s.Scope == "project" && !s.Off {
			out = append(out, model.FolderRun{File: s.Source, What: "MCP server " + s.Name, Command: serverCommand(s.Config)})
		}
	}
	dirs := []string{folder}
	if top, _ := repoOf(real(folder)); top != "" && top != real(folder) {
		dirs = append(dirs, top)
	}
	home := real(homeDir())
	for _, dir := range dirs {
		if real(dir) == home {
			continue // ~/.claude is the user's own config, not the folder's
		}
		for _, name := range []string{"settings.json", "settings.local.json"} {
			runs, err := settingsRuns(filepath.Join(dir, ".claude", name))
			if err != nil {
				return nil, err
			}
			out = append(out, runs...)
		}
		skills, _ := filepath.Glob(filepath.Join(dir, ".claude", "skills", "*", "SKILL.md"))
		for _, path := range skills {
			for _, cmd := range skillHooks(path) {
				out = append(out, model.FolderRun{File: path, What: "Hook in skill " + filepath.Base(filepath.Dir(path)), Command: cmd})
			}
		}
	}
	return out, nil
}

// serverCommand is the command line a server runs, or the URL it connects to.
func serverCommand(config string) string {
	var c struct {
		Command string   `json:"command"`
		Args    []string `json:"args"`
		URL     string   `json:"url"`
	}
	json.Unmarshal([]byte(config), &c)
	return cmp.Or(strings.Join(append([]string{c.Command}, c.Args...), " "), c.URL)
}

// helper says a setting names a command Claude runs on its own (Claude Code
// 2.1.309's credential helpers apiKeyHelper, awsAuthRefresh,
// awsCredentialExport, gcpAuthRefresh, otelHeadersHelper and
// proxyAuthHelper, and any it adds named the same way).
func helper(setting string) bool {
	return strings.HasSuffix(setting, "Helper") || strings.HasSuffix(setting, "AuthRefresh") || strings.HasSuffix(setting, "CredentialExport")
}

// settingsRuns lists what a settings file has Claude run: its hooks, its
// env block (the names only) and its helper commands.
func settingsRuns(path string) ([]model.FolderRun, error) {
	var s map[string]json.RawMessage
	b, err := claudemcp.ReadFile(path)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err == nil {
		err = json.Unmarshal(b, &s)
	}
	if err != nil {
		return nil, fmt.Errorf("reading %s: %w", path, err)
	}
	var out []model.FolderRun
	var hooks map[string][]struct {
		Matcher string `json:"matcher"`
		Hooks   []struct {
			Command string `json:"command"`
			Prompt  string `json:"prompt"`
		} `json:"hooks"`
	}
	json.Unmarshal(s["hooks"], &hooks)
	for _, event := range slices.Sorted(maps.Keys(hooks)) {
		for _, m := range hooks[event] {
			for _, h := range m.Hooks {
				out = append(out, model.FolderRun{File: path, What: "Hook on " + event, Command: cmp.Or(h.Command, h.Prompt)})
			}
		}
	}
	var env map[string]any
	if json.Unmarshal(s["env"], &env) == nil && len(env) > 0 {
		out = append(out, model.FolderRun{File: path, What: "Environment variables", Command: strings.Join(slices.Sorted(maps.Keys(env)), " ")})
	}
	for _, h := range slices.Sorted(maps.Keys(s)) {
		var cmd string
		if helper(h) && json.Unmarshal(s[h], &cmd) == nil && cmd != "" {
			out = append(out, model.FolderRun{File: path, What: h, Command: cmd})
		}
	}
	return out, nil
}

// skillHooks returns the commands of the hooks in a skill's front matter,
// read line by line rather than as YAML: each `command:` value of a plain
// `hooks:` block. A block with anything else in it (flow style, block
// scalars, anchors, keys it doesn't know), or hooks anywhere else, comes
// back whole, as one "command": what the reader can't follow, the user
// reads.
func skillHooks(path string) []string {
	b, err := claudemcp.ReadFile(path)
	if err != nil || !bytes.HasPrefix(b, []byte("---")) {
		return nil
	}
	var front, block, rest []string
	sc := bufio.NewScanner(bytes.NewReader(b[3:]))
	inHooks := false
	for sc.Scan() {
		line := sc.Text()
		if strings.TrimSpace(line) == "---" {
			break
		}
		front = append(front, line)
		if line != "" && line[0] != ' ' && line[0] != '\t' && line[0] != '-' && line[0] != '#' {
			inHooks = strings.TrimRight(line, " ") == "hooks:"
			if inHooks {
				continue
			}
		}
		if inHooks {
			block = append(block, line)
		} else {
			rest = append(rest, line)
		}
	}
	whole := []string{strings.TrimSpace(strings.Join(front, "\n"))}
	if anyHooks.MatchString(strings.Join(rest, "\n")) {
		return whole
	}
	var cmds []string
	for _, line := range block {
		k, v, ok := plainPair(strings.TrimPrefix(strings.TrimSpace(line), "- "))
		switch {
		case !ok:
			return whole
		case k == "command":
			cmds = append(cmds, v)
		}
	}
	return cmds
}

// anyHooks finds a hooks key anywhere in YAML, quoted or not.
var anyHooks = regexp.MustCompile(`(?m)(^|[\s{,\[])["']?hooks["']?\s*:`)

// plainKey is a key the hooks block has: an event's name, or a hook's
// fields as Claude documents them.
var plainKey = regexp.MustCompile(`^(?:[A-Z][A-Za-z]*|hooks|matcher|type|command|prompt|timeout|async|statusMessage|once)$`)

// plainPair reads a line of a hooks block the reader follows: empty, a
// comment, or `key:` with a value on the line that YAML takes as it reads
// (plain, or quoted and closed); ok is false for anything else.
func plainPair(line string) (k, v string, ok bool) {
	if line == "" || strings.HasPrefix(line, "#") {
		return "", "", true
	}
	k, v, found := strings.Cut(line, ":")
	v = strings.TrimSpace(v)
	if !found || !plainKey.MatchString(k) || strings.Contains(v, " #") {
		return "", "", false
	}
	switch {
	case v == "":
		return k, v, true
	case strings.ContainsAny(v[:1], "|>[{&*!%@`"):
		return "", "", false
	case v[0] == '"' || v[0] == '\'':
		q := v[:1]
		inner, closed := strings.CutSuffix(v[1:], q)
		if !closed || strings.Contains(inner, q) || strings.Contains(inner, "\\") {
			return "", "", false
		}
		return k, inner, true
	}
	return k, v, !strings.Contains(v, ": ")
}
