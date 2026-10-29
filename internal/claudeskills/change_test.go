package claudeskills

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/skillfile"
	"github.com/afrase/nushi/internal/testcheck"
)

// calls are the fake's calls, each its arguments.
func calls(t *testing.T, dir string) [][]string {
	t.Helper()
	b, _ := os.ReadFile(filepath.Join(dir, "args"))
	var out [][]string
	for call := range strings.SplitSeq(strings.TrimSpace(string(b)), "\n\n") {
		if call != "" {
			out = append(out, strings.Split(call, "\n"))
		}
	}
	return out
}

func readJSON(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var v any
	if err := json.Unmarshal(b, &v); err != nil {
		t.Fatal(err)
	}
	out, _ := json.Marshal(v)
	return string(out)
}

// A skill's switch changes only skillOverrides, in your settings for
// yours and the project's local settings for a project's, keeping the
// rest and the file's mode, through a new file.
func TestSetSkillOnChangesOnlyItsKey(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", cfg)
	top, deeper := repo(t)
	skill(t, filepath.Join(cfg, "skills"), "mine", "---\ndescription: d\n---\n")
	skill(t, filepath.Join(top, ".claude", "skills"), "proj", "---\ndescription: d\n---\n")
	user := filepath.Join(cfg, "settings.json")
	testcheck.Write(t, user, `{"model":"opus","skillOverrides":{"proj":"off","other":"name-only"}}`)
	if err := os.Chmod(user, 0o640); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if err := (Claude{}).SetSkillOn(ctx, deeper, "user", "mine", false); err != nil {
		t.Fatal(err)
	}
	if got := readJSON(t, user); got != `{"model":"opus","skillOverrides":{"mine":"off","other":"name-only","proj":"off"}}` {
		t.Errorf("user settings: %s", got)
	}
	if fi, _ := os.Stat(user); fi.Mode().Perm() != 0o640 {
		t.Errorf("mode %v", fi.Mode())
	}
	if err := (Claude{}).SetSkillOn(ctx, deeper, "user", "mine", true); err != nil {
		t.Fatal(err)
	}
	if got := readJSON(t, user); got != `{"model":"opus","skillOverrides":{"other":"name-only","proj":"off"}}` {
		t.Errorf("on again: %s", got)
	}
	// A project skill: the local settings, which say "on" over yours.
	if err := (Claude{}).SetSkillOn(ctx, deeper, "project", "proj", true); err != nil {
		t.Fatal(err)
	}
	local := filepath.Join(top, ".claude", "settings.local.json")
	if got := readJSON(t, local); got != `{"skillOverrides":{"proj":"on"}}` {
		t.Errorf("local settings: %s", got)
	}
	exclude, _ := os.ReadFile(filepath.Join(top, ".git", "info", "exclude"))
	if !strings.Contains(string(exclude), "/.claude/settings.local.json") {
		t.Errorf("a new local settings file not kept out of git: %s", exclude)
	}
	entries, _ := os.ReadDir(filepath.Join(top, ".claude"))
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), ".nushi-") {
			t.Errorf("left behind: %s", e.Name())
		}
	}
	// Your skill the project's settings decide can't be changed for you.
	testcheck.Write(t, local, `{"skillOverrides":{"mine":"off"}}`)
	if err := (Claude{}).SetSkillOn(ctx, deeper, "user", "mine", true); err == nil || !strings.Contains(err.Error(), local) {
		t.Errorf("set in the project: %v", err)
	}
	for _, s := range [][2]string{{"user", "nope"}, {"project", "mine"}, {"plugin", "x"}} {
		if err := (Claude{}).SetSkillOn(ctx, deeper, s[0], s[1], false); err == nil {
			t.Errorf("%s %s: changed", s[0], s[1])
		}
	}
	testcheck.Write(t, user, `{"skillOverrides":["not a map"]}`)
	if err := (Claude{}).SetSkillOn(ctx, deeper, "user", "mine", false); err == nil {
		t.Error("a skillOverrides of another shape: changed")
	}
	// A link to your settings (dotfiles) is followed, not replaced.
	linked := filepath.Join(t.TempDir(), "settings.json")
	testcheck.Write(t, linked, `{}`)
	_ = os.Remove(user)
	if err := os.Symlink(linked, user); err != nil {
		t.Fatal(err)
	}
	if err := (Claude{}).SetBuiltInOn(ctx, deeper, false); err != nil {
		t.Fatal(err)
	}
	if fi, _ := os.Lstat(user); fi.Mode()&os.ModeSymlink == 0 || readJSON(t, linked) != `{"disableBundledSkills":true}` {
		t.Errorf("through the link: %s", readJSON(t, linked))
	}
}

// Plugins are listed and changed through claude plugin run in Claude's
// config folder, never the project's, with the id after --: for you unless
// the project's settings name the plugin, then by its enabledPlugins entry
// in the local settings. Another project's install isn't listed; one
// installed for this project isn't uninstalled from here.
func TestPluginsThroughTheCLI(t *testing.T) {
	cfg, _ := filepath.EvalSymlinks(t.TempDir())
	t.Setenv("CLAUDE_CONFIG_DIR", cfg)
	top, _ := repo(t)
	dir := fakeClaude(t)
	plugin := t.TempDir()
	t.Setenv("FAKE_OUT", `[{"id":"demo@mk","scope":"user","enabled":true,"installPath":"`+plugin+`"},
		{"id":"team@mk","scope":"local","enabled":false,"projectPath":"`+top+`","installPath":"`+plugin+`"},
		{"id":"other@mk","scope":"local","enabled":true,"projectPath":"/elsewhere","installPath":"`+plugin+`"}]`)
	ctx := context.Background()
	testcheck.Write(t, filepath.Join(top, ".claude", "settings.local.json"), `{"enabledPlugins":{"team@mk":true}}`)
	got, err := listPlugins(ctx, top)
	if err != nil || len(got) != 2 || got[0].ID != "demo@mk" || !got[0].Enabled || got[1].ID != "team@mk" || !got[1].Enabled {
		t.Fatalf("listed %+v, %v", got, err)
	}
	if err := (Claude{}).SetPluginOn(ctx, top, "demo@mk", false); err != nil {
		t.Fatal(err)
	}
	testcheck.Write(t, filepath.Join(top, ".claude", "settings.json"), `{"enabledPlugins":{"demo@mk":true}}`)
	if err := (Claude{}).SetPluginOn(ctx, top, "demo@mk", false); err != nil {
		t.Fatal(err)
	}
	if got := readJSON(t, filepath.Join(top, ".claude", "settings.local.json")); got != `{"enabledPlugins":{"demo@mk":false,"team@mk":true}}` {
		t.Errorf("local settings: %s", got)
	}
	if err := (Claude{}).Uninstall(ctx, top, "demo@mk"); err != nil {
		t.Fatal(err)
	}
	for _, bad := range []string{"team@mk", "other@mk", "-x", "nothere@mk"} {
		if err := (Claude{}).Uninstall(ctx, top, bad); err == nil {
			t.Errorf("uninstalled %s", bad)
		}
	}
	list := []string{"plugin", "list", "--json"}
	want := [][]string{
		list, list, {"plugin", "disable", "--json", "--scope", "user", "--", "demo@mk"}, list,
		list, {"plugin", "uninstall", "--json", "--scope", "user", "--", "demo@mk"}, list, list, list,
	}
	if got := calls(t, dir); !slices.EqualFunc(got, want, slices.Equal) {
		t.Errorf("calls:\n%q\nwant\n%q", got, want)
	}
	pwd, _ := os.ReadFile(filepath.Join(dir, "pwd"))
	for line := range strings.SplitSeq(strings.TrimSpace(string(pwd)), "\n") {
		if line != cfg {
			t.Errorf("claude ran in %s", line)
		}
	}
	t.Setenv("FAKE_EXIT", "1")
	if _, err := listPlugins(ctx, top); err == nil {
		t.Error("a failed list: no error")
	}
}

// Only a skill's folder right in a skills folder goes to the Trash.
func TestTrashOnlyASkillsFolder(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", cfg)
	top, deeper := repo(t)
	bin := t.TempDir()
	trashed := filepath.Join(bin, "trashed")
	testcheck.Write(t, filepath.Join(bin, "trash"), "#!/bin/sh\necho \"$1\" >> \""+trashed+"\"\nmv \"$1\" \""+bin+"/gone\"\n")
	if err := os.Chmod(filepath.Join(bin, "trash"), 0o700); err != nil {
		t.Fatal(err)
	}
	old := skillfile.TrashProgram
	skillfile.TrashProgram = filepath.Join(bin, "trash")
	defer func() { skillfile.TrashProgram = old }()
	skill(t, filepath.Join(top, ".claude", "skills"), "proj", "x")
	testcheck.Write(t, filepath.Join(top, ".claude", "skills", "nofile", "README.md"), "x")
	ctx := context.Background()
	for _, bad := range []string{
		filepath.Join(top, ".claude", "skills"),
		filepath.Join(top, ".claude", "skills", "nofile"),
		filepath.Join(top, ".claude", "skills", "proj") + "/../proj",
		filepath.Join(top, "src"),
		filepath.Join(cfg, "skills", "missing"),
		"relative/proj",
	} {
		if err := (Claude{}).Trash(ctx, deeper, bad); err == nil {
			t.Errorf("trashed %s", bad)
		}
	}
	// A project's .claude/skills that links elsewhere: not listed, and
	// nothing moves.
	elsewhere := t.TempDir()
	skill(t, elsewhere, "victim", "x")
	if err := os.Symlink(elsewhere, filepath.Join(top, "sub", ".claude")); err != nil {
		t.Fatal(err)
	}
	if err := (Claude{}).Trash(ctx, deeper, filepath.Join(top, "sub", ".claude", "victim")); err == nil {
		t.Error("trashed through a linked .claude")
	}
	if err := os.MkdirAll(filepath.Join(top, "sub", "deeper", ".claude"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(elsewhere, filepath.Join(top, "sub", "deeper", ".claude", "skills")); err != nil {
		t.Fatal(err)
	}
	if err := (Claude{}).Trash(ctx, deeper, filepath.Join(top, "sub", "deeper", ".claude", "skills", "victim")); err == nil {
		t.Error("trashed through a linked .claude/skills")
	}
	if l, _ := (Claude{}).List(ctx, deeper); slices.ContainsFunc(l.Skills, func(s model.Skill) bool { return s.Name == "victim" }) {
		t.Error("listed a skill through a link")
	}
	if _, err := os.Stat(filepath.Join(elsewhere, "victim", "SKILL.md")); err != nil {
		t.Errorf("the link's target was touched: %v", err)
	}
	path := filepath.Join(top, ".claude", "skills", "proj")
	if err := (Claude{}).Trash(ctx, deeper, path); err != nil {
		t.Fatal(err)
	}
	// Through a folder of Nushi's in the repository (skillfile.Trash).
	if b, _ := os.ReadFile(trashed); !strings.HasPrefix(string(b), top+"/.nushi-trash-") || !strings.HasSuffix(string(b), "/proj\n") {
		t.Errorf("trash got %q", b)
	}
	if _, err := os.Lstat(path); err == nil {
		t.Error("still there")
	}
}
