package codexskills

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func read(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

// A switch changes only the skill's [[skills.config]] entries in Codex's
// config.toml: comments, order and the rest kept; off adds an entry, on
// takes it away (or sets enabled where the entry has more in it).
func TestSetSkillOnKeepsTheRest(t *testing.T) {
	codexHome, _, top, deeper := setup(t)
	skill(t, filepath.Join(top, ".agents", "skills"), "release", "")
	skill(t, filepath.Join(top, ".agents", "skills"), "other", "")
	file := filepath.Join(top, ".agents", "skills", "release", "SKILL.md")
	cfg := filepath.Join(codexHome, "config.toml")
	start := "# My Codex\nmodel = \"x\" # the model\n\n[projects.\"/p\"]\ntrust_level = \"trusted\"\n\n# keep other off\n[[skills.config]]\npath = \"" +
		filepath.Join(top, ".agents", "skills", "other", "SKILL.md") + "\"\nenabled = false\n"
	write(t, cfg, start)
	if err := os.Chmod(cfg, 0o640); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if err := (Codex{}).SetSkillOn(ctx, deeper, "shared", "release", false); err != nil {
		t.Fatal(err)
	}
	want := start + "\n[[skills.config]]\npath = \"" + file + "\"\nenabled = false\n"
	if got := read(t, cfg); got != want {
		t.Errorf("off:\n%s\nwant\n%s", got, want)
	}
	if fi, _ := os.Stat(cfg); fi.Mode().Perm() != 0o640 {
		t.Errorf("mode %v", fi.Mode())
	}
	if err := (Codex{}).SetSkillOn(ctx, deeper, "shared", "release", true); err != nil {
		t.Fatal(err)
	}
	if got := read(t, cfg); got != start+"\n" {
		t.Errorf("on again:\n%q\nwant\n%q", got, start+"\n")
	}

	// An entry with a comment in it keeps it: enabled flips.
	write(t, cfg, "[[skills.config]]\n# why\npath = \""+file+"\"\nenabled = false # for now\n[x]\ny = 1\n")
	if err := (Codex{}).SetSkillOn(ctx, deeper, "shared", "release", true); err != nil {
		t.Fatal(err)
	}
	if got := read(t, cfg); got != "[[skills.config]]\n# why\npath = \""+file+"\"\nenabled = true # for now\n[x]\ny = 1\n" {
		t.Errorf("an entry with a comment:\n%s", got)
	}

	// A name entry keeps it off: on adds a path entry after it.
	write(t, cfg, "[[skills.config]]\nname = \"release\"\nenabled = false\n")
	if err := (Codex{}).SetSkillOn(ctx, deeper, "shared", "release", true); err != nil {
		t.Fatal(err)
	}
	if l, _ := (Codex{}).List(ctx, deeper); !strings.Contains(listed(l.Skills), "shared release on") {
		t.Errorf("still off by name: %s", read(t, cfg))
	}

	// No config.toml yet: one is made.
	if err := os.Remove(cfg); err != nil {
		t.Fatal(err)
	}
	if err := (Codex{}).SetSkillOn(ctx, deeper, "shared", "release", false); err != nil {
		t.Fatal(err)
	}
	if got := read(t, cfg); got != "[[skills.config]]\npath = \""+file+"\"\nenabled = false\n" {
		t.Errorf("a new file:\n%s", got)
	}
}

// What Nushi can't edit safely is refused, the file untouched.
func TestSetSkillOnRefusesWhatItCantEdit(t *testing.T) {
	codexHome, _, top, deeper := setup(t)
	skill(t, filepath.Join(top, ".agents", "skills"), "release", "")
	file := filepath.Join(top, ".agents", "skills", "release", "SKILL.md")
	cfg := filepath.Join(codexHome, "config.toml")
	for _, c := range []struct {
		text string
		on   bool
	}{
		{"[skills]\nconfig = [{ name = \"x\", enabled = false }]\n", false}, // an inline array: [[skills.config]] can't follow
		{"skills = { config = [] }\n", false},
		{"[[skills.config]]\npath = '''\n" + file + "'''\nenabled = false\n", true}, // a value Nushi doesn't read
		{"not toml = = \n", true},
	} {
		text := c.text
		write(t, cfg, text)
		err := (Codex{}).SetSkillOn(context.Background(), deeper, "shared", "release", c.on)
		if err == nil || !strings.Contains(err.Error(), "change it in config.toml") {
			t.Errorf("%q: %v", text, err)
		}
		if got := read(t, cfg); got != text {
			t.Errorf("%q changed:\n%s", text, got)
		}
	}
	if err := (Codex{}).SetSkillOn(context.Background(), deeper, "shared", "nothere", false); err == nil {
		t.Error("a skill Codex doesn't list: not refused")
	}
}
