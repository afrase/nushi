package pigskills

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
	write(t, filepath.Join(root, dir, "SKILL.md"), "---\ndescription: "+dir+" does things\n---\n")
}

func listed(skills []model.Skill) string {
	var out []string
	for _, s := range skills {
		out = append(out, fmt.Sprintf("%s %s %s", s.Source, s.Name, s.State))
	}
	return strings.Join(out, "|")
}

// setup gives PiG a throwaway agent folder and HOME, and a repository
// with a folder two levels down (real paths).
func setup(t *testing.T) (agent, top, deeper string) {
	t.Helper()
	agent, _ = filepath.EvalSymlinks(t.TempDir())
	home, _ := filepath.EvalSymlinks(t.TempDir())
	t.Setenv("PIG_CODING_AGENT_DIR", agent)
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
	skill(t, filepath.Join(deeper, ".pig", "skills"), "pigonly")
	skill(t, filepath.Join(top, ".agents", "skills"), "release")
	skill(t, filepath.Join(top, ".agents", "skills"), "mine")       // the project's wins the name
	skill(t, filepath.Join(above, ".agents", "skills"), "above")    // above the repository: not read
	skill(t, filepath.Join(top, "sub", ".pig", "skills"), "notcwd") // .pig only in the folder itself
	write(t, filepath.Join(top, ".agents", "skills", "nodesc", "SKILL.md"), "plain text\n")
	return agent, top, deeper
}

// The project's skills load only once PiG trusts the folder: until then
// they show as "untrusted", and yours keep their names.
func TestTrust(t *testing.T) {
	agent, top, deeper := setup(t)
	ctx := context.Background()
	l, _ := PiG{}.List(ctx, deeper)
	want := "project pigonly untrusted|shared mine untrusted|shared release untrusted|user mine on|shared everyday on"
	if g := listed(l.Skills); g != want {
		t.Errorf("untrusted:\n%s\nwant\n%s", g, want)
	}
	if err := (PiG{}).SetSkillOn(ctx, deeper, "shared", "release", false); err == nil {
		t.Error("a switch for a skill PiG doesn't load")
	}
	// The repository's root trusted covers the folder; its own false wins.
	write(t, filepath.Join(agent, "trust.json"), `{"`+top+`": true}`)
	l, _ = PiG{}.List(ctx, deeper)
	want = "project pigonly on|shared mine on|shared release on|shared everyday on"
	if g := listed(l.Skills); g != want {
		t.Errorf("trusted:\n%s\nwant\n%s", g, want)
	}
	write(t, filepath.Join(agent, "trust.json"), `{"`+top+`": true, "`+deeper+`": false}`)
	if l, _ := (PiG{}).List(ctx, deeper); !strings.Contains(listed(l.Skills), "release untrusted") {
		t.Errorf("a nearer false: %s", listed(l.Skills))
	}
	write(t, filepath.Join(agent, "trust.json"), `{}`)
	write(t, filepath.Join(agent, "settings.json"), `{"defaultProjectTrust": "always"}`)
	if l, _ := (PiG{}).List(ctx, deeper); !strings.Contains(listed(l.Skills), "release on") {
		t.Errorf("trusted by default: %s", listed(l.Skills))
	}
	if sh := (PiG{}).Shared(ctx, deeper); len(sh) != 3 {
		t.Errorf("shared: %s", listed(sh))
	}
}

// A linked .agents or .agents/skills is left out.
func TestLinkedRootsLeftOut(t *testing.T) {
	agent, top, deeper := setup(t)
	write(t, filepath.Join(agent, "trust.json"), `{"`+top+`": true}`)
	elsewhere := t.TempDir()
	skill(t, filepath.Join(elsewhere, "skills"), "victim")
	if err := os.Symlink(elsewhere, filepath.Join(top, "sub", ".agents")); err != nil {
		t.Fatal(err)
	}
	if l, _ := (PiG{}).List(context.Background(), deeper); strings.Contains(listed(l.Skills), "victim") {
		t.Errorf("listed through a link: %s", listed(l.Skills))
	}
}

// Off is a "-<folder>" entry in the scope's settings: the project's for a
// project's shared skill, yours for yours; a "!" pattern decides where it
// matches, and the switch says so.
func TestSetSkillOn(t *testing.T) {
	agent, top, deeper := setup(t)
	write(t, filepath.Join(agent, "trust.json"), `{"`+top+`": true}`)
	write(t, filepath.Join(agent, "settings.json"), `{"theme": "dark", "skills": ["!every*"]}`)
	ctx := context.Background()
	if err := (PiG{}).SetSkillOn(ctx, deeper, "shared", "release", false); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(filepath.Join(deeper, ".pig", "settings.json"))
	if want := "{\n  \"skills\": [\n    \"-" + filepath.Join(top, ".agents", "skills", "release") + "\"\n  ]\n}\n"; string(b) != want {
		t.Errorf("project settings:\n%s", b)
	}
	l, _ := PiG{}.List(ctx, deeper)
	if g := listed(l.Skills); !strings.Contains(g, "shared release off") || !strings.Contains(g, "shared everyday off") {
		t.Errorf("after: %s", g)
	}
	if err := (PiG{}).SetSkillOn(ctx, deeper, "shared", "everyday", true); err == nil || !strings.Contains(err.Error(), "change it there") {
		t.Errorf("a pattern decides: %v", err)
	}
	if err := (PiG{}).SetSkillOn(ctx, deeper, "shared", "release", true); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(deeper, ".pig", "settings.json")); string(b) != "{}\n" {
		t.Errorf("on again: %s", b)
	}
	// A linked .pig is refused.
	elsewhere := t.TempDir()
	if err := os.RemoveAll(filepath.Join(deeper, ".pig")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(elsewhere, filepath.Join(deeper, ".pig")); err != nil {
		t.Fatal(err)
	}
	if err := (PiG{}).SetSkillOn(ctx, deeper, "shared", "release", false); err == nil {
		t.Error("wrote through a linked .pig")
	}
}
