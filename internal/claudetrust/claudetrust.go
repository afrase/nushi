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

// Key is the folder Claude keys a folder's trust on: its repository's main
// checkout, or the folder itself outside git (real paths).
func (Trust) Key(folder string) string { return claudemcp.Claude{}.Project(folder) }

// Trusted says whether folder is trusted: by Claude (its trust dialog was
// accepted there), or by one of also, keys Nushi was told to trust.
func (t Trust) Trusted(folder string, also []string) (bool, error) {
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
	if real, err := filepath.EvalSymlinks(folder); err == nil {
		folder = real
	}
	if ok(t.Key(folder)) {
		return true, nil
	}
	if toplevel(folder) != "" { // in a repository only its key counts
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

// toplevel is the root of folder's work tree, or "" outside git.
func toplevel(folder string) string {
	out, err := exec.Command("git", "-C", folder, "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
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
	if top := toplevel(folder); top != "" && top != folder {
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
