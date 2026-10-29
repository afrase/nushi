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
//     (local over project over user), else the skill's own
//     disable-model-invocation.
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
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/jsonsettings"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/procgroup"
	"github.com/afrase/nushi/internal/skillfile"
)

// Claude reads and changes Claude Code's skills and plugins.
type Claude struct{}

// configDir is Claude's config folder.
func configDir() string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return dir
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude")
}

// userRoot is the folder of your skills.
func userRoot() string { return filepath.Join(configDir(), "skills") }

// projectRoots are the .claude/skills folders Claude reads for folder,
// nearest first: the folder's and those above it up to its repository's
// top, or to / outside git. Your home folder's .claude is never the
// project's.
func projectRoots(ctx context.Context, folder string) []string {
	top := "/"
	cmd := exec.CommandContext(ctx, "git", "-C", folder, "rev-parse", "--show-toplevel") //nolint:gosec // git in the folder asked about
	procgroup.Bound(cmd)
	if out, err := cmd.Output(); err == nil {
		top = strings.TrimSpace(string(out))
	}
	if resolved, err := filepath.EvalSymlinks(folder); err == nil {
		folder = resolved
	}
	home, _ := os.UserHomeDir()
	var roots []string
	for dir := folder; ; dir = filepath.Dir(dir) {
		if dir != home && !linked(dir) {
			roots = append(roots, filepath.Join(dir, ".claude", "skills"))
		}
		if dir == top || dir == filepath.Dir(dir) {
			return roots
		}
	}
}

// linked says dir's .claude or .claude/skills is a symlink (or can't be
// looked at): a repository's link could point the listing, and Trash,
// anywhere, so Nushi leaves such a folder out.
func linked(dir string) bool {
	for _, p := range []string{filepath.Join(dir, ".claude"), filepath.Join(dir, ".claude", "skills")} {
		fi, err := os.Lstat(p)
		if err == nil && fi.Mode()&os.ModeSymlink != 0 || err != nil && !os.IsNotExist(err) {
			return true
		}
	}
	return false
}

// List returns folder's skills and plugins.
func (c Claude) List(ctx context.Context, folder string) (model.Skills, error) {
	return c.list(ctx, folder, true)
}

// list returns folder's skills, and with plugins its plugins (`claude
// plugin list`) and theirs.
func (Claude) list(ctx context.Context, folder string, plugins bool) (model.Skills, error) {
	var out model.Skills
	out.Skills = read(userRoot(), "user")
	seen := map[string]bool{}
	for _, root := range projectRoots(ctx, folder) {
		for _, s := range read(root, "project") {
			if !seen[s.Name] { // a nearer folder's has the name
				seen[s.Name] = true
				out.Skills = append(out.Skills, s)
			}
		}
	}
	files := settingsFiles(folder)
	for i, s := range out.Skills {
		out.Skills[i].State, out.Skills[i].SetIn = state(files, s)
	}
	if !plugins {
		return out, nil
	}
	installed, err := listPlugins(ctx, folder)
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

// settingsFiles are folder's settings files, the one that wins first:
// the project's local settings, its shared settings, yours. One that can't
// be read counts as empty.
func settingsFiles(folder string) []settings {
	var out []settings
	for _, path := range []string{
		claudemcp.LocalSettings(folder),
		filepath.Join(claudemcp.Claude{}.Project(folder), ".claude", "settings.json"),
		claudemcp.UserSettings(),
	} {
		s := settings{path: path}
		if b, err := jsonsettings.ReadFile(path); err == nil {
			_ = json.Unmarshal(b, &s) // a key of another shape counts as unset
		}
		out = append(out, s)
	}
	return out
}

// target is the settings file Nushi changes for a skill of source: the
// project's local settings for a project skill, yours for yours (as
// Claude's own advice has it).
func target(source string) int {
	if source == "project" {
		return 0
	}
	return 2
}

// state is a skill's state from the settings files, and the file that
// sets it when that file wins over the one Nushi would change.
func state(files []settings, s model.Skill) (state, setIn string) {
	for i, f := range files {
		if v, ok := f.SkillOverrides[s.Name]; ok {
			if i < target(s.Source) {
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
			if i < target("user") {
				setIn = f.path
			}
			return *f.NoBuiltIn, setIn
		}
	}
	return false, ""
}
