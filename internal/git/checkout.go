package git

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/procgroup"
)

// RealPath returns path with its symlinks resolved (macOS's /tmp is
// /private/tmp), as git reports worktrees and agents keep a session's
// cwd; path cleaned when it can't be resolved (a folder that's gone), so
// two spellings of it still compare equal; "" for "".
func RealPath(path string) string {
	if path == "" {
		return ""
	}
	if r, err := filepath.EvalSymlinks(path); err == nil {
		return r
	}
	return filepath.Clean(path)
}

// TrustRoot returns the root of folder's work tree ("" outside git) and
// the folder an agent keys its trust on: its repository's main checkout,
// or the folder itself outside git. It is read from the files rather than
// asked of git, which a repository's own config (core.worktree) can
// steer: the nearest folder up with a .git folder is a main checkout; one
// with a .git file is a worktree of the repository it names only when
// that repository names it back. Anything else, or a repository that sets
// core.worktree, keys on the folder itself. folder is a real path.
func TrustRoot(folder string) (top, key string) {
	for top = folder; ; top = filepath.Dir(top) {
		if _, err := os.Lstat(filepath.Join(top, ".git")); err == nil {
			break
		}
		if top == filepath.Dir(top) {
			return "", folder
		}
	}
	dotgit := filepath.Join(top, ".git")
	if fi, err := os.Lstat(dotgit); err == nil && fi.IsDir() {
		if worktreeSet(filepath.Join(dotgit, "config")) {
			return top, folder
		}
		return top, top
	}
	b, _ := os.ReadFile(dotgit)
	gitdir, ok := strings.CutPrefix(strings.TrimSpace(string(b)), "gitdir: ")
	if !ok {
		return top, folder
	}
	if !filepath.IsAbs(gitdir) {
		gitdir = filepath.Join(top, gitdir)
	}
	gitdir = RealPath(gitdir)
	back, _ := os.ReadFile(filepath.Join(gitdir, "gitdir"))
	common := filepath.Dir(filepath.Dir(gitdir)) // <common>/worktrees/<name>
	if RealPath(strings.TrimSpace(string(back))) != RealPath(dotgit) || filepath.Base(filepath.Dir(gitdir)) != "worktrees" ||
		filepath.Base(common) != ".git" || worktreeSet(filepath.Join(common, "config")) {
		return top, folder
	}
	return top, filepath.Dir(common)
}

// worktreeSet says whether a repository's config file sets core.worktree
// (includes followed); git's own environment is left out. git gets 5 s.
func worktreeSet(config string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", "config", "--file", config, "--includes", "--get", "core.worktree")
	cmd.Env = slices.DeleteFunc(os.Environ(), func(e string) bool { return strings.HasPrefix(e, "GIT_") })
	procgroup.Bound(cmd)
	return cmd.Run() == nil
}
