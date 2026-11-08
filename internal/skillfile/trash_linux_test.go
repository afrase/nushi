package skillfile

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// gio's trash takes a link to a skill, not the skill, into the Trash of
// XDG_DATA_HOME (here a temporary one).
func TestTrashWithGio(t *testing.T) {
	if _, err := exec.LookPath(TrashProgram[0]); err != nil {
		t.Skip("no gio on PATH (glib's)")
	}
	dir, _ := filepath.EvalSymlinks(t.TempDir())
	t.Setenv("HOME", dir)
	t.Setenv("XDG_DATA_HOME", filepath.Join(dir, "data"))
	target := filepath.Join(dir, "elsewhere", "s")
	testcheck.Write(t, filepath.Join(target, "SKILL.md"), "x")
	root := filepath.Join(dir, "skills")
	if err := os.MkdirAll(root, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, filepath.Join(root, "s")); err != nil {
		t.Fatal(err)
	}
	if err := Trash(context.Background(), nil, []string{root}, filepath.Join(root, "s")); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(target, "SKILL.md")); err != nil {
		t.Errorf("the link's target went: %v", err)
	}
	if st, err := os.Lstat(filepath.Join(dir, "data", "Trash", "files", "s")); err != nil || st.Mode()&os.ModeSymlink == 0 {
		t.Errorf("the link isn't in the Trash: %v", err)
	}
}
