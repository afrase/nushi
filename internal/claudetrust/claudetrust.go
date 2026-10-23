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
	b, err := os.ReadFile(claudemcp.ConfigFile())
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
	for dir := folder; ; dir = filepath.Dir(dir) { // outside git, a folder above counts too
		if ok(dir) {
			return true, nil
		}
		if dir == filepath.Dir(dir) {
			return false, nil
		}
	}
}

// Runs lists what folder brings for Claude to run: its .mcp.json servers
// (in it or a folder above, and not turned off), and the hooks, env block
// and helper commands in its .claude/settings.json and settings.local.json
// and its skills' hooks, in the folder and at its repository's root.
func (Trust) Runs(folder string) ([]model.FolderRun, error) {
	servers, err := claudemcp.Claude{}.Servers(folder)
	if err != nil {
		return nil, err
	}
	var out []model.FolderRun
	for _, s := range servers {
		if s.Scope == "project" && !s.Off {
			out = append(out, model.FolderRun{File: s.Source, What: "MCP server " + s.Name, Command: serverCommand(s.Config)})
		}
	}
	dirs := []string{folder}
	if top, _ := repoOf(real(folder)); top != "" && top != real(folder) {
		dirs = append(dirs, top)
	}
	for _, dir := range dirs {
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

// helpers are the settings that name a command Claude runs on its own.
var helpers = []string{"apiKeyHelper", "awsAuthRefresh", "awsCredentialExport", "otelHeadersHelper"}

// settingsRuns lists what a settings file has Claude run: its hooks, its
// env block (the names only) and its helper commands.
func settingsRuns(path string) ([]model.FolderRun, error) {
	var s map[string]json.RawMessage
	b, err := os.ReadFile(path)
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
	for _, h := range helpers {
		var cmd string
		if json.Unmarshal(s[h], &cmd) == nil && cmd != "" {
			out = append(out, model.FolderRun{File: path, What: h, Command: cmd})
		}
	}
	return out, nil
}

// skillHooks returns the commands of the hooks in a skill's front matter,
// read line by line rather than as YAML: each `command:` value under it.
func skillHooks(path string) []string {
	b, err := os.ReadFile(path)
	if err != nil || !bytes.HasPrefix(b, []byte("---")) {
		return nil
	}
	var cmds []string
	sc := bufio.NewScanner(bytes.NewReader(b[3:]))
	inHooks := false
	for sc.Scan() {
		line := sc.Text()
		if strings.TrimSpace(line) == "---" {
			break
		}
		if line != "" && line[0] != ' ' && line[0] != '\t' && line[0] != '-' {
			inHooks = strings.HasPrefix(line, "hooks:")
		}
		if v, ok := strings.CutPrefix(strings.TrimLeft(strings.TrimSpace(line), "- "), "command:"); ok && inHooks {
			cmds = append(cmds, strings.Trim(strings.TrimSpace(v), `"'`))
		}
	}
	return cmds
}
