package opencodeskills

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/skillfile"
	"github.com/afrase/nushi/internal/testcheck"
)

func skill(t *testing.T, root, dir string) {
	t.Helper()
	testcheck.Write(t, filepath.Join(root, dir, "SKILL.md"), "---\nname: Named Otherwise\ndescription: "+dir+"\n---\n")
}

func listed(skills []model.Skill) string {
	var out []string
	for _, s := range skills {
		out = append(out, fmt.Sprintf("%s %s %s", s.Source, s.Name, s.State))
	}
	return strings.Join(out, "|")
}

func deny(id string) string {
	return `{"action": "skill.use", "resource": "` + id + `", "effect": "deny"}`
}

// setup is a home folder with opencode's config in it, and a repository
// below it with a deeper folder: the walk up from there passes the home
// folder, whose own .agents and .claude are yours.
func setup(t *testing.T) (config, top, deeper string) {
	t.Helper()
	home, _ := filepath.EvalSymlinks(t.TempDir())
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("OPENCODE_CONFIG_DIR", "")
	config = filepath.Join(home, ".config", "opencode")
	top = filepath.Join(home, "work", "repo")
	deeper = filepath.Join(top, "sub", "deeper")
	for _, d := range []string{filepath.Join(top, ".git"), deeper} {
		if err := os.MkdirAll(d, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	skill(t, filepath.Join(config, "skills"), "mine")
	skill(t, filepath.Join(config, "skills"), "both")
	skill(t, filepath.Join(config, "skills", "group"), "nested")
	skill(t, filepath.Join(config, "skills", ".hidden"), "unseen")
	skill(t, filepath.Join(config, "skills", "node_modules"), "unseen")
	skill(t, filepath.Join(config, "skills", "mine"), "below") // nothing below a skill is read
	testcheck.Write(t, filepath.Join(config, "skills", "loose.md"), "A lone file.\n")
	testcheck.Write(t, filepath.Join(config, "skills", "empty", "SKILL.md"), "")
	skill(t, filepath.Join(config, "skill"), "mine") // skills has it
	skill(t, filepath.Join(config, "skill"), "older")
	skill(t, filepath.Join(home, ".agents", "skills"), "everyday")
	skill(t, filepath.Join(home, ".agents", "skills"), "both")
	skill(t, filepath.Join(home, ".claude", "skills"), "claudeuser")
	skill(t, filepath.Join(top, ".opencode", "skills"), "proj")
	skill(t, filepath.Join(top, ".opencode", "skills"), "both")
	skill(t, filepath.Join(top, ".claude", "skills"), "claudeproj")
	skill(t, filepath.Join(top, ".claude", "skills"), "release") // .agents has it
	skill(t, filepath.Join(top, "sub", ".agents", "skills"), "release")
	skill(t, filepath.Join(top, ".agents", "skills"), "release")        // the nearer one wins
	skill(t, filepath.Join(home, "work", ".agents", "skills"), "above") // above the repository: read too
	return config, top, deeper
}

// opencode's skills, one an id, from the folder up to /; a project's
// linked places left out; off by the global config's policies.
func TestList(t *testing.T) {
	config, top, deeper := setup(t)
	elsewhere := t.TempDir()
	skill(t, filepath.Join(elsewhere, "skills"), "victim")
	if err := os.Symlink(elsewhere, filepath.Join(deeper, ".agents")); err != nil {
		t.Fatal(err)
	}
	jsonc := filepath.Join(config, "opencode.jsonc")
	testcheck.Write(t, filepath.Join(config, "opencode.json"), `{"policies": [`+deny("mine")+`, `+deny("proj")+`,
		{"action": "skill.use", "resource": "proj", "effect": "allow"}, {"action": "tool.use", "resource": "*", "effect": "deny"}]}`)
	testcheck.Write(t, jsonc, "{\n  // the later document\n  \"policies\": [\n    "+deny("claude*")+",\n    "+deny("proj")+",\n    "+deny("everyday")+",\n  ],\n}\n")
	ctx := context.Background()
	l, err := OpenCode{}.List(ctx, deeper)
	if err != nil {
		t.Fatal(err)
	}
	want := "project both on|project proj on|user nested on|user loose on|user mine off|user older on|" +
		"shared release on|shared above on|shared everyday off|project claudeproj off|user claudeuser off"
	if g := listed(l.Skills); g != want {
		t.Errorf("skills:\n%s\nwant\n%s", g, want)
	}
	if !l.ReadsShared || l.NoSwitch != "" {
		t.Errorf("reads shared %v, no switch %q", l.ReadsShared, l.NoSwitch)
	}
	for _, s := range l.Skills {
		switch {
		case s.Name == "claudeuser" && s.SetIn != jsonc, (s.Name == "mine" || s.Name == "everyday") && s.SetIn != "":
			t.Errorf("%s set in %q", s.Name, s.SetIn)
		case s.Name == "release" && s.Path != filepath.Join(top, "sub", ".agents", "skills", "release"),
			s.Name == "nested" && s.Path != filepath.Join(config, "skills", "group", "nested"):
			t.Errorf("%s at %s", s.Name, s.Path)
		case s.Name == "everyday" && !s.Everywhere, s.Name == "nested" && s.Description != "nested":
			t.Errorf("%+v", s)
		}
	}
	// In the config folder itself opencode reads no project.
	l, _ = OpenCode{}.List(ctx, config)
	if g := listed(l.Skills); strings.Contains(g, "project") || !strings.Contains(g, "user mine off") {
		t.Errorf("in the config folder: %s", g)
	}
}

// opencode's wildcard: * any text, ? one character, a trailing " *"
// optional; an old integration.use of skill:<id> counts.
func TestPolicies(t *testing.T) {
	for _, c := range []struct {
		id, pattern string
		want        bool
	}{
		{"pdf", "pdf", true}, {"pdf", "PDF", false}, {"pdf", "*", true}, {"pdf", "p?f", true}, {"pdf", "p?", false},
		{"a.b", "a?b", true}, {"axb", "a.b", false}, {"git", "git *", true}, {"git x", "git *", true}, {"gitx", "git *", false},
	} {
		if got := match(c.id, c.pattern); got != c.want {
			t.Errorf("match(%q, %q) = %v", c.id, c.pattern, got)
		}
	}
	config, _, deeper := setup(t)
	testcheck.Write(t, filepath.Join(config, "opencode.json"), `{"experimental": {"policies": [`+deny("older")+`]},
		"policies": [{"action": "integration.use", "resource": "skill:proj", "effect": "deny"}, {"resource": "mine", "effect": "deny"}, "deny"]}`)
	l, _ := OpenCode{}.List(context.Background(), deeper)
	for _, s := range l.Skills {
		if off := s.Name == "older" || s.Name == "proj"; off != (s.State == "off") || off != (s.SetIn != "") {
			t.Errorf("%s is %s, set in %q", s.Name, s.State, s.SetIn)
		}
	}
}

// Only a folder right in the config's skills or a .opencode/skills goes
// to the Trash.
func TestTrash(t *testing.T) {
	config, top, deeper := setup(t)
	bin := t.TempDir()
	testcheck.Write(t, filepath.Join(bin, "trash"), "#!/bin/sh\nrm -r \"$1\"\n")
	testcheck.NoErr(t, os.Chmod(filepath.Join(bin, "trash"), 0o700))
	old := skillfile.TrashProgram
	skillfile.TrashProgram = []string{filepath.Join(bin, "trash")}
	t.Cleanup(func() { skillfile.TrashProgram = old })
	ctx := context.Background()
	for _, p := range []string{filepath.Join(config, "skills", "mine"), filepath.Join(top, ".opencode", "skills", "proj")} {
		if err := (OpenCode{}).Trash(ctx, deeper, p); err != nil {
			t.Errorf("%s: %v", p, err)
		}
	}
	for _, p := range []string{filepath.Join(config, "skills", "group", "nested"), filepath.Join(config, "skills", "loose.md"),
		filepath.Join(top, ".agents", "skills", "release"), filepath.Join(top, ".claude", "skills", "claudeproj")} {
		if err := (OpenCode{}).Trash(ctx, deeper, p); err == nil {
			t.Errorf("%s went to the Trash", p)
		}
	}
	l, _ := OpenCode{}.List(ctx, deeper)
	if g := listed(l.Skills); strings.Contains(g, "project proj on") || !strings.Contains(g, "user mine on|user older") {
		t.Errorf("after: %s", g) // the config's skill folder's mine shows once skills' is gone
	}
}
