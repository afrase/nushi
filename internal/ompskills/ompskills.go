// Package ompskills reads the skills oh-my-pi uses in a folder and turns
// them on and off as omp does (omp 18.12.6; docs/facts/omp.md):
//   - in the folder and each folder above it, up to the repository's root
//     (outside git, up to your home folder, never it): .omp/skills,
//     .claude/skills, .agent/skills ("project") and .agents/skills
//     ("shared"); the nearest .codex/skills; the folder's own
//     .github/skills;
//   - yours: <agent dir>/skills ("user"; PI_CODING_AGENT_DIR, else
//     ~/.omp/agent), ~/.agents/skills ("shared", everywhere),
//     ~/.agent/skills, and ~/.claude/skills only with
//     skills.enableClaudeUser;
//   - no trust; a name in two places is kept twice (omp renames one);
//     .omp's and .github's need a description;
//   - off by name: "skill:<name>" in disabledExtensions, or a
//     skills.ignoredSkills glob, in your config.yml (everywhere) or the
//     project's nearest .omp/config.yml (config.go).
//
// omp follows linked roots; Nushi leaves a project's out (the step-300
// rule). Plugins' and skillshare's skills aren't listed. Nothing here runs
// omp.
package ompskills

import (
	"cmp"
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/omp"
	"github.com/afrase/nushi/internal/skillfile"
)

// OMP reads and changes omp's skills.
type OMP struct{}

type root struct {
	path, source string
	everywhere   bool
	described    bool // its skills need a description
}

// walk is folder and the folders above it omp reads, nearest first.
func walk(folder string) []string {
	home, _ := os.UserHomeDir()
	top := skillfile.Top(folder)
	var out []string
	for dir := folder; dir != home; dir = filepath.Dir(dir) {
		out = append(out, dir)
		if dir == top || dir == filepath.Dir(dir) {
			break
		}
	}
	return out
}

// roots are the skills folders omp reads for folder, in its order.
func roots(folder string, cfg config) []root {
	home, _ := os.UserHomeDir()
	dirs := walk(folder)
	var out []root
	project := func(rel, source string, described bool, dirs []string) {
		for _, d := range dirs {
			if !skillfile.Linked(d, rel) {
				out = append(out, root{path: filepath.Join(d, rel), source: source, described: described})
			}
		}
	}
	project(".omp/skills", "project", true, dirs)
	out = append(out, root{path: filepath.Join(omp.AgentDir(), "skills"), source: "user", described: true})
	if cfg.on("enableClaudeProject", true) {
		project(".claude/skills", "project", false, dirs)
	}
	if cfg.on("enableClaudeUser", false) {
		out = append(out, root{path: filepath.Join(home, ".claude", "skills"), source: "user"})
	}
	if cfg.on("enableAgentsProject", true) {
		for _, d := range dirs {
			project(".agents/skills", "shared", false, []string{d})
			project(".agent/skills", "project", false, []string{d})
		}
	}
	if cfg.on("enableAgentsUser", true) {
		out = append(out, root{path: filepath.Join(home, ".agents", "skills"), source: "shared", everywhere: true},
			root{path: filepath.Join(home, ".agent", "skills"), source: "user"})
	}
	for _, d := range dirs {
		if fi, err := os.Stat(filepath.Join(d, ".codex")); err == nil && fi.IsDir() {
			project(".codex/skills", "project", false, []string{d})
			break
		}
	}
	project(".github/skills", "project", true, dirs[:min(1, len(dirs))])
	return out
}

// List returns omp's skills in folder, the shared ones among them.
func (OMP) List(_ context.Context, folder string) (model.Skills, error) {
	out := model.Skills{ReadsShared: true}
	folder = git.RealPath(folder)
	cfg, err := readConfig(folder)
	if err != nil {
		out.NoSwitch = err.Error()
	}
	seen := map[string]bool{}
	for _, r := range roots(folder, cfg) {
		for _, f := range skillfile.List(r.path) {
			if r.described && !f.Described || seen[f.Dir] {
				continue
			}
			seen[f.Dir] = true
			name := cmp.Or(f.Name, f.Entry)
			s := model.Skill{Name: name, Description: f.Description, Source: r.source, Path: f.Dir, Linked: f.Linked,
				Everywhere: r.everywhere, State: "on", Tokens: skillfile.Tokens(name + f.Description)}
			if off, setIn := cfg.off(name); off {
				s.State, s.SetIn = "off", setIn
			}
			out.Skills = append(out.Skills, s)
		}
	}
	return out, nil
}

// SetSkillOn turns a skill off by its name in your config.yml's
// disabledExtensions (every skill of the name, everywhere), or on by
// taking it out; refused where a pattern or the project's config decides.
func (o OMP) SetSkillOn(ctx context.Context, folder, source, name string, on bool) error {
	l, _ := o.List(ctx, folder)
	s, ok := l.Find(source, name)
	if !ok {
		return fmt.Errorf("omp has no %s skill %q here", source, name)
	}
	if set := s.SetIn; set != "" {
		return fmt.Errorf("it's off in %s; change it there", set)
	}
	return setDisabled(userConfig(), "skill:"+name, !on)
}

// Trash moves one of omp's own skill folders to the Trash: right in your
// skills folder or a .omp/skills omp reads here.
func (OMP) Trash(ctx context.Context, folder, path string) error {
	var project []string
	for _, d := range walk(git.RealPath(folder)) {
		if !skillfile.Linked(d, ".omp/skills") {
			project = append(project, filepath.Join(d, ".omp", "skills"))
		}
	}
	return skillfile.Trash(ctx, project, []string{filepath.Join(omp.AgentDir(), "skills")}, path)
}
