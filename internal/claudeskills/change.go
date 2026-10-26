package claudeskills

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/model"
)

// Nushi turns skills on and off with Claude's documented skillOverrides
// setting (absent is on), in the file Claude's own advice names: your
// settings for your skill, the project's local settings for a project's.
// Only that key changes (claudemcp.EditUser, EditLocal). Built-in skills
// go on and off together (disableBundledSkills, in your settings), a
// plugin's skills with their plugin, through `claude plugin`. A skill is
// deleted by moving its folder to the Trash (ADR 0051).

// errSetIn says a file that wins over the one Nushi changes decides it.
func errSetIn(what, file string) error {
	return fmt.Errorf("%s is set in %s; change it there", what, file)
}

// SetSkillOn turns your skill or one of folder's project's skills on or
// off. Off is "off"; on drops the skill's override, or says "on" when a
// file below the one changed would keep it off.
func (c Claude) SetSkillOn(ctx context.Context, folder, source, name string, on bool) error {
	if source == "shared" { // a shared skill Claude has through a link of its own: that skill
		i := slices.IndexFunc(c.Shared(ctx, folder), func(s model.Skill) bool { return s.Name == name })
		if i < 0 {
			return fmt.Errorf("Claude doesn't load a shared skill %q here", name)
		}
		source = "project"
		if filepath.Dir(c.Shared(ctx, folder)[i].Agents[0].Via) == userRoot() {
			source = "user"
		}
	}
	roots := map[string][]string{"user": {userRoot()}, "project": projectRoots(ctx, folder)}[source]
	found := false
	for _, root := range roots {
		found = found || slices.ContainsFunc(read(root, source), func(s model.Skill) bool { return s.Name == name })
	}
	if !found {
		return fmt.Errorf("no %s skill %q here", source, name)
	}
	files := settingsFiles(folder)
	t := target(source)
	if _, setIn := state(files, model.Skill{Name: name, Source: source}); setIn != "" {
		return errSetIn(name, setIn)
	}
	value := "off"
	if on {
		value = ""
		for _, f := range files[t+1:] {
			if v, ok := f.SkillOverrides[name]; ok && v != "on" {
				value = "on"
			}
		}
	}
	change := func(settings map[string]json.RawMessage) error {
		overrides := map[string]json.RawMessage{}
		if raw, ok := settings["skillOverrides"]; ok && string(raw) != "null" && json.Unmarshal(raw, &overrides) != nil {
			return errors.New("skillOverrides isn't a map")
		}
		delete(overrides, name)
		if value != "" {
			overrides[name], _ = json.Marshal(value)
		}
		if len(overrides) == 0 {
			delete(settings, "skillOverrides")
			return nil
		}
		b, err := json.Marshal(overrides)
		settings["skillOverrides"] = b
		return err
	}
	if t == 0 {
		return claudemcp.EditLocal(ctx, folder, change)
	}
	return claudemcp.EditUser(change)
}

// SetBuiltInOn turns Claude's built-in skills on or off, everywhere
// (disableBundledSkills in your settings).
func (Claude) SetBuiltInOn(_ context.Context, folder string, on bool) error {
	if _, setIn := builtInOff(settingsFiles(folder)); setIn != "" {
		return errSetIn("Whether built-in skills are on", setIn)
	}
	return claudemcp.EditUser(func(settings map[string]json.RawMessage) error {
		delete(settings, "disableBundledSkills")
		if !on {
			settings["disableBundledSkills"] = json.RawMessage("true")
		}
		return nil
	})
}

// validID is a plugin's id as Claude makes it: "<name>@<marketplace>".
var validID = regexp.MustCompile(`^[A-Za-z0-9_.][A-Za-z0-9_.-]*(@[A-Za-z0-9_.][A-Za-z0-9_.-]*)?$`)

// installed is folder's installed plugin id.
func installed(ctx context.Context, folder, id string) (plugin, error) {
	if !validID.MatchString(id) {
		return plugin{}, fmt.Errorf("%q isn't a plugin's id", id)
	}
	plugins, err := listPlugins(ctx, folder)
	if err != nil {
		return plugin{}, err
	}
	for _, p := range plugins {
		if p.ID == id {
			return p, nil
		}
	}
	return plugin{}, fmt.Errorf("no plugin %s is installed", id)
}

// PluginScope is where SetPluginOn turns a plugin on or off: for you
// ("user") when it's yours and the project's settings don't name it,
// else the project's local settings ("local"), which win over the shared
// ones (Claude's own `--scope` guess changed a shared file, seen).
func (Claude) PluginScope(folder string, p model.Plugin) string {
	if p.Scope != "user" {
		return "local"
	}
	for _, f := range settingsFiles(folder)[:2] {
		if _, ok := f.EnabledPlugins[p.ID]; ok {
			return "local"
		}
	}
	return "user"
}

// SetPluginOn turns an installed plugin on or off, and with it its
// skills, commands, agents and servers: for you through `claude plugin
// enable` or `disable` (run outside the folder); for the project by its
// enabledPlugins entry in the project's local settings, the key Claude's
// own advice names (only that entry changes).
func (Claude) SetPluginOn(ctx context.Context, folder, id string, on bool) error {
	p, err := installed(ctx, folder, id)
	if err != nil {
		return err
	}
	if (Claude{}).PluginScope(folder, p.Plugin) == "local" {
		return claudemcp.EditLocal(ctx, folder, func(settings map[string]json.RawMessage) error {
			enabled := map[string]json.RawMessage{}
			if raw, ok := settings["enabledPlugins"]; ok && string(raw) != "null" && json.Unmarshal(raw, &enabled) != nil {
				return errors.New("enabledPlugins isn't a map")
			}
			enabled[id], _ = json.Marshal(on)
			b, err := json.Marshal(enabled)
			settings["enabledPlugins"] = b
			return err
		})
	}
	verb := map[bool]string{true: "enable", false: "disable"}[on]
	out, err := claudePlugin(ctx, verb, "--json", "--scope", "user", "--", id)
	var result struct {
		Done bool `json:"alreadyInGoalState"`
	}
	if err != nil && json.Unmarshal(out, &result) == nil && result.Done {
		return nil
	}
	return err
}

// Uninstall uninstalls a plugin installed for you (`claude plugin
// uninstall --scope user`, run outside the folder). One installed for a
// project is uninstalled there, with /plugin in a terminal: Claude would
// have to run in the folder.
func (Claude) Uninstall(ctx context.Context, folder, id string) error {
	p, err := installed(ctx, folder, id)
	if err != nil {
		return err
	}
	if p.Scope != "user" {
		return fmt.Errorf("%s is installed for this project; uninstall it with /plugin in a terminal there", id)
	}
	_, err = claudePlugin(ctx, "uninstall", "--json", "--scope", "user", "--", id)
	return err
}

// trashProgram moves a file to the Trash (macOS's).
var trashProgram = "/usr/bin/trash"

// Trash moves a skill's folder (or the link in its place) to the Trash
// (macOS's trash): only a folder right in your skills folder or one of
// folder's project's, holding a SKILL.md.
func (Claude) Trash(ctx context.Context, folder, path string) error {
	name := filepath.Base(path)
	roots := append([]string{userRoot()}, projectRoots(ctx, folder)...)
	if filepath.Clean(path) != path || strings.HasPrefix(name, ".") || !slices.Contains(roots, filepath.Dir(path)) {
		return fmt.Errorf("%s isn't a skill's folder", path)
	}
	if _, err := os.Stat(filepath.Join(path, "SKILL.md")); err != nil {
		return fmt.Errorf("%s isn't a skill's folder", path)
	}
	// A project's .claude and .claude/skills are the repository's: a link
	// there could take the Trash elsewhere. Only the skill's own folder
	// may be a link (the link itself goes).
	if root := filepath.Dir(path); root != userRoot() {
		for _, p := range []string{filepath.Dir(root), root} {
			if fi, err := os.Lstat(p); err != nil || fi.Mode()&os.ModeSymlink != 0 {
				return fmt.Errorf("%s is a symlink; not moving what's in it", p)
			}
		}
	}
	if out, err := exec.CommandContext(ctx, trashProgram, path).CombinedOutput(); err != nil { //nolint:gosec // an absolute path checked above
		return fmt.Errorf("moving %s to the Trash: %s", path, strings.TrimSpace(string(out)))
	}
	if _, err := os.Lstat(path); err == nil {
		return fmt.Errorf("%s is still there", path)
	}
	return nil
}
