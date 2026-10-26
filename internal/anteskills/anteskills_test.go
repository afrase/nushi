package anteskills

import (
	"context"
	"fmt"
	"os"
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

func skill(t *testing.T, root, dir, name string) {
	t.Helper()
	text := "---\ndescription: " + dir + "\n"
	if name != "" {
		text += "name: " + name + "\n"
	}
	write(t, filepath.Join(root, dir, "SKILL.md"), text+"---\n")
}

func listed(skills []model.Skill) string {
	var out []string
	for _, s := range skills {
		out = append(out, fmt.Sprintf("%s %s %s", s.Source, s.Name, s.State))
	}
	return strings.Join(out, "|")
}

// Ante's skills: the folder's own (no walk up), .ante over .agents over
// .claude, the project's over yours; exclude_skills by name, a project's
// adding to yours; linked project roots left out.
func TestListAndSwitch(t *testing.T) {
	anteHome, _ := filepath.EvalSymlinks(t.TempDir())
	home, _ := filepath.EvalSymlinks(t.TempDir())
	t.Setenv("ANTE_HOME", anteHome)
	t.Setenv("HOME", home)
	top, _ := filepath.EvalSymlinks(t.TempDir())
	folder := filepath.Join(top, "sub")
	skill(t, filepath.Join(anteHome, "skills"), "mine", "")
	skill(t, filepath.Join(anteHome, ".system", "skills"), "resume-claude", "")
	skill(t, filepath.Join(home, ".agents", "skills"), "everyday", "")
	skill(t, filepath.Join(home, ".claude", "skills"), "claudes", "")
	skill(t, filepath.Join(folder, ".ante", "skills"), "dir-a", "dup")
	skill(t, filepath.Join(folder, ".agents", "skills"), "dup", "")
	skill(t, filepath.Join(folder, ".agents", "skills"), "release", "")
	skill(t, filepath.Join(folder, ".claude", "skills"), "proj", "")
	skill(t, filepath.Join(top, ".agents", "skills"), "above", "") // not read: no walk up
	elsewhere := t.TempDir()
	skill(t, filepath.Join(elsewhere, "skills"), "victim", "")
	if err := os.MkdirAll(filepath.Join(folder, ".ante"), 0o700); err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(top, ".ante", "settings.json"), `{"exclude_skills": ["proj"]}`)
	ctx := context.Background()
	l, err := Ante{}.List(ctx, folder)
	if err != nil {
		t.Fatal(err)
	}
	want := "project dup on|shared release on|project proj off|user mine on|shared everyday on|user claudes on|system resume-claude on"
	if g := listed(l.Skills); g != want {
		t.Errorf("skills:\n%s\nwant\n%s", g, want)
	}
	if err := (Ante{}).SetSkillOn(ctx, folder, "project", "proj", true); err == nil || !strings.Contains(err.Error(), "change it there") {
		t.Errorf("set in the project's settings: %v", err)
	}
	write(t, filepath.Join(anteHome, "settings.json"), `{"model": "x"}`)
	if err := (Ante{}).SetSkillOn(ctx, folder, "shared", "release", false); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(filepath.Join(anteHome, "settings.json"))
	if string(b) != "{\n  \"exclude_skills\": [\n    \"release\"\n  ],\n  \"model\": \"x\"\n}\n" {
		t.Errorf("settings: %s", b)
	}
	if sh := (Ante{}).Shared(ctx, folder); listed(sh) != "shared release off|shared everyday on" {
		t.Errorf("shared: %s", listed(sh))
	}
	if err := (Ante{}).SetSkillOn(ctx, folder, "shared", "release", true); err != nil {
		t.Fatal(err)
	}
	// A linked .agents is left out.
	if err := os.RemoveAll(filepath.Join(folder, ".agents")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(elsewhere, filepath.Join(folder, ".agents")); err != nil {
		t.Fatal(err)
	}
	if l, _ := (Ante{}).List(ctx, folder); strings.Contains(listed(l.Skills), "victim") {
		t.Errorf("listed through a link: %s", listed(l.Skills))
	}
}
