package claudemcp

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/git"
)

// A .mcp.json server is approved or rejected per project through two
// lists in Claude's settings files, enabledMcpjsonServers and
// disabledMcpjsonServers. A rejection in any settings file (or in the
// project's entry in ~/.claude.json, where the terminal records its
// choices) keeps the server out; an approval in the project's
// .claude/settings.local.json counts once the folder is trusted. Nushi
// changes only those two lists, and only in that file (ADR 0021): unlike
// ~/.claude.json, Claude writes it only when you pick "don't ask again".

// LocalSettings is localSettings, for other packages.
func LocalSettings(folder string) string { return localSettings(folder) }

// localSettings is the settings file Claude keeps per project for you:
// .claude/settings.local.json at the repository's root (its main
// checkout), or in the folder outside git.
func localSettings(folder string) string {
	return filepath.Join(project(folder), ".claude", "settings.local.json")
}

// UserSettings is Claude's user settings file.
func UserSettings() string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return filepath.Join(dir, "settings.json")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude", "settings.json")
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
// folder (the settings files, and ~/.claude.json's entry for the project),
// and the servers the project's local settings approve.
func rejected(folder string, terminal []string) (out map[string][]string, approved []string) {
	out = map[string][]string{}
	for i, path := range []string{localSettings(folder), filepath.Join(folder, ".claude", "settings.json"), UserSettings()} {
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
		out[name] = append(out[name], ConfigFile())
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
	return EditLocal(ctx, folder, func(settings map[string]json.RawMessage) error {
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

// EditLocal changes folder's project's .claude/settings.local.json, the
// settings Claude keeps per project for you, through change, which gets
// the file's settings by key (none for a new file). Other settings stay;
// the file is replaced at once, keeping its mode; a new one is kept out of
// git through the repository's info/exclude, as Claude keeps it out
// through your global excludes.
func EditLocal(ctx context.Context, folder string, change func(settings map[string]json.RawMessage) error) error {
	path := localSettings(folder)
	// The repository decides what's in .claude/: refuse symlinks there, so
	// a cloned repo can't point the write at a file elsewhere.
	for _, p := range []string{filepath.Dir(path), path} {
		if fi, err := os.Lstat(p); err == nil && fi.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("%s is a symlink; not changing it", p)
		}
	}
	created, err := edit(path, change)
	if err != nil {
		return err
	}
	root := project(folder)
	if created && !git.Ignored(ctx, root, ".claude/settings.local.json") {
		_ = git.Exclude(ctx, root, "/.claude/settings.local.json") // outside git there is nothing to keep it out of
	}
	return nil
}

// EditUser changes Claude's user settings file (~/.claude/settings.json)
// as EditLocal does; a link there (your dotfiles') is followed, to change
// the file it points at.
func EditUser(change func(settings map[string]json.RawMessage) error) error {
	path := UserSettings()
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		path = resolved
	}
	_, err := edit(path, change)
	return err
}

// edit reads the settings file at path, changes it and writes it back.
func edit(path string, change func(map[string]json.RawMessage) error) (created bool, err error) {
	settings := map[string]json.RawMessage{}
	b, err := ReadFile(path)
	created = os.IsNotExist(err)
	if err == nil {
		err = json.Unmarshal(b, &settings)
	}
	if err != nil && !created {
		return false, fmt.Errorf("reading %s: %w", path, err)
	}
	if settings == nil { // the file holds null
		settings = map[string]json.RawMessage{}
	}
	if err := change(settings); err != nil {
		return false, fmt.Errorf("%s: %w", path, err)
	}
	out, err := json.MarshalIndent(settings, "", "  ")
	if err != nil {
		return false, err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil { //nolint:gosec // a .claude folder, as Claude makes it
		return false, err
	}
	mode := os.FileMode(0o644)
	if fi, err := os.Lstat(path); err == nil {
		mode = fi.Mode().Perm()
	}
	return created, atomicfile.Replace(path, append(out, '\n'), mode)
}
