package piskills

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/pi"
	"github.com/afrase/nushi/internal/testcheck"
)

var skills = Skills{Flavor: pi.Pi}

func skill(t *testing.T, root, dir string) {
	t.Helper()
	testcheck.Write(t, filepath.Join(root, dir, "SKILL.md"), "---\ndescription: "+dir+" does things\n---\n")
}

func listed(skills []model.Skill) string {
	var out []string
	for _, s := range skills {
		out = append(out, fmt.Sprintf("%s %s %s", s.Source, s.Name, s.State))
	}
	return strings.Join(out, "|")
}

// sharedOf is a list's shared skills, as the skills feature takes them.
func sharedOf(l model.Skills) []model.Skill {
	return slices.DeleteFunc(l.Skills, func(s model.Skill) bool { return s.Source != "shared" })
}

// setup gives Pi a throwaway agent folder and HOME, and a repository
// with a folder two levels down (real paths).
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
	skill(t, filepath.Join(deeper, ".pi", "skills"), "pigonly")
	skill(t, filepath.Join(top, ".agents", "skills"), "release")
	skill(t, filepath.Join(top, ".agents", "skills"), "mine")      // the project's wins the name
	skill(t, filepath.Join(above, ".agents", "skills"), "above")   // above the repository: not read
	skill(t, filepath.Join(top, "sub", ".pi", "skills"), "notcwd") // .pi only in the folder itself
	testcheck.Write(t, filepath.Join(top, ".agents", "skills", "nodesc", "SKILL.md"), "plain text\n")
	return agent, top, deeper
}

// The project's skills load only once Pi trusts the folder: until then
// they show as "untrusted", and yours keep their names.
func TestTrust(t *testing.T) {
	agent, top, deeper := setup(t)
	ctx := context.Background()
	l, _ := skills.List(ctx, deeper)
	want := "project pigonly untrusted|shared mine untrusted|shared release untrusted|user mine on|shared everyday on"
	if g := listed(l.Skills); g != want {
		t.Errorf("untrusted:\n%s\nwant\n%s", g, want)
	}
	if err := skills.SetSkillOn(ctx, deeper, "shared", "release", false); err == nil {
		t.Error("a switch for a skill Pi doesn't load")
	}
	// The repository's root trusted covers the folder; its own false wins.
	testcheck.Write(t, filepath.Join(agent, "trust.json"), `{"`+top+`": true}`)
	l, _ = skills.List(ctx, deeper)
	want = "project pigonly on|shared mine on|shared release on|shared everyday on"
	if g := listed(l.Skills); g != want {
		t.Errorf("trusted:\n%s\nwant\n%s", g, want)
	}
	testcheck.Write(t, filepath.Join(agent, "trust.json"), `{"`+top+`": true, "`+deeper+`": false}`)
	if l, _ := skills.List(ctx, deeper); !strings.Contains(listed(l.Skills), "release untrusted") {
		t.Errorf("a nearer false: %s", listed(l.Skills))
	}
	testcheck.Write(t, filepath.Join(agent, "trust.json"), `{}`)
	testcheck.Write(t, filepath.Join(agent, "settings.json"), `{"defaultProjectTrust": "always"}`)
	if l, _ := skills.List(ctx, deeper); !strings.Contains(listed(l.Skills), "release on") {
		t.Errorf("trusted by default: %s", listed(l.Skills))
	}
	if l, _ := skills.List(ctx, deeper); len(sharedOf(l)) != 3 {
		t.Errorf("shared: %s", listed(sharedOf(l)))
	}
}

// A linked .agents or .agents/skills is left out.
func TestLinkedRootsLeftOut(t *testing.T) {
	agent, top, deeper := setup(t)
	testcheck.Write(t, filepath.Join(agent, "trust.json"), `{"`+top+`": true}`)
	elsewhere := t.TempDir()
	skill(t, filepath.Join(elsewhere, "skills"), "victim")
	if err := os.Symlink(elsewhere, filepath.Join(top, "sub", ".agents")); err != nil {
		t.Fatal(err)
	}
	if l, _ := skills.List(context.Background(), deeper); strings.Contains(listed(l.Skills), "victim") {
		t.Errorf("listed through a link: %s", listed(l.Skills))
	}
}

// Off is a "-<folder>" entry in the scope's settings: the project's for a
// project's shared skill, yours for yours; a "!" pattern decides where it
// matches, and the switch says so.
func TestSetSkillOn(t *testing.T) {
	agent, top, deeper := setup(t)
	testcheck.Write(t, filepath.Join(agent, "trust.json"), `{"`+top+`": true}`)
	testcheck.Write(t, filepath.Join(agent, "settings.json"), `{"theme": "dark", "skills": ["!every*"]}`)
	ctx := context.Background()
	if err := skills.SetSkillOn(ctx, deeper, "shared", "release", false); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(filepath.Join(deeper, ".pi", "settings.json"))
	if want := "{\n  \"skills\": [\"-skills/release\"]\n}\n"; string(b) != want {
		t.Errorf("project settings:\n%s", b)
	}
	l, _ := skills.List(ctx, deeper)
	if g := listed(l.Skills); !strings.Contains(g, "shared release off") || !strings.Contains(g, "shared everyday off") {
		t.Errorf("after: %s", g)
	}
	if err := skills.SetSkillOn(ctx, deeper, "shared", "everyday", true); err == nil || !strings.Contains(err.Error(), "change it there") {
		t.Errorf("a pattern decides: %v", err)
	}
	if err := skills.SetSkillOn(ctx, deeper, "shared", "release", true); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(deeper, ".pi", "settings.json")); string(b) != "{\n  \"skills\": []\n}\n" {
		t.Errorf("on again: %s", b)
	}

	// A project file of its own shape: only the skills value changes, every
	// other byte kept; an old absolute entry goes; no path of yours goes in.
	own := "{\"theme\":\"light\",   \"skills\" : [\"!old*\", \"-" + filepath.Join(top, ".agents", "skills", "release") + "\"],\n\t\"z\": {\"a\": 1}\n}"
	testcheck.Write(t, filepath.Join(deeper, ".pi", "settings.json"), own)
	if err := skills.SetSkillOn(ctx, deeper, "shared", "release", true); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(deeper, ".pi", "settings.json")); string(b) != "{\"theme\":\"light\",   \"skills\" : [\"!old*\"],\n\t\"z\": {\"a\": 1}\n}" {
		t.Errorf("kept:\n%s", b)
	}
	testcheck.Write(t, filepath.Join(deeper, ".pi", "settings.json"), "{\"theme\": \"light\"}")
	if err := skills.SetSkillOn(ctx, deeper, "shared", "release", false); err != nil {
		t.Fatal(err)
	}
	b, _ = os.ReadFile(filepath.Join(deeper, ".pi", "settings.json"))
	if string(b) != "{\"theme\": \"light\",\n  \"skills\": [\"-skills/release\"]}" || strings.Contains(string(b), top) {
		t.Errorf("added:\n%s", b)
	}
	for _, bad := range []string{"{\"skills\": [], \"skills\": []}", "[1]", "{\"skills\": \"x\"}"} {
		testcheck.Write(t, filepath.Join(deeper, ".pi", "settings.json"), bad)
		if err := skills.SetSkillOn(ctx, deeper, "shared", "release", false); err == nil {
			t.Errorf("%s: not refused", bad)
		}
		if b, _ := os.ReadFile(filepath.Join(deeper, ".pi", "settings.json")); string(b) != bad {
			t.Errorf("%s changed: %s", bad, b)
		}
	}
	if err := os.Remove(filepath.Join(deeper, ".pi", "settings.json")); err != nil {
		t.Fatal(err)
	}

	// A linked .pi is refused.
	elsewhere := t.TempDir()
	if err := os.RemoveAll(filepath.Join(deeper, ".pi")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(elsewhere, filepath.Join(deeper, ".pi")); err != nil {
		t.Fatal(err)
	}
	if err := skills.SetSkillOn(ctx, deeper, "shared", "release", false); err == nil {
		t.Error("wrote through a linked .pi")
	}
}

// PiG reads the same rules from its own folders and variable.
func TestPiGHasItsOwnFolders(t *testing.T) {
	agent, home, repo := t.TempDir(), t.TempDir(), git.RealPath(t.TempDir())
	t.Setenv("PIG_CODING_AGENT_DIR", agent)
	t.Setenv("HOME", home)
	skill(t, filepath.Join(agent, "skills"), "mine")
	skill(t, filepath.Join(repo, ".pig", "skills"), "theirs")
	skill(t, filepath.Join(repo, ".pi", "skills"), "other")
	p := Skills{Flavor: pi.PiG}
	ctx := context.Background()
	l, err := p.List(ctx, repo)
	if err != nil {
		t.Fatal(err)
	}
	if got, want := listed(l.Skills), "project theirs untrusted|user mine on"; got != want {
		t.Errorf("skills = %q, want %q", got, want)
	}
	if err := p.SetSkillOn(ctx, repo, "project", "theirs", false); err == nil || !strings.Contains(err.Error(), "/trust in pig") {
		t.Errorf("switching an untrusted skill: %v", err)
	}
	testcheck.Write(t, filepath.Join(agent, "trust.json"), `{"`+repo+`": true}`)
	if err := p.SetSkillOn(ctx, repo, "project", "theirs", false); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(filepath.Join(repo, ".pig", "settings.json"))
	if err != nil || !strings.Contains(string(b), "-skills/theirs") {
		t.Errorf(".pig/settings.json = %s, %v", b, err)
	}
}
