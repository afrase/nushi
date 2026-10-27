// Package pigskills reads the skills PiG uses in a folder and turns them
// on and off as PiG does (PiG 0.5.3; docs/facts/pig.md):
//   - the project's: .pig/skills in the folder itself ("project") and
//     .agents/skills in the folder and each folder above it up to the
//     repository's root, or to / outside git ("shared"); they load only
//     once PiG trusts the folder (its trust.json, the nearest folder's
//     decision, or defaultProjectTrust "always");
//   - yours: <agent dir>/skills ("user") and ~/.agents/skills ("shared",
//     everywhere);
//   - the first of a name wins, in that order; a skill needs a description
//     in its front matter; its name is the front matter's, else its
//     folder's;
//   - off: a "-<skill folder>" entry in the skills list of the settings
//     file of the skill's scope: <agent dir>/settings.json for yours, the
//     folder's .pig/settings.json for the project's (each reaches only its
//     own); a "!<glob>" entry there turns off every skill whose folder
//     name matches.
//
// PiG also follows linked roots and searches skill folders' subfolders,
// and reads skills named in settings and packages; Nushi lists one level
// of real roots (the step-300 rule) and no settings' or packages' skills.
// Nothing here runs PiG.
package pigskills

import (
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/jsonsettings"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/pig"
	"github.com/afrase/nushi/internal/skillfile"
)

// PiG reads and changes PiG's skills.
type PiG struct{}

// root is a skills folder and what its skills are.
type root struct {
	path, source string
	project      bool // the project's: loads once the folder is trusted
	everywhere   bool
}

// roots are the skills folders PiG reads for folder, in its order.
func roots(folder string) []root {
	home, _ := os.UserHomeDir()
	out := []root{}
	if !skillfile.Linked(folder, ".pig/skills") {
		out = append(out, root{path: filepath.Join(folder, ".pig", "skills"), source: "project", project: true})
	}
	top := skillfile.Top(realPath(folder))
	for _, r := range skillfile.Roots(folder, walkTop(folder, top), ".agents/skills") {
		if filepath.Dir(filepath.Dir(r)) != home { // your own, read as yours below
			out = append(out, root{path: r, source: "shared", project: true})
		}
	}
	return append(out,
		root{path: filepath.Join(pig.AgentDir(), "skills"), source: "user"},
		root{path: filepath.Join(home, ".agents", "skills"), source: "shared", everywhere: true})
}

// walkTop is where the walk up from folder stops: its repository's root
// (found on the real path, stopped at on folder's own spelling), or /.
func walkTop(folder, top string) string {
	if top == "" {
		return ""
	}
	for dir := folder; ; dir = filepath.Dir(dir) {
		if realPath(dir) == top {
			return dir
		}
		if dir == filepath.Dir(dir) {
			return ""
		}
	}
}

func realPath(p string) string {
	if r, err := filepath.EvalSymlinks(p); err == nil {
		return r
	}
	return p
}

// settings is the part of a PiG settings file read here.
type settings struct {
	Skills              []string `json:"skills"`
	DefaultProjectTrust string   `json:"defaultProjectTrust"`
}

func userSettings() string { return filepath.Join(pig.AgentDir(), "settings.json") }

func projectSettings(folder string) string { return filepath.Join(folder, ".pig", "settings.json") }

// readSettings reads a settings file; a missing one is empty.
func readSettings(file string) (settings, error) {
	var s settings
	b, err := jsonsettings.ReadFile(file)
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err == nil {
		err = json.Unmarshal(b, &s)
	}
	if err != nil {
		return s, fmt.Errorf("%s doesn't read: %w", file, err)
	}
	return s, nil
}

// trusted says PiG loads folder's own skills: the nearest decision in its
// trust.json for the folder (its real path) or one above it, else your
// settings' defaultProjectTrust "always".
func trusted(folder string, user settings) bool {
	var decisions map[string]bool
	if b, err := jsonsettings.ReadFile(filepath.Join(pig.AgentDir(), "trust.json")); err == nil {
		_ = json.Unmarshal(b, &decisions) // unreadable: no decisions
	}
	for dir := realPath(folder); ; dir = filepath.Dir(dir) {
		if v, ok := decisions[dir]; ok {
			return v
		}
		if dir == filepath.Dir(dir) {
			return user.DefaultProjectTrust == "always"
		}
	}
}

// off says a settings file's skills list turns off the skill in dir:
// "-<dir>" or "-skills/<folder>" (relative to the root's base folder, .pig
// or .agents, as PiG matches it) exactly, or a "!<glob>" on its folder's
// name; "+" with either keeps it on. by is the entry that does.
func off(list []string, dir string) (bool, string) {
	rel := "skills/" + filepath.Base(dir)
	if slices.Contains(list, "+"+dir) || slices.Contains(list, "+"+rel) {
		return false, ""
	}
	for _, e := range list {
		if glob, ok := strings.CutPrefix(e, "!"); ok {
			if m, _ := path.Match(glob, filepath.Base(dir)); m {
				return true, e
			}
		}
		if e == "-"+dir || e == "-"+rel {
			return true, e
		}
	}
	return false, ""
}

// List returns PiG's skills in folder: the shared ones among them; the
// project's marked "untrusted" when PiG doesn't trust the folder.
func (PiG) List(_ context.Context, folder string) (model.Skills, error) {
	out := model.Skills{ReadsShared: true}
	user, uerr := readSettings(userSettings())
	project, perr := readSettings(projectSettings(folder))
	if err := cmp.Or(uerr, perr); err != nil {
		out.NoSwitch = err.Error()
	}
	trust := trusted(folder, user)
	seen := map[string]bool{}
	for _, r := range roots(folder) {
		for _, f := range skillfile.List(r.path) {
			name := cmp.Or(f.Name, f.Entry)
			if !f.Described || seen[name] && (trust || !r.project) {
				continue // PiG skips one without a description, and a name already taken
			}
			s := model.Skill{Name: name, Description: f.Description, Source: r.source, Path: f.Dir, Linked: f.Linked,
				Everywhere: r.everywhere, State: "on", Tokens: skillfile.Tokens(name + f.Description)}
			list, file := user.Skills, userSettings()
			if r.project {
				list, file = project.Skills, projectSettings(folder)
			}
			if isOff, by := off(list, f.Dir); isOff {
				s.State = "off"
				if !strings.HasPrefix(by, "-") {
					s.SetIn = file
				}
			}
			if r.project && !trust {
				s.State = "untrusted"
			} else {
				seen[name] = true
			}
			out.Skills = append(out.Skills, s)
		}
	}
	return out, nil
}

// Shared returns the shared skills PiG loads in folder (or would, once
// trusted).
func (p PiG) Shared(ctx context.Context, folder string) []model.Skill {
	l, _ := p.List(ctx, folder)
	return slices.DeleteFunc(l.Skills, func(s model.Skill) bool { return s.Source != "shared" })
}

// SetSkillOn turns a skill off with a "-<folder>" entry in its scope's
// settings file, or on by dropping it. Refused for a project's skill PiG
// doesn't load (the folder isn't trusted), and where a "!" entry decides.
func (p PiG) SetSkillOn(ctx context.Context, folder, source, name string, on bool) error {
	l, _ := p.List(ctx, folder)
	i := slices.IndexFunc(l.Skills, func(s model.Skill) bool { return s.Source == source && s.Name == name })
	if i < 0 {
		return fmt.Errorf("PiG has no %s skill %q here", source, name)
	}
	s := l.Skills[i]
	switch {
	case s.State == "untrusted":
		return errors.New("PiG loads this folder's skills only once you trust it (/trust in pig)")
	case s.SetIn != "":
		return fmt.Errorf("a pattern in %s turns it off; change it there", s.SetIn)
	}
	// The entries this skill's switch writes and drops: yours by its
	// folder's path (your own file); the project's relative to the root's
	// base folder ("skills/<folder>", which PiG matches against .pig and
	// each .agents alike), so no path of yours goes into a file the
	// repository may commit.
	entry := s.Path
	drop := []string{"-" + s.Path, "+" + s.Path}
	project := s.Source == "project" || s.Source == "shared" && !s.Everywhere
	if project {
		entry = "skills/" + filepath.Base(s.Path)
		drop = append(drop, "-"+entry, "+"+entry)
	}
	change := func(raw json.RawMessage) (json.RawMessage, error) {
		var list []string
		if len(raw) > 0 && string(raw) != "null" && json.Unmarshal(raw, &list) != nil {
			return nil, errors.New("skills isn't a list")
		}
		list = slices.DeleteFunc(list, func(e string) bool { return slices.Contains(drop, e) })
		if !on {
			list = append(list, "-"+entry)
		}
		if list == nil {
			list = []string{}
		}
		return json.Marshal(list)
	}
	if !project {
		file := userSettings()
		if resolved, err := filepath.EvalSymlinks(file); err == nil {
			file = resolved // your dotfiles' link: change what it points at
		}
		_, err := jsonsettings.Edit(file, func(m map[string]json.RawMessage) error {
			b, err := change(m["skills"])
			m["skills"] = b
			if string(b) == "[]" {
				delete(m, "skills")
			}
			return err
		})
		return err
	}
	file := projectSettings(folder)
	for _, p := range []string{filepath.Dir(file), file} {
		if fi, err := os.Lstat(p); err == nil && fi.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("%s is a symlink; not changing it", p)
		}
	}
	// Only the skills key, every other byte kept, through the folder's
	// root (a .pig swapped for a link meanwhile can't lead out of it).
	return jsonsettings.SetKeyIn(folder, filepath.Join(".pig", "settings.json"), "skills", change)
}

// Trash moves one of PiG's own skill folders to the Trash: right in your
// skills folder or the folder's .pig/skills.
func (PiG) Trash(ctx context.Context, folder, path string) error {
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
