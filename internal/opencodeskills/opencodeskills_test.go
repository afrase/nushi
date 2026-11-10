package opencodeskills

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/features/skills"
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
// linked places and linked groups left out, a linked group of yours
// followed; off by the global config's policies.
func TestList(t *testing.T) {
	config, top, deeper := setup(t)
	elsewhere := t.TempDir()
	skill(t, filepath.Join(elsewhere, "skills"), "victim")
	skill(t, filepath.Join(elsewhere, "dotfiles"), "linked")
	for link, to := range map[string]string{
		filepath.Join(deeper, ".agents"):                    elsewhere,
		filepath.Join(top, ".agents", "skills", "away"):     filepath.Join(elsewhere, "skills"),
		filepath.Join(top, ".opencode", "skills", "away"):   filepath.Join(elsewhere, "skills"),
		filepath.Join(config, "skills", "yours"):            filepath.Join(elsewhere, "dotfiles"),
		filepath.Join(top, ".opencode", "skills", "byLink"): filepath.Join(elsewhere, "dotfiles", "linked"),
	} {
		testcheck.NoErr(t, os.Symlink(to, link))
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
	want := "project both on|project byLink on|project proj on|user nested on|user loose on|user mine off|user linked on|user older on|" +
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
		case s.Name == "everyday" && !s.Everywhere, s.Name == "nested" && s.Description != "nested",
			s.Name == "loose" && s.Path != filepath.Join(config, "skills", "loose.md"),
			s.Name == "byLink" && (s.Linked == "" || s.Path != filepath.Join(top, ".opencode", "skills", "byLink")),
			s.Name == "linked" && s.Path != filepath.Join(config, "skills", "yours", "linked"):
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

// trashByRemoving has the Trash remove what it is given.
func trashByRemoving(t *testing.T) {
	t.Helper()
	bin := t.TempDir()
	testcheck.Write(t, filepath.Join(bin, "trash"), "#!/bin/sh\nrm -r \"$1\"\n")
	testcheck.NoErr(t, os.Chmod(filepath.Join(bin, "trash"), 0o700))
	old := skillfile.TrashProgram
	skillfile.TrashProgram = []string{filepath.Join(bin, "trash")}
	t.Cleanup(func() { skillfile.TrashProgram = old })
}

// Only a folder right in the config's skills or a .opencode/skills goes
// to the Trash. A skill that is one file and one in a group stay, in
// yours and in a project's, with an error that says why; so does what
// isn't opencode's own.
func TestTrash(t *testing.T) {
	config, top, deeper := setup(t)
	trashByRemoving(t)
	skill(t, filepath.Join(top, ".opencode", "skills", "group"), "deep")
	testcheck.Write(t, filepath.Join(top, ".opencode", "skills", "lone.md"), "A lone file.\n")
	testcheck.Write(t, filepath.Join(config, "skills", "notes.txt"), "Not a skill.\n")
	ctx := context.Background()
	for _, c := range []struct{ path, want string }{
		{filepath.Join(config, "skills", "loose.md"), "is a skill in one file"},
		{filepath.Join(top, ".opencode", "skills", "lone.md"), "is a skill in one file"},
		{filepath.Join(config, "skills", "group", "nested"), "is in a group of skills"},
		{filepath.Join(top, ".opencode", "skills", "group", "deep"), "is in a group of skills"},
		{filepath.Join(config, "skills", "group"), "isn't a skill's folder"},
		{filepath.Join(config, "skills", "notes.txt"), "isn't a skill's folder"},
		{filepath.Join(config, "skills"), "isn't a skill's folder"},
		{filepath.Join(config, "skills", "mine", "..", "..", "skills"), "isn't a skill's folder"},
		{filepath.Join(top, ".agents", "skills", "release"), "isn't a skill's folder"},
		{filepath.Join(top, ".claude", "skills", "claudeproj"), "isn't a skill's folder"},
	} {
		err := OpenCode{}.Trash(ctx, deeper, c.path)
		if err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: %v, want %q", c.path, err, c.want)
		}
		if _, err := os.Stat(c.path); err != nil {
			t.Errorf("%s is gone: %v", c.path, err)
		}
	}
	for _, p := range []string{filepath.Join(config, "skills", "mine"), filepath.Join(top, ".opencode", "skills", "proj")} {
		if err := (OpenCode{}).Trash(ctx, deeper, p); err != nil {
			t.Errorf("%s: %v", p, err)
		}
	}
	// What went took nothing with it.
	l, _ := OpenCode{}.List(ctx, deeper)
	want := "project both on|project deep on|project lone on|user nested on|user loose on|user mine on|user older on|" +
		"shared release on|shared above on|shared everyday on|project claudeproj on|user claudeuser on"
	if g := listed(l.Skills); g != want { // the config's skill folder's mine shows once skills' is gone
		t.Errorf("after:\n%s\nwant\n%s", g, want)
	}
}

// A shared skill goes by the Skills view's service, which takes the
// folder holding it as its place: one in a group goes alone, one that is
// a file stays, and one in a project's linked group isn't listed, so
// nothing outside the repository can go.
func TestTrashOfASharedSkill(t *testing.T) {
	_, top, deeper := setup(t)
	trashByRemoving(t)
	shared := filepath.Join(top, ".agents", "skills")
	elsewhere, _ := filepath.EvalSymlinks(t.TempDir())
	skill(t, elsewhere, "victim")
	testcheck.NoErr(t, os.Symlink(elsewhere, filepath.Join(shared, "away")))
	skill(t, filepath.Join(shared, "group"), "deep")
	skill(t, filepath.Join(shared, "group"), "other")
	testcheck.Write(t, filepath.Join(shared, "lone.md"), "A lone file.\n")
	svc := skills.New([]string{"opencode"}, map[string]skills.Reader{"opencode": OpenCode{}}, skillfile.CanTrash, skillfile.Trash)
	ctx := context.Background()
	l, err := svc.List(ctx, "opencode", deeper)
	if err != nil {
		t.Fatal(err)
	}
	paths := map[string]string{}
	for _, s := range l.Skills {
		paths[s.Name] = s.Path
	}
	if paths["deep"] != filepath.Join(shared, "group", "deep") || paths["lone"] != filepath.Join(shared, "lone.md") || paths["victim"] != "" {
		t.Fatalf("listed at %v", paths)
	}
	for _, p := range []string{paths["lone"], filepath.Join(elsewhere, "victim"), filepath.Join(shared, "away", "victim")} {
		if err := svc.Trash(ctx, "opencode", deeper, p); err == nil || !strings.Contains(err.Error(), "isn't a skill's folder") {
			t.Errorf("%s: %v", p, err)
		}
	}
	testcheck.NoErr(t, svc.Trash(ctx, "opencode", deeper, paths["deep"]))
	for _, p := range []string{paths["lone"], filepath.Join(elsewhere, "victim", "SKILL.md"), filepath.Join(shared, "group", "other", "SKILL.md"), filepath.Join(shared, "release")} {
		if _, err := os.Stat(p); err != nil {
			t.Errorf("%s is gone: %v", p, err)
		}
	}
	if _, err := os.Stat(paths["deep"]); err == nil {
		t.Errorf("%s stayed", paths["deep"])
	}
}

// A SKILL.md right in a place makes the place one skill, named for its
// folder. It is listed as that file, a skill in one file, so Delete has
// no folder to take: the place, with every other skill in it, stays,
// whether the app sends the listed path or the place's.
func TestTrashOfAPlaceThatIsASkill(t *testing.T) {
	for _, c := range []struct {
		name    string
		place   func(home, config, top string) string
		sibling string
		want    string
	}{
		{"the project's own", func(_, _, top string) string { return filepath.Join(top, ".opencode", "skills") }, "proj", "is a skill in one file"},
		{"yours", func(_, config, _ string) string { return filepath.Join(config, "skills") }, "mine", "is a skill in one file"},
		{"the project's shared", func(_, _, top string) string { return filepath.Join(top, ".agents", "skills") }, "release", "isn't a skill's folder"},
		{"your shared", func(home, _, _ string) string { return filepath.Join(home, ".agents", "skills") }, "everyday", "isn't a skill's folder"},
		{"the project's Claude", func(_, _, top string) string { return filepath.Join(top, ".claude", "skills") }, "claudeproj", "isn't a skill's folder"},
		{"your Claude", func(home, _, _ string) string { return filepath.Join(home, ".claude", "skills") }, "claudeuser", "isn't a skill's folder"},
	} {
		t.Run(c.name, func(t *testing.T) {
			config, top, deeper := setup(t)
			trashByRemoving(t)
			place := c.place(os.Getenv("HOME"), config, top)
			file := filepath.Join(place, "SKILL.md")
			testcheck.Write(t, file, "---\ndescription: the place\n---\n")
			svc := skills.New([]string{"opencode"}, map[string]skills.Reader{"opencode": OpenCode{}}, skillfile.CanTrash, skillfile.Trash)
			ctx := context.Background()
			l, err := svc.List(ctx, "opencode", deeper)
			if err != nil {
				t.Fatal(err)
			}
			var paths []string
			for _, s := range l.Skills {
				if s.Name == filepath.Base(place) {
					paths = append(paths, s.Path)
				}
				if s.Path == place {
					t.Errorf("%s is listed as a skill's folder", place)
				}
			}
			if len(paths) != 1 || paths[0] != file {
				t.Fatalf("listed at %v, want %s", paths, file)
			}
			if err := svc.Trash(ctx, "opencode", deeper, file); err == nil || !strings.Contains(err.Error(), c.want) {
				t.Errorf("%s: %v, want %q", file, err, c.want)
			}
			if err := svc.Trash(ctx, "opencode", deeper, place); err == nil {
				t.Errorf("%s went to the Trash", place)
			}
			for _, p := range []string{file, place} {
				if err := (OpenCode{}).Trash(ctx, deeper, p); err == nil {
					t.Errorf("opencode's own Trash took %s", p)
				}
			}
			for _, p := range []string{file, filepath.Join(place, c.sibling, "SKILL.md")} {
				if _, err := os.Stat(p); err != nil {
					t.Errorf("%s is gone: %v", p, err)
				}
			}
		})
	}
}

// A linked group of yours can lead to the folder a place is in, and the
// place is then found a second way, further down. It is still the place:
// listed as its file, and Delete takes it by neither spelling.
func TestAPlaceFoundThroughALinkedGroup(t *testing.T) {
	_, _, deeper := setup(t)
	trashByRemoving(t)
	home := os.Getenv("HOME")
	place := filepath.Join(home, ".claude", "skills")
	file := filepath.Join(place, "SKILL.md")
	testcheck.Write(t, file, "The place itself.\n")
	through := filepath.Join(home, ".agents", "skills", "claude")
	testcheck.NoErr(t, os.Symlink(filepath.Join(home, ".claude"), through))
	svc := skills.New([]string{"opencode"}, map[string]skills.Reader{"opencode": OpenCode{}}, skillfile.CanTrash, skillfile.Trash)
	ctx := context.Background()
	l, err := svc.List(ctx, "opencode", deeper)
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, s := range l.Skills {
		if s.Name == "skills" {
			got = append(got, fmt.Sprintf("%s file:%v delete:%v", s.Path, s.OneFile, !s.NoTrash))
		}
	}
	if want := file + " file:true delete:false"; len(got) != 1 || got[0] != want {
		t.Errorf("listed as %v, want %s", got, want)
	}
	for _, p := range []string{place, file, filepath.Join(through, "skills"), filepath.Join(through, "skills", "SKILL.md")} {
		if err := svc.Trash(ctx, "opencode", deeper, p); err == nil {
			t.Errorf("%s went to the Trash", p)
		}
	}
	for _, p := range []string{file, filepath.Join(place, "claudeuser", "SKILL.md")} {
		if _, err := os.Stat(p); err != nil {
			t.Errorf("%s is gone: %v", p, err)
		}
	}
}

// The list says of each skill whether it is one file and whether Delete
// would refuse it, and Delete refuses exactly those: a file, one in a
// group of opencode's own (a group named as a place is, too) and Claude's,
// but not a shared one in a group. Link is refused for all: Nushi links
// nothing for opencode.
func TestTheListSaysWhatTrashRefuses(t *testing.T) {
	config, top, deeper := setup(t)
	trashByRemoving(t)
	skill(t, filepath.Join(top, ".opencode", "skills", "skills"), "inskills")
	skill(t, filepath.Join(top, ".agents", "skills", "group"), "deep")
	testcheck.Write(t, filepath.Join(top, ".agents", "skills", "lone.md"), "A lone file.\n")
	testcheck.Write(t, filepath.Join(config, "skill", "SKILL.md"), "The place itself.\n")
	svc := skills.New([]string{"opencode"}, map[string]skills.Reader{"opencode": OpenCode{}}, skillfile.CanTrash, skillfile.Trash)
	ctx := context.Background()
	l, err := svc.List(ctx, "opencode", deeper)
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]string{}
	for _, s := range l.Skills {
		got[s.Name] = fmt.Sprintf("file:%v delete:%v", s.OneFile, !s.NoTrash)
		if fi, err := os.Stat(s.Path); err != nil || fi.Mode().IsRegular() != s.OneFile {
			t.Errorf("%s: one file %v at %s (%v)", s.Name, s.OneFile, s.Path, err)
		}
		if s.Source == "shared" {
			if err := svc.Link(ctx, "opencode", deeper, s.Path); err == nil || !s.NoLink {
				t.Errorf("%s: link %v, the list says no link %v", s.Name, err, s.NoLink)
			}
		}
		if err := svc.Trash(ctx, "opencode", deeper, s.Path); (err != nil) != s.NoTrash {
			t.Errorf("%s: Trash %v, the list says no Trash %v", s.Name, err, s.NoTrash)
		}
	}
	for name, want := range map[string]string{
		"mine": "file:false delete:true", "proj": "file:false delete:true", "release": "file:false delete:true",
		"everyday": "file:false delete:true", "deep": "file:false delete:true",
		"nested": "file:false delete:false", "inskills": "file:false delete:false", "claudeproj": "file:false delete:false",
		"claudeuser": "file:false delete:false", "loose": "file:true delete:false", "lone": "file:true delete:false",
		"skill": "file:true delete:false",
	} {
		if got[name] != want {
			t.Errorf("%s: %q, want %q", name, got[name], want)
		}
	}
}
