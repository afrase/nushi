package claudemcp

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/jsonsettings"
)

// A .mcp.json server is approved or rejected per project through two
// lists in Claude's settings files, enabledMcpjsonServers and
// disabledMcpjsonServers. A rejection in any settings file (or in the
// project's entry in ~/.claude.json, where the terminal records its
// choices) keeps the server out; an approval in the project's
// .claude/settings.local.json counts once the folder is trusted. Nushi
// changes only those two lists, and only in that file (ADR 0021): unlike
// ~/.claude.json, Claude writes it only when you pick "don't ask again".

// localSettings is the settings file Claude keeps per project for you,
// the one Nushi changes: .claude/settings.local.json in the project (key,
// Project), its repository's main checkout or the folder outside git.
func localSettings(key string) string {
	return filepath.Join(key, ".claude", "settings.local.json")
}

// SettingsFiles are the settings files Claude reads in folder, whose
// project is key (Project), the one that wins first (docs/facts/claude.md,
// seen with Claude Code 2.1.312): the project's local settings, the
// folder's own local settings (another file in a worktree or a subfolder),
// the folder's .claude/settings.json (not the repository root's or the
// main checkout's), yours.
func SettingsFiles(folder, key string) []string {
	files := []string{localSettings(key)}
	if git.RealPath(folder) != key {
		files = append(files, filepath.Join(folder, ".claude", "settings.local.json"))
	}
	return append(files, filepath.Join(folder, ".claude", "settings.json"), claude.UserSettings())
}

type lists struct {
	Enabled  names `json:"enabledMcpjsonServers"`
	Disabled names `json:"disabledMcpjsonServers"`
}

// names is a list of server names, which Claude also takes as one name
// alone, a string.
type names []string

func (n *names) UnmarshalJSON(b []byte) error {
	var one string
	if json.Unmarshal(b, &one) == nil {
		*n = names{one}
		return nil
	}
	return json.Unmarshal(b, (*[]string)(n))
}

// rejected returns, by name, the files that reject a .mcp.json server in
// folder, whose project is key (the settings files, and ~/.claude.json's
// entry for the project), and the servers the project's local settings
// approve.
func rejected(folder, key string, terminal []string) (out map[string][]string, approved []string) {
	out = map[string][]string{}
	for i, path := range SettingsFiles(folder, key) {
		var l lists
		_ = readJSON(path, &l) // an unreadable settings file rejects nothing here
		for _, name := range l.Disabled {
			out[name] = append(out[name], path)
		}
		if i == 0 {
			approved = l.Enabled
		}
	}
	for _, name := range terminal {
		out[name] = append(out[name], claude.ConfigFile())
	}
	return out, approved
}

// SetOn turns a server on or off for folder's project: a project server
// (.mcp.json) through the approval lists below, a user or local one
// through Claude's own toggle (Toggle).
func (c Claude) SetOn(ctx context.Context, folder, scope, name string, on bool) error {
	if scope == "project" {
		return approve(ctx, folder, name, on)
	}
	return c.Toggle(ctx, folder, name, on)
}

// approve approves (on) or rejects a .mcp.json server for folder's
// project, in its .claude/settings.local.json.
func approve(ctx context.Context, folder, name string, on bool) error {
	return EditLocal(ctx, Project(folder), func(settings map[string]json.RawMessage) error {
		add, drop := "enabledMcpjsonServers", "disabledMcpjsonServers"
		if !on {
			add, drop = drop, add
		}
		for key, keep := range map[string]bool{add: true, drop: false} {
			list := names{}
			raw, had := settings[key]
			if had && string(raw) != "null" && json.Unmarshal(raw, &list) != nil {
				return fmt.Errorf("%s isn't a list of names", key)
			}
			list = slices.DeleteFunc(list, func(n string) bool { return n == name })
			if keep {
				list = append(list, name)
			}
			if len(list) > 0 || had {
				settings[key], _ = json.Marshal(list)
			}
		}
		return nil
	})
}

// EditLocal changes a project's .claude/settings.local.json (key, a
// folder's Project), the settings Claude keeps per project for you,
// through change, which gets the file's settings by key (none for a new
// file). Other settings stay; the file is replaced at once, keeping its
// mode; a new one is kept out of git through the repository's
// info/exclude, as Claude keeps it out through your global excludes.
func EditLocal(ctx context.Context, key string, change func(settings map[string]json.RawMessage) error) error {
	path := localSettings(key)
	// The repository decides what's in .claude/: refuse symlinks there, so
	// a cloned repo can't point the write at a file elsewhere.
	for _, p := range []string{filepath.Dir(path), path} {
		if fi, err := os.Lstat(p); err == nil && fi.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("%s is a symlink; not changing it", p)
		}
	}
	created, err := jsonsettings.EditIn(key, filepath.Join(".claude", "settings.local.json"), change) // a link swapped in meanwhile can't lead out
	if err != nil {
		return err
	}
	if created && !git.Ignored(ctx, key, ".claude/settings.local.json") {
		_ = git.Exclude(ctx, key, "/.claude/settings.local.json") // outside git there is nothing to keep it out of
	}
	return nil
}

// EditUser changes Claude's user settings file (~/.claude/settings.json)
// as EditLocal does; a link there (your dotfiles') is followed, to change
// the file it points at.
func EditUser(change func(settings map[string]json.RawMessage) error) error {
	_, err := jsonsettings.Edit(claude.UserSettings(), change)
	return err
}
