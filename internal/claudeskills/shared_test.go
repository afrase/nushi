package claudeskills

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
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
	for _, bad := range []string{
		filepath.Join(top, ".agents", "skills", "taken"), // .claude/skills/taken is there
		filepath.Join(top, ".claude", "skills", "taken"), // not a shared skill
		shared + "/../release",
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
	write(t, filepath.Join(bin, "trash"), "#!/bin/sh\nmv \"$1\" \""+bin+"/gone\"\n")
	if err := os.Chmod(filepath.Join(bin, "trash"), 0o700); err != nil {
		t.Fatal(err)
	}
	old := trashProgram
	trashProgram = filepath.Join(bin, "trash")
	defer func() { trashProgram = old }()
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
