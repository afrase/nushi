// Package codexskills reads the skills Codex uses in a folder and turns
// them on and off as Codex documents it (Codex 0.163.0, as its
// app-server's skills/list has them; docs/facts/codex.md):
//   - yours: $CODEX_HOME/skills/<dir>/SKILL.md ("user"), the ones Codex
//     installs itself in its .system folder ("system"), and
//     ~/.agents/skills ("shared", everywhere);
//   - the project's: .codex/skills ("project") and .agents/skills
//     ("shared") in the folder and each folder above it up to the
//     repository's root (the nearest .git), or only the folder's own
//     outside git; trusted or not;
//   - a skill needs front matter with a description; its name is the
//     front matter's, else its folder's; a SKILL.md that is a link is
//     skipped, as Codex skips it;
//   - whether it's on: [[skills.config]] entries in $CODEX_HOME/config.toml
//     (by the resolved SKILL.md's path, or by name), the last that matches
//     winning (config.go).
//
// Codex follows a linked .agents or skills folder; Nushi leaves a
// project's out (ADR 0052's rule: a repository's link could point the
// listing, and Delete, anywhere). Plugins' skills aren't listed. Nothing
// here runs Codex.
package codexskills

import (
	"cmp"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/internal/codex"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/skillfile"
)

// Codex reads and changes Codex's skills.
type Codex struct{}

// root is a skills folder and what its skills are.
type root struct {
	path, source string
	everywhere   bool // a shared folder of yours, not the project's
}

// roots are the skills folders Codex reads for folder: yours, then the
// project's, nearest first.
func roots(folder string) []root {
	userHome, _ := os.UserHomeDir()
	out := []root{
		{path: filepath.Join(codex.Home(), "skills"), source: "user"},
		{path: filepath.Join(codex.Home(), "skills", ".system"), source: "system"},
		{path: filepath.Join(userHome, ".agents", "skills"), source: "shared", everywhere: true},
	}
	folder = git.RealPath(folder)
	top := cmp.Or(skillfile.Top(folder), folder)
	for _, kind := range []struct{ rel, source string }{{".codex/skills", "project"}, {".agents/skills", "shared"}} {
		for _, r := range skillfile.Roots(folder, top, kind.rel) {
			if !slices.ContainsFunc(out, func(o root) bool { return o.path == r }) {
				out = append(out, root{path: r, source: kind.source})
			}
		}
	}
	return out
}

// List returns Codex's skills in folder, the shared ones among them, each
// on or off as config.toml says. A config.toml that doesn't read leaves
// them all on, without switches.
func (Codex) List(_ context.Context, folder string) (model.Skills, error) {
	var out model.Skills
	out.ReadsShared = true
	entries, err := readEntries()
	if err != nil {
		out.NoSwitch = err.Error()
	}
	for _, r := range roots(folder) {
		for _, f := range skillfile.List(r.path) {
			if f.FileLinked || !f.Described {
				continue // Codex skips a linked SKILL.md, and one without a description in front matter
			}
			s := model.Skill{Name: cmp.Or(f.Name, f.Entry), Description: f.Description, Source: r.source, Path: f.Dir,
				Linked: f.Linked, Everywhere: r.everywhere, State: "on"}
			s.Tokens = skillfile.Tokens(s.Name + s.Description)
			if !enabled(entries, skillFile(f.Dir), s.Name) {
				s.State = "off"
			}
			out.Skills = append(out.Skills, s)
		}
	}
	return out, nil
}

// skillFile is a skill's SKILL.md as Codex names it: links resolved.
func skillFile(dir string) string { return git.RealPath(filepath.Join(dir, "SKILL.md")) }

// find is folder's skill of source and name, as listed.
func (c Codex) find(ctx context.Context, folder, source, name string) (model.Skill, error) {
	l, _ := c.List(ctx, folder)
	if s, ok := l.Find(source, name); ok {
		return s, nil
	}
	return model.Skill{}, fmt.Errorf("Codex has no %s skill %q here", source, name)
}

// SetSkillOn turns a skill off with a [[skills.config]] entry for its
// SKILL.md in Codex's config.toml, or on by dropping that entry (config.go).
func (c Codex) SetSkillOn(ctx context.Context, folder, source, name string, on bool) error {
	s, err := c.find(ctx, folder, source, name)
	if err != nil {
		return err
	}
	return setOn(configFile(), skillFile(s.Path), s.Name, on)
}

// Trash moves one of Codex's skill folders to the Trash: only right in
// your skills folder or one of the project's .codex/skills (not Codex's
// own .system ones, which it puts back).
func (Codex) Trash(ctx context.Context, folder, path string) error {
	var project, yours []string
	for _, r := range roots(folder) {
		switch r.source {
		case "user":
			yours = append(yours, r.path)
		case "project":
			project = append(project, r.path)
		}
	}
	return skillfile.Trash(ctx, project, yours, path)
}
