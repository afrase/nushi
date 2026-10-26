package ompskills

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

func skill(t *testing.T, root, dir string) {
	t.Helper()
	write(t, filepath.Join(root, dir, "SKILL.md"), "---\ndescription: "+dir+"\n---\n")
}

func listed(skills []model.Skill) string {
	var out []string
	for _, s := range skills {
		out = append(out, fmt.Sprintf("%s %s %s", s.Source, s.Name, s.State))
	}
	return strings.Join(out, "|")
}

func setup(t *testing.T) (agent, top, deeper string) {
	t.Helper()
	agent, _ = filepath.EvalSymlinks(t.TempDir())
	home, _ := filepath.EvalSymlinks(t.TempDir())
	t.Setenv("PI_CODING_AGENT_DIR", agent)
	t.Setenv("HOME", home)
	above, _ := filepath.EvalSymlinks(t.TempDir())
	top = filepath.Join(above, "repo")
	deeper = filepath.Join(top, "sub", "deeper")
	for _, d := range []string{filepath.Join(top, ".git"), deeper} {
		if err := os.MkdirAll(d, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	skill(t, filepath.Join(agent, "skills"), "mine")
	skill(t, filepath.Join(home, ".agents", "skills"), "everyday")
	skill(t, filepath.Join(home, ".claude", "skills"), "claudeuser") // only with enableClaudeUser
	skill(t, filepath.Join(top, ".omp", "skills"), "ompproj")
	skill(t, filepath.Join(top, ".claude", "skills"), "claudeproj")
	skill(t, filepath.Join(top, "sub", ".agents", "skills"), "release")
	skill(t, filepath.Join(top, ".agents", "skills"), "release") // kept twice: omp renames one
	skill(t, filepath.Join(above, ".agents", "skills"), "above") // above the repository: not read
	write(t, filepath.Join(top, ".agents", "skills", "plain", "SKILL.md"), "no front matter\n")
	write(t, filepath.Join(top, ".omp", "skills", "nodesc", "SKILL.md"), "no front matter\n") // .omp's need one
	return agent, top, deeper
}

// omp's skills, from the folder up to the repository's root; linked
// roots left out; off by name in your config.yml or the project's.
func TestList(t *testing.T) {
	agent, top, deeper := setup(t)
	elsewhere := t.TempDir()
	skill(t, filepath.Join(elsewhere, "skills"), "victim")
	if err := os.Symlink(elsewhere, filepath.Join(deeper, ".agents")); err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(agent, "config.yml"), "disabledExtensions:\n  - skill:mine\nskills:\n  ignoredSkills: [\"claude*\"]\n")
	write(t, filepath.Join(top, ".omp", "config.yml"), "disabledExtensions: [skill:plain]\n")
	ctx := context.Background()
	l, err := OMP{}.List(ctx, deeper)
	if err != nil {
		t.Fatal(err)
	}
	want := "project ompproj on|user mine off|project claudeproj off|shared release on|shared plain off|shared release on|shared everyday on"
	if g := listed(l.Skills); g != want {
		t.Errorf("skills:\n%s\nwant\n%s", g, want)
	}
	for _, s := range l.Skills {
		if s.Name == "plain" && s.SetIn != filepath.Join(top, ".omp", "config.yml") || s.Name == "mine" && s.SetIn != "" {
			t.Errorf("%s set in %q", s.Name, s.SetIn)
		}
	}
	if err := (OMP{}).SetSkillOn(ctx, deeper, "project", "claudeproj", true); err == nil || !strings.Contains(err.Error(), "change it there") {
		t.Errorf("a pattern decides: %v", err)
	}
}

// The switch edits your disabledExtensions only, comments kept; a file
// yaml.v3 wouldn't write back unchanged is refused.
func TestSetSkillOn(t *testing.T) {
	agent, _, deeper := setup(t)
	cfg := filepath.Join(agent, "config.yml")
	start := "# my omp\nmodelRoles:\n  default: fireworks/x # cheap\n"
	write(t, cfg, start)
	ctx := context.Background()
	if err := (OMP{}).SetSkillOn(ctx, deeper, "shared", "everyday", false); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(cfg)
	if want := start + "disabledExtensions:\n  - skill:everyday\n"; string(b) != want {
		t.Errorf("off:\n%s\nwant\n%s", b, want)
	}
	if err := (OMP{}).SetSkillOn(ctx, deeper, "shared", "everyday", true); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(cfg); string(b) != start {
		t.Errorf("on again:\n%s", b)
	}
	odd := "modelRoles:\n    default: x\n"
	write(t, cfg, odd)
	if err := (OMP{}).SetSkillOn(ctx, deeper, "shared", "everyday", false); err == nil || !strings.Contains(err.Error(), "change it in config.yml") {
		t.Errorf("four spaces: %v", err)
	}
	if b, _ := os.ReadFile(cfg); string(b) != odd {
		t.Errorf("changed: %s", b)
	}
}
