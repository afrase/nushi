// Package opencodeskills reads the skills opencode uses in a folder and
// turns them on and off as opencode does (opencode 2.2.6;
// docs/facts/opencode.md):
//   - one skill an id, from the first of these places that has it:
//     .opencode/skills, then .opencode/skill, in the folder and each
//     folder above it up to / ("project"); <config>/skills, then
//     <config>/skill ("user"; OPENCODE_CONFIG_DIR, else
//     $XDG_CONFIG_HOME/opencode, else ~/.config/opencode); .agents/skills
//     in the same folders ("shared") and ~/.agents/skills ("shared",
//     everywhere); .claude/skills in them ("project") and
//     ~/.claude/skills ("user");
//   - in a place, a folder holding a SKILL.md is a skill and its id is
//     the folder's name, whatever its front matter says; a folder without
//     one is a group of them, read six deep; a <name>.md right in the
//     place is a skill too, and so is the place itself when it holds a
//     SKILL.md (scan.go);
//   - no trust: a folder's skills load as soon as opencode runs there;
//   - off by id, whichever place it comes from: a skill.use deny among
//     the policies of your global opencode.json or opencode.jsonc
//     (config.go, switch.go).
//
// opencode follows linked places; Nushi leaves a project's out (ADR
// 0052's rule), and a linked group in one. Its built-in skills, and those
// of the system's folder, of a config's skills list or of a Console
// library, aren't listed. Nothing here runs opencode.
package opencodeskills

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/opencode"
	"github.com/afrase/nushi/internal/skillfile"
)

// OpenCode reads and changes opencode's skills.
type OpenCode struct{}

// configDir is opencode's global config folder (opencode.ConfigDir).
func configDir() string {
	home, _ := os.UserHomeDir()
	return opencode.ConfigDir(home)
}

type root struct {
	path, source string
	everywhere   bool
	project      bool // in the folder or one above it, not yours
}

// same says a and b are one folder, however each is reached.
func same(a, b string) bool {
	x, errA := os.Stat(a)
	y, errB := os.Stat(b)
	return errA == nil && errB == nil && os.SameFile(x, y)
}

// roots are the skills folders opencode reads for folder, the winner of
// an id first. Your home folder's own .agents and .claude, and the config
// folder when it is on the way up, are yours and not a project's; in the
// config folder itself opencode reads no project at all.
func roots(folder string) []root {
	home, _ := os.UserHomeDir()
	config := configDir()
	var dirs []string
	if filepath.IsAbs(folder) && !same(folder, config) {
		for dir := folder; ; dir = filepath.Dir(dir) {
			dirs = append(dirs, dir)
			if dir == filepath.Dir(dir) {
				break
			}
		}
	}
	var out []root
	project := func(source, yours string, rels ...string) {
		for _, d := range dirs {
			for _, rel := range rels {
				if !same(filepath.Join(d, filepath.Dir(rel)), yours) && !skillfile.Linked(d, rel) {
					out = append(out, root{path: filepath.Join(d, rel), source: source, project: true})
				}
			}
		}
	}
	project("project", config, ".opencode/skills", ".opencode/skill")
	out = append(out, root{path: filepath.Join(config, "skills"), source: "user"}, root{path: filepath.Join(config, "skill"), source: "user"})
	project("shared", filepath.Join(home, ".agents"), ".agents/skills")
	out = append(out, root{path: filepath.Join(home, ".agents", "skills"), source: "shared", everywhere: true})
	project("project", filepath.Join(home, ".claude"), ".claude/skills")
	return append(out, root{path: filepath.Join(home, ".claude", "skills"), source: "user"})
}

// List returns opencode's skills in folder, the shared ones among them.
func (OpenCode) List(_ context.Context, folder string) (model.Skills, error) {
	out := model.Skills{ReadsShared: true}
	folder = git.RealPath(folder)
	docs, err := readGlobal()
	if err != nil {
		out.NoSwitch = err.Error()
	}
	seen := map[string]bool{}
	for _, r := range roots(folder) {
		for _, f := range scan(r.path, !r.project) {
			if seen[f.id] {
				continue
			}
			seen[f.id] = true
			s := model.Skill{Name: f.id, Description: f.Description, Source: r.source, Path: f.path, OneFile: f.path == f.file,
				Linked: f.linked, Everywhere: r.everywhere, State: "on", Tokens: skillfile.Tokens(f.id + f.Description)}
			if off, setIn := docs.off(f.id); off {
				s.State, s.SetIn = "off", setIn
			}
			out.Skills = append(out.Skills, s)
		}
	}
	return out, nil
}

// own are the places opencode's own skill folders are in: each
// .opencode/skills (or skill) opencode reads here, and your config's.
func own(folder string) (project, yours []string) {
	for _, r := range roots(git.RealPath(folder)) {
		switch {
		case r.project && r.source == "project" && filepath.Base(filepath.Dir(r.path)) == ".opencode":
			project = append(project, r.path)
		case !r.project && filepath.Dir(r.path) == configDir():
			yours = append(yours, r.path)
		}
	}
	return project, yours
}

// CanTrash says why Trash wouldn't move path: nil only for a skill's
// folder right in one of opencode's own places. One in a group, and a
// skill in one file (a lone <name>.md, or the SKILL.md that makes a place
// a skill), stay, and the error says which it is: Nushi's Trash takes a
// skill's folder from its place and nothing else (skillfile.Trash), never
// a file, a folder further down or the place.
func (OpenCode) CanTrash(_ context.Context, folder, path string) error {
	project, yours := own(folder)
	for _, place := range slices.Concat(project, yours) {
		rel, err := filepath.Rel(place, path)
		if err != nil || rel == "." || !filepath.IsLocal(rel) || filepath.Clean(path) != path {
			continue
		}
		if filepath.Dir(path) != place {
			return fmt.Errorf("%s is in a group of skills; Nushi moves only a skill right in %s to the Trash", path, place)
		}
		if fi, err := os.Stat(path); err == nil && fi.Mode().IsRegular() && strings.HasSuffix(path, ".md") {
			return fmt.Errorf("%s is a skill in one file; Nushi moves only a skill's folder to the Trash", path)
		}
	}
	return skillfile.CanTrash(project, yours, path)
}

// Trash moves one of opencode's own skill folders to the Trash: only one
// CanTrash passes.
func (o OpenCode) Trash(ctx context.Context, folder, path string) error {
	if err := o.CanTrash(ctx, folder, path); err != nil {
		return err
	}
	project, yours := own(folder)
	return skillfile.Trash(ctx, project, yours, path)
}
