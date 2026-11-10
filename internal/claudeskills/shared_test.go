package claudeskills

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

// Claude doesn't read .agents/skills: a shared skill is Claude's only
// through a link in .claude/skills, which Link makes (relative, beside the
// .agents holding it), Shared finds, the switch changes by the link's
// name, and Trash takes away without touching what it points at.
func TestSharedThroughALink(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", cfg)
	top, deeper := repo(t)
	skill(t, filepath.Join(top, ".agents", "skills"), "release", "---\ndescription: shared\n---\n")
	skill(t, filepath.Join(top, ".claude", "skills"), "taken", "x")
	skill(t, filepath.Join(top, ".agents", "skills"), "taken", "x")
	ctx := context.Background()
	if got := (Claude{}).Shared(ctx, deeper); len(got) != 0 {
		t.Errorf("shared before a link: %+v", got)
	}
	shared := filepath.Join(top, ".agents", "skills", "release")
	if err := (Claude{}).Link(ctx, deeper, shared); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(top, ".claude", "skills", "release")
	if to, _ := os.Readlink(link); to != "../../.agents/skills/release" {
		t.Errorf("the link says %q", to)
	}
	// opencode lists a shared folder that holds a SKILL.md as a skill, by
	// that file: neither it nor the folder is a skill's folder to link.
	testcheck.Write(t, filepath.Join(top, ".agents", "skills", "SKILL.md"), "x")
	for _, bad := range []string{
		filepath.Join(top, ".agents", "skills", "taken"), // .claude/skills/taken is there
		filepath.Join(top, ".claude", "skills", "taken"), // not a shared skill
		shared + "/../release",
		filepath.Join(top, ".agents", "skills", "SKILL.md"),
		filepath.Join(top, ".agents", "skills"),
	} {
		if err := (Claude{}).Link(ctx, deeper, bad); err == nil {
			t.Errorf("linked %s", bad)
		}
	}
	got := Claude{}.Shared(ctx, deeper)
	if len(got) != 1 || got[0].Path != shared || got[0].Agents[0].Via != link || got[0].State != "on" {
		t.Fatalf("shared: %+v", got)
	}
	if err := (Claude{}).SetSkillOn(ctx, deeper, "shared", "release", false); err != nil {
		t.Fatal(err)
	}
	if s := readJSON(t, filepath.Join(top, ".claude", "settings.local.json")); !strings.Contains(s, `"release":"off"`) {
		t.Errorf("local settings: %s", s)
	}
	bin := t.TempDir()
	testcheck.Write(t, filepath.Join(bin, "trash"), "#!/bin/sh\nmv \"$1\" \""+bin+"/gone\"\n")
	if err := os.Chmod(filepath.Join(bin, "trash"), 0o700); err != nil {
		t.Fatal(err)
	}
	old := skillfile.TrashProgram
	skillfile.TrashProgram = []string{filepath.Join(bin, "trash")}
	defer func() { skillfile.TrashProgram = old }()
	if err := (Claude{}).Trash(ctx, deeper, link); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(shared, "SKILL.md")); err != nil {
		t.Errorf("the shared skill went with its link: %v", err)
	}

	// A linked .claude: no link made through it.
	other, _ := filepath.EvalSymlinks(t.TempDir())
	skill(t, filepath.Join(other, ".agents", "skills"), "x", "x")
	if err := os.Symlink(t.TempDir(), filepath.Join(other, ".claude")); err != nil {
		t.Fatal(err)
	}
	if err := (Claude{}).Link(ctx, other, filepath.Join(other, ".agents", "skills", "x")); err == nil {
		t.Error("linked through a linked .claude")
	}
}

// others is another agent's reader: it lists the shared skills given and
// has no skill folder of its own.
type others []model.Skill

func (o others) List(context.Context, string) (model.Skills, error) {
	return model.Skills{Skills: o, ReadsShared: true}, nil
}
func (others) SetSkillOn(context.Context, string, string, string, bool) error { return nil }
func (others) CanTrash(_ context.Context, _, path string) error {
	return fmt.Errorf("%s isn't its own", path)
}
func (o others) Trash(ctx context.Context, folder, path string) error {
	return o.CanTrash(ctx, folder, path)
}

// Claude's list says of each skill what Delete, and of each shared one
// what Link for Claude, would refuse, and they refuse exactly those: no
// link to a skill in a group or one that is a file (opencode lists both),
// nor where .claude/skills has the name already; no Delete of a file.
func TestTheListSaysWhatTrashAndLinkRefuse(t *testing.T) {
	home, _ := filepath.EvalSymlinks(t.TempDir())
	t.Setenv("HOME", home)
	cfg := filepath.Join(home, "config")
	t.Setenv("CLAUDE_CONFIG_DIR", cfg)
	fakeClaude(t)
	t.Setenv("FAKE_OUT", "[]")
	bin := t.TempDir()
	testcheck.Write(t, filepath.Join(bin, "trash"), "#!/bin/sh\nrm -r \"$1\"\n")
	testcheck.NoErr(t, os.Chmod(filepath.Join(bin, "trash"), 0o700))
	old := skillfile.TrashProgram
	skillfile.TrashProgram = []string{filepath.Join(bin, "trash")}
	defer func() { skillfile.TrashProgram = old }()
	top, deeper := repo(t)
	shared, yours := filepath.Join(top, ".agents", "skills"), filepath.Join(home, ".agents", "skills")
	var other others
	for _, rel := range []string{"plain", "taken", "linked", "group/deep", "lone.md"} {
		file := filepath.Join(shared, rel, "SKILL.md")
		if strings.HasSuffix(rel, ".md") {
			file = filepath.Join(shared, rel)
		}
		testcheck.Write(t, file, "x")
		other = append(other, model.Skill{Name: strings.TrimSuffix(filepath.Base(rel), ".md"), Source: "shared", Path: filepath.Join(shared, rel), State: "on"})
	}
	skill(t, yours, "everyday", "x")
	other = append(other, model.Skill{Name: "everyday", Source: "shared", Path: filepath.Join(yours, "everyday"), State: "on", Everywhere: true})
	skill(t, filepath.Join(top, ".claude", "skills"), "taken", "x")
	skill(t, filepath.Join(top, ".claude", "skills"), "own", "x")
	skill(t, filepath.Join(cfg, "skills"), "mine", "x")
	ctx := context.Background()
	testcheck.NoErr(t, Claude{}.Link(ctx, deeper, filepath.Join(shared, "linked")))
	svc := skills.New([]string{"claude", "codex"}, map[string]skills.Reader{"claude": Claude{}, "codex": other}, skillfile.CanTrash, skillfile.Trash)
	l, err := svc.List(ctx, "claude", deeper)
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]string{}
	// Every link first: a skill gone to the Trash frees its name for one.
	for _, s := range l.Skills {
		got[s.Source+" "+s.Name] = fmt.Sprintf("delete:%v link:%v", !s.NoTrash, s.Source == "shared" && !s.NoLink)
		if s.Source != "shared" {
			continue
		}
		if err := svc.Link(ctx, "claude", deeper, s.Path); (err != nil) != s.NoLink {
			t.Errorf("%s: Link %v, the list says no link %v", s.Name, err, s.NoLink)
		}
	}
	for _, s := range l.Skills {
		if err := svc.Trash(ctx, "claude", deeper, s.Path); (err != nil) != s.NoTrash {
			t.Errorf("%s %s: Trash %v, the list says no Trash %v", s.Source, s.Name, err, s.NoTrash)
		}
	}
	want := map[string]string{
		"user mine": "delete:true link:false", "project own": "delete:true link:false", "project taken": "delete:true link:false",
		"shared plain": "delete:true link:true", "shared everyday": "delete:true link:true",
		"shared taken": "delete:true link:false", "shared linked": "delete:true link:false",
		"shared deep": "delete:true link:false", "shared lone": "delete:false link:false",
	}
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Errorf("the list says\n%v\nwant\n%v", got, want)
	}
}
