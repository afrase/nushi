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
	"bytes"
	"context"
	"encoding/json"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"unicode"
	"unicode/utf8"

	"gopkg.in/yaml.v3"

	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/model"
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
	if out, err := exec.CommandContext(ctx, "git", "-C", folder, "rev-parse", "--show-toplevel").Output(); err == nil { //nolint:gosec // git in the folder asked about
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
	plugins, err := listPlugins(ctx, folder)
	if err != nil {
		out.PluginsError = err.Error()
	}
	for _, p := range plugins {
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

// read reads the skills in a skills folder: each folder in it with a
// SKILL.md that is a regular file (a link to one counts, as for Claude).
func read(root, source string) []model.Skill {
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil
	}
	var out []model.Skill
	for _, e := range entries {
		dir := filepath.Join(root, e.Name())
		b, err := claudemcp.ReadFile(filepath.Join(dir, "SKILL.md"))
		if err != nil || strings.HasPrefix(e.Name(), ".") {
			continue
		}
		desc, extra, author := frontMatter(b)
		s := model.Skill{Name: e.Name(), Description: desc, Source: source, Path: dir, State: "on"}
		if author {
			s.State = "user-invocable-only"
		}
		s.Tokens = tokens(s.Name + desc + extra)
		out = append(out, s)
	}
	return out
}

// maxDescription is the most of a description kept.
const maxDescription = 4000

// frontMatter reads a SKILL.md's description (else its first line), the
// rest Claude lists with it (when_to_use), and whether its author keeps
// Claude from using it on its own (disable-model-invocation).
func frontMatter(b []byte) (desc, extra string, author bool) {
	body := b
	if rest, ok := bytes.CutPrefix(b, []byte("---")); ok {
		if yamlText, after, ok := bytes.Cut(rest, []byte("\n---")); ok {
			var fm struct {
				Description string `yaml:"description"`
				WhenToUse   string `yaml:"when_to_use"`
				NoModel     bool   `yaml:"disable-model-invocation"`
			}
			_ = yaml.Unmarshal(yamlText, &fm) // what doesn't decode stays empty
			desc, extra, author, body = fm.Description, fm.WhenToUse, fm.NoModel, after
		}
	}
	if strings.TrimSpace(desc) == "" {
		for line := range strings.SplitSeq(string(body), "\n") {
			if line = strings.TrimSpace(strings.TrimLeft(line, "-# ")); line != "" {
				desc = line
				break
			}
		}
	}
	desc = strings.TrimSpace(strings.Map(shown, desc))
	if len(desc) > maxDescription {
		desc = strings.ToValidUTF8(desc[:maxDescription], "") + "…"
	}
	return desc, extra, author
}

// shown keeps a description's character, a line break as a space, but
// drops control and bidirectional-override characters: the text is its
// author's, shown as plain text, and shouldn't be able to reorder or hide
// what's around it.
func shown(r rune) rune {
	switch {
	case r == '\n' || r == '\t':
		return ' '
	case unicode.IsControl(r), r >= 0x202A && r <= 0x202E, r >= 0x2066 && r <= 0x2069, r == 0x200E, r == 0x200F:
		return -1
	}
	return r
}

// tokens is about what listing text costs: Claude Code 2.1.310's /skills
// gave 5 to 21 tokens for skills whose name and description were 14 to 62
// characters, about 0.35 a character.
func tokens(text string) int {
	return int(math.Round(float64(utf8.RuneCountInString(text)) * 0.35))
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
		if b, err := claudemcp.ReadFile(path); err == nil {
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
