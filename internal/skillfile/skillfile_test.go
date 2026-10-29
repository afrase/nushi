package skillfile

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// The front matter's name and description, cleaned; the first line
// without one.
func TestParse(t *testing.T) {
	f := Parse([]byte("---\nname: \"x\\u202ey\"\ndescription: Does\tthings\n---\nbody\n"))
	if f.Name != "xy" || f.Description != "Does things" || !f.Described {
		t.Errorf("%+v", f)
	}
	if f := Parse([]byte("---\ndescription: \"a\\u2028b\\u200bc\\u061c\"\n---\n")); f.Description != "a bc" {
		t.Errorf("separators and invisible characters: %q", f.Description)
	}
	if f := Parse([]byte("# Title here\nmore\n")); f.Description != "Title here" || f.Described {
		t.Errorf("%+v", f)
	}
}

// Roots go up to the top, nearest first, leaving out any whose way down
// has a link; List marks a linked skill folder and a linked SKILL.md.
func TestRootsAndList(t *testing.T) {
	top, _ := filepath.EvalSymlinks(t.TempDir())
	deeper := filepath.Join(top, "a", "b")
	testcheck.Write(t, filepath.Join(top, ".agents", "skills", "s", "SKILL.md"), "x")
	elsewhere := t.TempDir()
	testcheck.Write(t, filepath.Join(elsewhere, "skills", "far", "SKILL.md"), "x")
	if err := os.MkdirAll(deeper, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(elsewhere, filepath.Join(top, "a", ".agents")); err != nil {
		t.Fatal(err)
	}
	got := Roots(deeper, top, ".agents/skills")
	want := []string{filepath.Join(deeper, ".agents", "skills"), filepath.Join(top, ".agents", "skills")}
	if !slices.Equal(got, want) {
		t.Errorf("roots %q", got)
	}
	if err := os.Symlink(filepath.Join(elsewhere, "skills", "far"), filepath.Join(top, ".agents", "skills", "linked")); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(top, ".agents", "skills", "lf"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(elsewhere, "skills", "far", "SKILL.md"), filepath.Join(top, ".agents", "skills", "lf", "SKILL.md")); err != nil {
		t.Fatal(err)
	}
	testcheck.Write(t, filepath.Join(top, ".agents", "skills")+"/evil\u202egnp/SKILL.md", "x") // a name posing as another: skipped
	l := List(filepath.Join(top, ".agents", "skills"))
	if len(l) != 3 || l[0].Entry != "lf" || !l[0].FileLinked || l[1].Linked != filepath.Join(elsewhere, "skills", "far") || l[2].Linked != "" {
		t.Errorf("%+v", l)
	}
	if Top(deeper) != "" {
		t.Error("a top without .git")
	}
}

// Trash moves only a skill's folder right in a root: a link goes, not
// what it points at; a project's skill goes through a folder of Nushi's
// in its repository, and a project root that is a link is refused.
func TestTrash(t *testing.T) {
	top, _ := filepath.EvalSymlinks(t.TempDir())
	if err := os.MkdirAll(filepath.Join(top, ".git"), 0o700); err != nil {
		t.Fatal(err)
	}
	root := filepath.Join(top, ".agents", "skills")
	bin := t.TempDir()
	testcheck.Write(t, filepath.Join(bin, "trash"), "#!/bin/sh\necho \"$1\" >> \""+bin+"/trashed\"\nmv \"$1\" \""+bin+"/gone\"\n")
	if err := os.Chmod(filepath.Join(bin, "trash"), 0o700); err != nil {
		t.Fatal(err)
	}
	old := TrashProgram
	TrashProgram = filepath.Join(bin, "trash")
	defer func() { TrashProgram = old }()
	target := t.TempDir()
	testcheck.Write(t, filepath.Join(target, "SKILL.md"), "x")
	if err := os.MkdirAll(root, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, filepath.Join(root, "linked")); err != nil {
		t.Fatal(err)
	}
	testcheck.Write(t, filepath.Join(root, "nofile", "README"), "x")
	ctx := context.Background()
	for _, bad := range []string{root, filepath.Join(root, "nofile"), filepath.Join(root, "linked") + "/../linked", "rel/linked", target} {
		if err := Trash(ctx, []string{root}, nil, bad); err == nil {
			t.Errorf("trashed %s", bad)
		}
	}
	if err := Trash(ctx, []string{root}, nil, filepath.Join(root, "linked")); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(target, "SKILL.md")); err != nil {
		t.Errorf("the link's target went: %v", err)
	}
	b, _ := os.ReadFile(filepath.Join(bin, "trashed"))
	if staged := strings.TrimSpace(string(b)); filepath.Base(staged) != "linked" || !strings.HasPrefix(staged, top+"/.nushi-trash-") {
		t.Errorf("trashed %q", staged)
	}
	if left, _ := filepath.Glob(filepath.Join(top, ".nushi-trash-*")); len(left) != 0 {
		t.Errorf("left %q", left)
	}

	// A project root that became a link: refused, and nothing moves.
	elsewhere := t.TempDir()
	testcheck.Write(t, filepath.Join(elsewhere, "victim", "SKILL.md"), "x")
	if err := os.RemoveAll(filepath.Join(top, ".agents")); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(top, ".agents"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(elsewhere, root); err != nil {
		t.Fatal(err)
	}
	if err := Trash(ctx, []string{root}, nil, filepath.Join(root, "victim")); err == nil {
		t.Error("trashed through a linked root")
	}
	if _, err := os.Stat(filepath.Join(elsewhere, "victim", "SKILL.md")); err != nil {
		t.Errorf("the link's target went: %v", err)
	}
	// Yours may be a link.
	if err := Trash(ctx, nil, []string{root}, filepath.Join(root, "victim")); err != nil {
		t.Fatal(err)
	}
}
