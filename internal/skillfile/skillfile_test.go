package skillfile

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"testing"
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

// The front matter's name and description, cleaned; the first line
// without one.
func TestParse(t *testing.T) {
	f := Parse([]byte("---\nname: \"x\\u202ey\"\ndescription: Does\tthings\n---\nbody\n"))
	if f.Name != "xy" || f.Description != "Does things" || !f.Described {
		t.Errorf("%+v", f)
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
	write(t, filepath.Join(top, ".agents", "skills", "s", "SKILL.md"), "x")
	elsewhere := t.TempDir()
	write(t, filepath.Join(elsewhere, "skills", "far", "SKILL.md"), "x")
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
	l := List(filepath.Join(top, ".agents", "skills"))
	if len(l) != 3 || l[0].Entry != "lf" || !l[0].FileLinked || l[1].Linked != filepath.Join(elsewhere, "skills", "far") || l[2].Linked != "" {
		t.Errorf("%+v", l)
	}
	if Top(deeper) != "" {
		t.Error("a top without .git")
	}
}

// Trash moves only a skill's folder right in a root: a link goes, not
// what it points at.
func TestTrash(t *testing.T) {
	root, _ := filepath.EvalSymlinks(t.TempDir())
	bin := t.TempDir()
	write(t, filepath.Join(bin, "trash"), "#!/bin/sh\nmv \"$1\" \""+bin+"/gone\"\n")
	if err := os.Chmod(filepath.Join(bin, "trash"), 0o700); err != nil {
		t.Fatal(err)
	}
	old := trashProgram
	trashProgram = filepath.Join(bin, "trash")
	defer func() { trashProgram = old }()
	target := t.TempDir()
	write(t, filepath.Join(target, "SKILL.md"), "x")
	if err := os.Symlink(target, filepath.Join(root, "linked")); err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(root, "nofile", "README"), "x")
	ctx := context.Background()
	for _, bad := range []string{root, filepath.Join(root, "nofile"), filepath.Join(root, "linked") + "/../linked", "rel/linked", target} {
		if err := Trash(ctx, []string{root}, bad); err == nil {
			t.Errorf("trashed %s", bad)
		}
	}
	if err := Trash(ctx, []string{root}, filepath.Join(root, "linked")); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(target, "SKILL.md")); err != nil {
		t.Errorf("the link's target went: %v", err)
	}
}
