// Package claudeskills reads the skills and plugins Claude Code uses in a
// folder, and turns them on and off the ways Claude documents (ADR 0051).
// Claude's own files are the source of truth (Claude Code 2.1.310):
//   - your skills: skills/<name>/SKILL.md in Claude's config folder
//     ($CLAUDE_CONFIG_DIR, else ~/.claude);
//   - the project's: .claude/skills/<name>/SKILL.md in the folder and each
//     folder above it, up to the repository's top (to / outside git), the
//     nearest winning a name;
//   - plugins': `claude plugin list --json` (run outside the folder) for
//     what is installed, enabledPlugins in the settings files for whether
//     each is on here, then each plugin's skills/, commands/ and agents/
//     folders;
//   - whether a skill is listed: "skillOverrides" in the settings files
//     (claudemcp.SettingsFiles: the project's local settings, the
//     folder's own local and project settings, yours, the first
//     winning), else the skill's own disable-model-invocation.
//
// A skill's name is its folder's name, as Claude lists it; its description
// is its front matter's, else its first line. Nothing here runs Claude in
// the folder: a run outside --bare would run the folder's apiKeyHelper. A
// project's .claude or .claude/skills that is a symlink is left out.
package claudeskills

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/jsonsettings"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/skillfile"
)

// Claude reads and changes Claude Code's skills and plugins.
type Claude struct{}

// userRoot is the folder of your skills.
func userRoot() string { return filepath.Join(claude.ConfigDir(), "skills") }

// projectRoots are the .claude/skills folders Claude reads for folder,
// nearest first: the folder's and those above it up to its repository's
// top (the nearest .git), or to / outside git. One whose .claude or
// .claude/skills is a symlink (or can't be looked at) is left out
// (skillfile.Roots): a repository's link could point the listing, and
// Trash, anywhere. Your home folder's .claude is never the project's.
func projectRoots(folder string) []string {
	folder = git.RealPath(folder)
	home, _ := os.UserHomeDir()
	return slices.DeleteFunc(skillfile.Roots(folder, skillfile.Top(folder), ".claude/skills"), func(root string) bool {
		return root == filepath.Join(home, ".claude", "skills")
	})
}

// List returns folder's skills and plugins.
func (c Claude) List(ctx context.Context, folder string) (model.Skills, error) {
	return c.list(ctx, folder, claudemcp.Project(folder), true)
}

// list returns folder's skills, whose project is key, and with plugins
// its plugins (`claude plugin list`) and theirs.
func (Claude) list(ctx context.Context, folder, key string, plugins bool) (model.Skills, error) {
	var out model.Skills
	out.Skills = read(userRoot(), "user")
	seen := map[string]bool{}
	for _, root := range projectRoots(folder) {
		for _, s := range read(root, "project") {
			if !seen[s.Name] { // a nearer folder's has the name
				seen[s.Name] = true
				out.Skills = append(out.Skills, s)
			}
		}
	}
	files := settingsFiles(folder, key)
	for i, s := range out.Skills {
		out.Skills[i].State, out.Skills[i].SetIn = state(files, s)
	}
	if !plugins {
		return out, nil
	}
	installed, err := listPlugins(ctx, folder, key)
	if err != nil {
		out.PluginsError = err.Error()
	}
	for _, p := range installed {
		out.Plugins = append(out.Plugins, p.Plugin)
		for _, s := range p.skills {
			s.Name, s.Source, s.Plugin = p.Name+":"+s.Name, "plugin", p.ID
			s.State = map[bool]string{true: "on", false: "off"}[p.Enabled]
			out.Skills = append(out.Skills, s)
		}
	}
	out.BuiltInOff, out.BuiltInSetIn = builtInOff(files)
	return out, nil
}

// read reads the skills in a skills folder (skillfile.List). A skill's
// name is its folder's, as Claude lists it; a linked folder is marked.
func read(root, source string) []model.Skill {
	var out []model.Skill
	for _, f := range skillfile.List(root) {
		s := model.Skill{Name: f.Entry, Description: f.Description, Source: source, Path: f.Dir, State: "on", Linked: f.Linked}
		if f.NoModel {
			s.State = "user-invocable-only"
		}
		s.Tokens = skillfile.Tokens(s.Name + f.Description + f.WhenToUse)
		out = append(out, s)
	}
	return out
}

// settings is one settings file's keys that this package reads.
type settings struct {
	path           string
	SkillOverrides map[string]string `json:"skillOverrides"`
	NoBuiltIn      *bool             `json:"disableBundledSkills"`
	EnabledPlugins map[string]any    `json:"enabledPlugins"`
}

// settingsFiles are the settings files Claude reads in folder, whose
// project is key, the one that wins first (claudemcp.SettingsFiles): the
// project's local settings first, yours last. One that can't be read
// counts as empty.
func settingsFiles(folder, key string) []settings {
	var out []settings
	for _, path := range claudemcp.SettingsFiles(folder, key) {
		s := settings{path: path}
		if b, err := jsonsettings.ReadFile(path); err == nil {
			_ = json.Unmarshal(b, &s) // a key of another shape counts as unset
		}
		out = append(out, s)
	}
	return out
}

// target is the settings file Nushi changes for a skill of source, of
// files: the project's local settings for a project skill, yours for
// yours (as Claude's own advice has it).
func target(files []settings, source string) int {
	if source == "project" {
		return 0
	}
	return len(files) - 1
}

// state is a skill's state from the settings files, and the file that
// sets it when that file wins over the one Nushi would change.
func state(files []settings, s model.Skill) (state, setIn string) {
	for i, f := range files {
		if v, ok := f.SkillOverrides[s.Name]; ok {
			if i < target(files, s.Source) {
				setIn = f.path
			}
			return v, setIn
		}
	}
	return s.State, ""
}

// builtInOff says whether disableBundledSkills turns the built-in skills
// off, and the file that does when it isn't yours.
func builtInOff(files []settings) (off bool, setIn string) {
	for i, f := range files {
		if f.NoBuiltIn != nil {
			if i < target(files, "user") {
				setIn = f.path
			}
			return *f.NoBuiltIn, setIn
		}
	}
	return false, ""
}
