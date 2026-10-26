// Package anteskills reads the skills Ante uses in a folder and turns them
// on and off as Ante does (Ante 0.2.14; docs/facts/ante.md):
//   - the project's, in the folder itself only (no walk up): .ante/skills
//     and .claude/skills ("project"), .agents/skills ("shared");
//   - yours: $ANTE_HOME/skills and ~/.claude/skills ("user"),
//     ~/.agents/skills ("shared", everywhere); its bundled ones in
//     $ANTE_HOME/.system/skills ("system");
//   - a name is the front matter's, else the folder's; the project's win
//     over yours, and .ante over .agents over .claude;
//   - off by name: exclude_skills in $ANTE_HOME/settings.json (or the
//     nearest .ante/settings.json, which adds to it), for every skill of
//     that name; skills: false turns them all off.
//
// No trust: a folder's skills load at once. Nushi leaves a linked project
// root out (the step-300 rule; Ante follows it). Nothing here runs Ante:
// its own list comes only from a session in the folder.
package anteskills

import (
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/jsonsettings"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/skillfile"
)

// Ante reads and changes Ante's skills.
type Ante struct{}

type root struct {
	path, source string
	everywhere   bool
}

// roots are the skills folders Ante reads for folder, the one that wins
// a name first.
func roots(folder string) []root {
	home, _ := os.UserHomeDir()
	var out []root
	for _, r := range []root{
		{path: ".ante/skills", source: "project"}, {path: ".agents/skills", source: "shared"}, {path: ".claude/skills", source: "project"},
	} {
		if !skillfile.Linked(folder, r.path) && folder != home {
			out = append(out, root{path: filepath.Join(folder, r.path), source: r.source})
		}
	}
	return append(out,
		root{path: filepath.Join(ante.Home(), "skills"), source: "user"},
		root{path: filepath.Join(home, ".agents", "skills"), source: "shared", everywhere: true},
		root{path: filepath.Join(home, ".claude", "skills"), source: "user"},
		root{path: filepath.Join(ante.Home(), ".system", "skills"), source: "system"})
}

// settings is what's read of an Ante settings file.
type settings struct {
	path    string
	Skills  *bool    `json:"skills"`
	Exclude []string `json:"exclude_skills"`
}

func userSettings() string { return filepath.Join(ante.Home(), "settings.json") }

// readSettings reads the project's nearest .ante/settings.json (if any)
// and yours, in that order.
func readSettings(folder string) ([]settings, error) {
	files := []string{}
	for dir := folder; ; dir = filepath.Dir(dir) {
		p := filepath.Join(dir, ".ante", "settings.json")
		if _, err := os.Stat(p); err == nil && p != userSettings() {
			files = append(files, p)
			break
		}
		if dir == filepath.Dir(dir) {
			break
		}
	}
	var out []settings
	var errs []error
	for _, f := range append(files, userSettings()) {
		s := settings{path: f}
		b, err := jsonsettings.ReadFile(f)
		if err == nil {
			err = json.Unmarshal(b, &s)
		}
		if err != nil && !errors.Is(err, os.ErrNotExist) {
			errs = append(errs, fmt.Errorf("%s doesn't read: %w", f, err))
		}
		out = append(out, s)
	}
	return out, errors.Join(errs...)
}

// state is a skill's state by name, and the file that decides it when
// that isn't your settings' exclude_skills.
func state(files []settings, name string) (on bool, setIn string) {
	for _, f := range files {
		if f.Skills != nil {
			if !*f.Skills {
				return false, f.path
			}
			break
		}
	}
	for _, f := range files {
		if slices.Contains(f.Exclude, name) {
			if f.path != userSettings() {
				return false, f.path
			}
			return false, ""
		}
	}
	return true, ""
}

// List returns Ante's skills in folder, the shared ones among them.
func (Ante) List(_ context.Context, folder string) (model.Skills, error) {
	out := model.Skills{ReadsShared: true}
	files, err := readSettings(folder)
	if err != nil {
		out.NoSwitch = err.Error()
	}
	seen := map[string]bool{}
	for _, r := range roots(folder) {
		for _, f := range skillfile.List(r.path) {
			name := cmp.Or(f.Name, f.Entry)
			if seen[name] {
				continue
			}
			seen[name] = true
			s := model.Skill{Name: name, Description: f.Description, Source: r.source, Path: f.Dir, Linked: f.Linked,
				Everywhere: r.everywhere, State: "on", Tokens: skillfile.Tokens(name + f.Description)}
			on, setIn := state(files, name)
			if !on {
				s.State, s.SetIn = "off", setIn
			}
			out.Skills = append(out.Skills, s)
		}
	}
	return out, nil
}

// Shared returns the shared skills Ante loads in folder.
func (a Ante) Shared(ctx context.Context, folder string) []model.Skill {
	l, _ := a.List(ctx, folder)
	return slices.DeleteFunc(l.Skills, func(s model.Skill) bool { return s.Source != "shared" })
}

// SetSkillOn turns a skill off by its name in your settings'
// exclude_skills (every skill of the name, everywhere), or on by taking
// it out; refused where a project's file or skills: false decides.
func (a Ante) SetSkillOn(ctx context.Context, folder, source, name string, on bool) error {
	l, _ := a.List(ctx, folder)
	i := slices.IndexFunc(l.Skills, func(s model.Skill) bool { return s.Source == source && s.Name == name })
	if i < 0 {
		return fmt.Errorf("Ante has no %s skill %q here", source, name)
	}
	if set := l.Skills[i].SetIn; set != "" {
		return fmt.Errorf("it's off in %s; change it there", set)
	}
	file := userSettings()
	if resolved, err := filepath.EvalSymlinks(file); err == nil {
		file = resolved
	}
	_, err := jsonsettings.Edit(file, func(m map[string]json.RawMessage) error {
		var list []string
		if raw, ok := m["exclude_skills"]; ok && string(raw) != "null" && json.Unmarshal(raw, &list) != nil {
			return errors.New("exclude_skills isn't a list")
		}
		list = slices.DeleteFunc(list, func(n string) bool { return n == name })
		if !on {
			list = append(list, name)
		}
		if len(list) == 0 {
			delete(m, "exclude_skills")
			return nil
		}
		b, err := json.Marshal(list)
		m["exclude_skills"] = b
		return err
	})
	return err
}

// Trash moves one of Ante's own skill folders to the Trash: right in
// your skills folder or the folder's .ante/skills (not Claude's, nor its
// bundled ones).
func (Ante) Trash(ctx context.Context, folder, path string) error {
	allowed := []string{filepath.Join(ante.Home(), "skills")}
	if !skillfile.Linked(folder, ".ante/skills") {
		allowed = append(allowed, filepath.Join(folder, ".ante", "skills"))
	}
	return skillfile.Trash(ctx, allowed, path)
}
