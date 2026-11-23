package claude

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/jsonsettings"
	"github.com/afrase/nushi/internal/realpath"
)

// Claude's settings files, as its MCP servers, skills and trust card read
// and change them (claudemcp, claudeskills, claudetrust).

// Project is the folder Claude files folder's local servers and settings
// under, and keys its trust on: its repository's main checkout, or the
// folder itself outside git (a real path; git.TrustRoot, as the trust
// card has it). Work it out once a call: it reads the repository's files.
//
//nolint:contextcheck // TrustRoot's one quick git config, bounded by its own 5 s; also for callers with no request (the MCP list's scopes)
func Project(folder string) string {
	_, key := git.TrustRoot(realpath.Of(folder))
	return key
}

// LocalSettings is the settings file Claude keeps per project for you,
// the one Nushi changes: .claude/settings.local.json in the project (key,
// Project), its repository's main checkout or the folder outside git.
func LocalSettings(key string) string {
	return filepath.Join(key, ".claude", "settings.local.json")
}

// SettingsFiles are the settings files Claude reads in folder, whose
// project is key (Project), the one that wins first (docs/facts/claude.md,
// seen with Claude Code 2.1.312): the project's local settings, the
// folder's own local settings (another file in a worktree or a subfolder),
// the folder's .claude/settings.json (not the repository root's or the
// main checkout's), yours.
func SettingsFiles(folder, key string) []string {
	files := []string{LocalSettings(key)}
	if realpath.Of(folder) != key {
		files = append(files, filepath.Join(folder, ".claude", "settings.local.json"))
	}
	return append(files, filepath.Join(folder, ".claude", "settings.json"), UserSettings())
}

// EditLocal changes a project's .claude/settings.local.json (key, a
// folder's Project), the settings Claude keeps per project for you,
// through change, which gets the file's settings by key (none for a new
// file). Other settings stay; the file is replaced at once, keeping its
// mode; a new one is kept out of git through the repository's
// info/exclude, as Claude keeps it out through your global excludes.
func EditLocal(ctx context.Context, key string, change func(settings map[string]json.RawMessage) error) error {
	path := LocalSettings(key)
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
	_, err := jsonsettings.Edit(UserSettings(), change)
	return err
}
