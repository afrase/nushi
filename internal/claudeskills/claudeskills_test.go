package claudeskills

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

func write(t *testing.T, path, text string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(text), 0o600); err != nil {
		t.Fatal(err)
	}
}

// fakeClaude puts a claude first on PATH that records its arguments (a
// line each, a call a paragraph) in dir/args and prints $FAKE_OUT, exiting
// with $FAKE_EXIT.
func fakeClaude(t *testing.T) (dir string) {
	t.Helper()
	dir = t.TempDir()
	write(t, filepath.Join(dir, "claude"), "#!/bin/sh\n{ printf '%s\\n' \"$@\"; echo; } >> \""+dir+"/args\"\nprintf '%s' \"$FAKE_OUT\"\nexit ${FAKE_EXIT:-0}\n")
	if err := os.Chmod(filepath.Join(dir, "claude"), 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+":"+os.Getenv("PATH"))
	return dir
}

// skill writes a SKILL.md in root/name.
func skill(t *testing.T, root, name, text string) {
	t.Helper()
	write(t, filepath.Join(root, name, "SKILL.md"), text)
}

// repo is a git repository in a temp folder (real path), and its sub/deeper.
func repo(t *testing.T) (top, deeper string) {
	t.Helper()
	top, _ = filepath.EvalSymlinks(t.TempDir())
	if out, err := exec.Command("git", "-C", top, "init", "-q").CombinedOutput(); err != nil {
		t.Fatal(string(out))
	}
	deeper = filepath.Join(top, "sub", "deeper")
	if err := os.MkdirAll(deeper, 0o700); err != nil {
		t.Fatal(err)
	}
	return top, deeper
}

func names(skills []model.Skill) []string {
	var out []string
	for _, s := range skills {
		out = append(out, fmt.Sprintf("%s %s %s %d", s.Source, s.Name, s.State, s.Tokens))
	}
	return out
}

// Skills come from your folder, the project's folders up to the
// repository's top (the nearest winning a name), and plugins; settings
// decide which are listed, local over shared over yours.
func TestListReadsEachSource(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", cfg)
	top, deeper := repo(t)
	skill(t, filepath.Join(cfg, "skills"), "mine", "---\nname: other\ndescription: A user skill in the config dir. It does things.\n---\nbody\n")
	skill(t, filepath.Join(cfg, "skills"), "quiet", "---\ndescription: Off for me\n---\n")
	skill(t, filepath.Join(top, ".claude", "skills"), "projskill", "---\ndescription: A project skill\nwhen_to_use: when testing\n---\nb\n")
	skill(t, filepath.Join(top, ".claude", "skills"), "noname", "no front matter here\n")
	skill(t, filepath.Join(top, ".claude", "skills"), "dup", "---\ndescription: far\n---\n")
	skill(t, filepath.Join(top, ".claude", "skills"), "manual", "---\ndescription: dir differs\ndisable-model-invocation: true\n---\n")
	skill(t, filepath.Join(top, "sub", ".claude", "skills"), "dup", "---\ndescription: near\n---\n")
	skill(t, filepath.Join(filepath.Dir(top), ".claude", "skills"), "above", "---\ndescription: above the repo\n---\n") // not read
	write(t, filepath.Join(top, ".claude", "skills", "notadir"), "x")
	write(t, filepath.Join(top, ".claude", "skills", "empty", "README.md"), "no SKILL.md")
	write(t, filepath.Join(cfg, "settings.json"), `{"skillOverrides":{"quiet":"off","projskill":"on","noname":"off"},"other":1}`)
	write(t, filepath.Join(top, ".claude", "settings.local.json"), `{"skillOverrides":{"projskill":"off","quiet":"name-only"}}`)
	write(t, filepath.Join(top, ".claude", "settings.json"), `{"skillOverrides":"not a map","disableBundledSkills":true}`)

	plugin := t.TempDir()
	skill(t, filepath.Join(plugin, "skills"), "hello", "---\ndescription: Says hello when the user greets. Use for greetings.\n---\n")
	skill(t, filepath.Join(plugin, "extra"), "more", "---\ndescription: from the manifest's folder\n---\n")
	write(t, filepath.Join(plugin, "commands", "democmd.md"), "x")
	write(t, filepath.Join(plugin, "agents", "a.md"), "x")
	write(t, filepath.Join(plugin, "agents", "b.md"), "x")
	write(t, filepath.Join(plugin, ".claude-plugin", "plugin.json"), `{"name":"demo","description":"A demo plugin","skills":["./extra","../outside"]}`)
	fakeClaude(t)
	t.Setenv("FAKE_OUT", `[{"id":"demo@mk","version":"1.0.0","scope":"user","enabled":false,"installPath":"`+plugin+`",
		"mcpServers":{"pms":{"command":"x"}},"projectEnabled":false,"somethingNew":{"a":[1]}},{"id":"","installPath":"/x"}]`)

	got, err := Claude{}.List(context.Background(), deeper)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		"user mine on 18", "user quiet name-only 5",
		"project dup on 2", "project manual user-invocable-only 6", "project noname off 9", "project projskill off 13",
		"plugin demo:hello off 20", "plugin demo:more off 11",
	}
	if g := names(got.Skills); strings.Join(g, "|") != strings.Join(want, "|") {
		t.Errorf("skills:\n%q\nwant\n%q", g, want)
	}
	byName := map[string]model.Skill{}
	for _, s := range got.Skills {
		byName[s.Name] = s
	}
	if s := byName["quiet"]; s.SetIn != filepath.Join(top, ".claude", "settings.local.json") {
		t.Errorf("a user skill the project's settings decide: %+v", s)
	}
	if s := byName["projskill"]; s.SetIn != "" || s.Path != filepath.Join(top, ".claude", "skills", "projskill") {
		t.Errorf("a project skill: %+v", s)
	}
	if s := byName["dup"]; s.Description != "near" {
		t.Errorf("the nearer of two: %+v", s)
	}
	if s := byName["noname"]; s.Description != "no front matter here" {
		t.Errorf("a skill without front matter: %+v", s)
	}
	if len(got.Plugins) != 1 || got.Plugins[0] != (model.Plugin{ID: "demo@mk", Name: "demo", Version: "1.0.0", Description: "A demo plugin",
		Scope: "user", Path: plugin, Skills: 2, Commands: 1, Agents: 2, MCPServers: 1}) {
		t.Errorf("plugins: %+v", got.Plugins)
	}
	if !got.BuiltInOff || got.BuiltInSetIn != filepath.Join(top, ".claude", "settings.json") {
		t.Errorf("built in: %v %q", got.BuiltInOff, got.BuiltInSetIn)
	}
}

// A plugin list Claude couldn't give leaves the rest listed.
func TestListWithoutPlugins(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", cfg)
	skill(t, filepath.Join(cfg, "skills"), "mine", "---\ndescription: d\n---\n")
	fakeClaude(t)
	t.Setenv("FAKE_OUT", "not json")
	got, err := Claude{}.List(context.Background(), t.TempDir())
	if err != nil || len(got.Skills) != 1 || got.PluginsError == "" {
		t.Errorf("%+v, %v", got, err)
	}
}
