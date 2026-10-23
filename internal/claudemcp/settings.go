package claudemcp

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"

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

// localSettings is the settings file Claude keeps per project for you:
// .claude/settings.local.json at the repository's root (its main
// checkout), or in the folder outside git.
func localSettings(folder string) string {
	return filepath.Join(project(folder), ".claude", "settings.local.json")
}

// userSettings is Claude's user settings file.
func userSettings() string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return filepath.Join(dir, "settings.json")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude", "settings.json")
}

type lists struct {
	Enabled  []string `json:"enabledMcpjsonServers"`
	Disabled []string `json:"disabledMcpjsonServers"`
}

// rejected returns, by name, the files that reject a .mcp.json server in
// folder (the settings files, and ~/.claude.json's entry for the project),
// and the servers the project's local settings approve.
func rejected(folder string, terminal []string) (out map[string][]string, approved []string) {
	out = map[string][]string{}
	for i, path := range []string{localSettings(folder), filepath.Join(folder, ".claude", "settings.json"), userSettings()} {
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
		out[name] = append(out[name], configFile())
	}
	return out, approved
}

// SetOn approves (on) or rejects a .mcp.json server for folder's project,
// in its .claude/settings.local.json. Other settings in the file stay; a
// new file is kept out of git through the repository's info/exclude, as
// Claude keeps it out through your global excludes.
func (Claude) SetOn(ctx context.Context, folder, name string, on bool) error {
	path := localSettings(folder)
	settings := map[string]json.RawMessage{}
	b, err := os.ReadFile(path)
	created := os.IsNotExist(err)
	if err == nil {
		err = json.Unmarshal(b, &settings)
	}
	if err != nil && !created {
		return fmt.Errorf("reading %s: %w", path, err)
	}
	add, drop := "enabledMcpjsonServers", "disabledMcpjsonServers"
	if !on {
		add, drop = drop, add
	}
	for key, keep := range map[string]bool{add: true, drop: false} {
		names := []string{}
		raw, had := settings[key]
		if had && json.Unmarshal(raw, &names) != nil {
			return fmt.Errorf("%s in %s isn't a list of names", key, path)
		}
		names = slices.DeleteFunc(names, func(n string) bool { return n == name })
		if keep {
			names = append(names, name)
		}
		if len(names) > 0 || had {
			settings[key], _ = json.Marshal(names)
		}
	}
	out, _ := json.MarshalIndent(settings, "", "  ")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	mode := os.FileMode(0o644)
	if fi, err := os.Stat(path); err == nil {
		mode = fi.Mode().Perm()
	}
	tmp := path + ".nushi-tmp"
	if err := os.WriteFile(tmp, append(out, '\n'), mode); err != nil {
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		return err
	}
	root := project(folder)
	if created && !git.Ignored(ctx, root, ".claude/settings.local.json") {
		_ = git.Exclude(ctx, root, "/.claude/settings.local.json") // outside git there is nothing to keep it out of
	}
	return nil
}
