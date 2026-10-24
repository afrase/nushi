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
	"bytes"
	"cmp"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"maps"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/git"
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
	_, key := git.TrustRoot(git.RealPath(folder))
	return key
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
	folder = git.RealPath(folder)
	top, key := git.TrustRoot(folder)
	if ok(key) {
		return true, nil
	}
	if top != "" { // in a repository only its key counts
		return false, nil
	}
	// Outside git, a folder above counts too, but never the home folder or
	// /: trusting your home would trust every download under it (Claude
	// keeps home trust for one session only).
	home := git.RealPath(homeDir())
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
		what, text := "MCP servers Nushi couldn't read", u.Err.Error()
		if b, err := claudemcp.ReadFile(u.Path); err == nil {
			text = whole(u.Path, b)
		}
		out = append(out, model.FolderRun{File: u.Path, What: what, Command: text})
	}
	for _, s := range servers {
		if s.Scope == "project" && !s.Off {
			out = append(out, model.FolderRun{File: s.Source, What: "MCP server " + s.Name, Command: serverCommand(s.Config)})
		}
	}
	dirs := []string{folder}
	if top, _ := git.TrustRoot(git.RealPath(folder)); top != "" && top != git.RealPath(folder) {
		dirs = append(dirs, top)
	}
	home := git.RealPath(homeDir())
	for _, dir := range dirs {
		if git.RealPath(dir) == home {
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
			if front, ok := skillHooks(path); ok {
				out = append(out, model.FolderRun{File: path, What: "Hooks in skill " + filepath.Base(filepath.Dir(path)), Command: whole(path, front)})
			}
		}
	}
	return out, nil
}

// shown is the most of a file the trust card shows: all of it, or nothing
// but where it is, never a part that would look like all of it.
const shown = 256 << 10

func whole(path string, b []byte) string {
	if len(b) > shown {
		return fmt.Sprintf("too large to show (%d KB): read %s", (len(b)+1023)>>10, path)
	}
	return string(b)
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

// skillHooks returns a skill's front matter, raw, when it has hooks: the
// word anywhere in it, or a key that YAML reads as hooks (any case, any
// depth, in any of its documents, aliases and merges resolved), or YAML
// that doesn't decode. Nushi doesn't guess which commands Claude would read
// out of it. Without a closing "---" line, the whole file counts.
func skillHooks(path string) ([]byte, bool) {
	b, err := claudemcp.ReadFile(path)
	if err != nil || !bytes.HasPrefix(b, []byte("---")) {
		return nil, false
	}
	front := b
	if loc := closing.FindIndex(b[3:]); loc != nil {
		front = bytes.TrimRight(b[:3+loc[1]], "\n")
	}
	if bytes.Contains(bytes.ToLower(front), []byte("hooks")) {
		return front, true
	}
	yamlText := bytes.TrimPrefix(front, []byte("---"))
	if loc := closing.FindIndex(yamlText); loc != nil {
		yamlText = yamlText[:loc[0]]
	}
	dec := yaml.NewDecoder(bytes.NewReader(yamlText))
	for {
		var doc any
		err := dec.Decode(&doc)
		if errors.Is(err, io.EOF) {
			return nil, false
		}
		if err != nil || hasHooksKey(doc) {
			return front, true
		}
	}
}

// closing is the line that ends front matter: "---" alone.
var closing = regexp.MustCompile(`\n---[ \t\r]*(\n|\z)`)

// hasHooksKey says a decoded YAML value has a key reading hooks, in any
// case, at any depth.
func hasHooksKey(v any) bool {
	switch v := v.(type) {
	case map[string]any:
		for k, x := range v {
			if strings.EqualFold(k, "hooks") || hasHooksKey(x) {
				return true
			}
		}
	case map[any]any:
		for k, x := range v {
			if strings.EqualFold(fmt.Sprint(k), "hooks") || hasHooksKey(k) || hasHooksKey(x) {
				return true
			}
		}
	case []any:
		for _, x := range v {
			if hasHooksKey(x) {
				return true
			}
		}
	}
	return false
}
