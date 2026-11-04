// Package piskills reads the skills Pi or PiG uses in a folder and turns
// them on and off as it does (PiG 0.5.3, Pi 1.4.0; docs/facts/pig.md,
// docs/facts/pi.md):
//   - the project's: .pi/skills in the folder itself ("project") and
//     .agents/skills in the folder and each folder above it up to the
//     repository's root, or to / outside git ("shared"); they load only
//     once Pi trusts the folder (its trust.json, the nearest folder's
//     decision, or defaultProjectTrust "always");
//   - yours: <agent dir>/skills ("user") and ~/.agents/skills ("shared",
//     everywhere);
//   - the first of a name wins, in that order; a skill needs a description
//     in its front matter; its name is the front matter's, else its
//     folder's;
//   - off: a "-<skill folder>" entry in the skills list of the settings
//     file of the skill's scope: <agent dir>/settings.json for yours, the
//     folder's .pi/settings.json for the project's (each reaches only its
//     own); a "!<glob>" entry there turns off every skill whose folder
//     name matches.
//
// Pi also follows linked roots and searches skill folders' subfolders,
// and reads skills named in settings and packages; Nushi lists one level
// of real roots (ADR 0052's rule) and no settings' or packages' skills.
// Nothing here runs Pi.
package piskills

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

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/jsonsettings"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/pi"
	"github.com/afrase/nushi/internal/skillfile"
)

// Skills reads and changes a Flavor's skills.
type Skills struct{ pi.Flavor }

// root is a skills folder and what its skills are.
type root struct {
	path, source string
	project      bool // the project's: loads once the folder is trusted
	everywhere   bool
}

// roots are the skills folders Pi reads for folder, in its order.
func (k Skills) roots(folder string) []root {
	home, _ := os.UserHomeDir()
	out := []root{}
	if !skillfile.Linked(folder, k.Folder+"/skills") {
		out = append(out, root{path: filepath.Join(folder, k.Folder, "skills"), source: "project", project: true})
	}
	top := skillfile.Top(git.RealPath(folder))
	for _, r := range skillfile.Roots(folder, walkTop(folder, top), ".agents/skills") {
		if filepath.Dir(filepath.Dir(r)) != home { // your own, read as yours below
			out = append(out, root{path: r, source: "shared", project: true})
		}
	}
	return append(out,
		root{path: filepath.Join(k.AgentDir(), "skills"), source: "user"},
		root{path: filepath.Join(home, ".agents", "skills"), source: "shared", everywhere: true})
}

// walkTop is where the walk up from folder stops: its repository's root
// (found on the real path, stopped at on folder's own spelling), or /.
func walkTop(folder, top string) string {
	if top == "" {
		return ""
	}
	for dir := folder; ; dir = filepath.Dir(dir) {
		if git.RealPath(dir) == top {
			return dir
		}
		if dir == filepath.Dir(dir) {
			return ""
		}
	}
}

// settings is the part of a Pi settings file read here.
type settings struct {
	Skills              []string `json:"skills"`
	DefaultProjectTrust string   `json:"defaultProjectTrust"`
}

func (k Skills) userSettings() string { return filepath.Join(k.AgentDir(), "settings.json") }

func (k Skills) projectSettings(folder string) string {
	return filepath.Join(folder, k.Folder, "settings.json")
}

// readSettings reads a settings file; a missing one is empty.
func readSettings(file string) (settings, error) {
	var s settings
	err := jsonsettings.Read(file, &s)
	return s, err
}

// trusted says Pi loads folder's own skills: the nearest decision in its
// trust.json for the folder (its real path) or one above it, else your
// settings' defaultProjectTrust "always".
func (k Skills) trusted(folder string, user settings) bool {
	var decisions map[string]bool
	_ = jsonsettings.Read(filepath.Join(k.AgentDir(), "trust.json"), &decisions) // unreadable: no decisions
	for dir := git.RealPath(folder); ; dir = filepath.Dir(dir) {
		if v, ok := decisions[dir]; ok {
			return v
		}
		if dir == filepath.Dir(dir) {
			return user.DefaultProjectTrust == "always"
		}
	}
}

// off says a settings file's skills list turns off the skill in dir:
// "-<dir>" or "-skills/<folder>" (relative to the root's base folder, .pi
// or .agents, as Pi matches it) exactly, or a "!<glob>" on its folder's
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

// List returns Pi's skills in folder: the shared ones among them; the
// project's marked "untrusted" when Pi doesn't trust the folder.
func (k Skills) List(_ context.Context, folder string) (model.Skills, error) {
	out := model.Skills{ReadsShared: true}
	user, uerr := readSettings(k.userSettings())
	project, perr := readSettings(k.projectSettings(folder))
	if err := cmp.Or(uerr, perr); err != nil {
		out.NoSwitch = err.Error()
	}
	trust := k.trusted(folder, user)
	seen := map[string]bool{}
	for _, r := range k.roots(folder) {
		for _, f := range skillfile.List(r.path) {
			name := cmp.Or(f.Name, f.Entry)
			if !f.Described || seen[name] && (trust || !r.project) {
				continue // Pi skips one without a description, and a name already taken
			}
			s := model.Skill{Name: name, Description: f.Description, Source: r.source, Path: f.Dir, Linked: f.Linked,
				Everywhere: r.everywhere, State: "on", Tokens: skillfile.Tokens(name + f.Description)}
			list, file := user.Skills, k.userSettings()
			if r.project {
				list, file = project.Skills, k.projectSettings(folder)
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

// SetSkillOn turns a skill off with a "-<folder>" entry in its scope's
// settings file, or on by dropping it. Refused for a project's skill Pi
// doesn't load (the folder isn't trusted), and where a "!" entry decides.
func (k Skills) SetSkillOn(ctx context.Context, folder, source, name string, on bool) error {
	l, _ := k.List(ctx, folder)
	s, ok := l.Find(source, name)
	if !ok {
		return fmt.Errorf("%s has no %s skill %q here", k.Title, source, name)
	}
	switch {
	case s.State == "untrusted":
		return fmt.Errorf("%s loads this folder's skills only once you trust it (/trust in %s)", k.Title, k.CLI)
	case s.SetIn != "":
		return fmt.Errorf("a pattern in %s turns it off; change it there", s.SetIn)
	}
	// The entries this skill's switch writes and drops: yours by its
	// folder's path (your own file); the project's relative to the root's
	// base folder ("skills/<folder>", which Pi matches against .pi and
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
		_, err := jsonsettings.Edit(k.userSettings(), func(m map[string]json.RawMessage) error {
			b, err := change(m["skills"])
			m["skills"] = b
			if string(b) == "[]" {
				delete(m, "skills")
			}
			return err
		})
		return err
	}
	file := k.projectSettings(folder)
	for _, p := range []string{filepath.Dir(file), file} {
		if fi, err := os.Lstat(p); err == nil && fi.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("%s is a symlink; not changing it", p)
		}
	}
	// Only the skills key, every other byte kept, through the folder's
	// root (a .pi swapped for a link meanwhile can't lead out of it).
	return jsonsettings.SetKeyIn(folder, filepath.Join(k.Folder, "settings.json"), "skills", change)
}

// Trash moves one of Pi's own skill folders to the Trash: right in your
// skills folder or the folder's .pi/skills.
func (k Skills) Trash(ctx context.Context, folder, path string) error {
	var project, yours []string
	for _, r := range k.roots(folder) {
		switch r.source {
		case "user":
			yours = append(yours, r.path)
		case "project":
			project = append(project, r.path)
		}
	}
	return skillfile.Trash(ctx, project, yours, path)
}
