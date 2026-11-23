package claude

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A worktree made with worktree.useRelativePaths (git 2.48) links back to
// itself with a relative path; its project is still the main checkout.
func TestProjectOfARelativeWorktree(t *testing.T) {
	base, _ := filepath.EvalSymlinks(t.TempDir())
	main, wt := filepath.Join(base, "main"), filepath.Join(base, "wt")
	testcheck.NoErr(t, os.Mkdir(main, 0o700))
	testcheck.Git(t, main, "init", "-q")
	testcheck.Git(t, main, "commit", "-q", "--allow-empty", "-m", "first")
	testcheck.Git(t, main, "-c", "worktree.useRelativePaths=true", "worktree", "add", "-q", wt)
	if b, _ := os.ReadFile(filepath.Join(main, ".git", "worktrees", "wt", "gitdir")); filepath.IsAbs(strings.TrimSpace(string(b))) {
		testcheck.Lacks(t, fmt.Sprintf("git wrote an absolute link back (%s): older than 2.48", b))
	}
	sub := filepath.Join(wt, "sub")
	testcheck.NoErr(t, os.Mkdir(sub, 0o700))
	for _, folder := range []string{wt, sub} {
		if got := Project(folder); got != main {
			t.Errorf("Project(%s) = %s, want the main checkout %s", folder, got, main)
		}
	}
}
