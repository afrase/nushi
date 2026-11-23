// Package realpath compares folders as the file system has them: a path
// with its links resolved, and whether one folder is in another by either
// spelling. A chat's record can hold a folder by a link's spelling (macOS's
// /tmp is /private/tmp) while git and agents report the resolved one.
package realpath

import "path/filepath"

// Of returns path with its links resolved (macOS's /tmp is /private/tmp),
// as git reports worktrees and agents keep a session's cwd; path cleaned
// when it can't be resolved (a folder that's gone), so two spellings of it
// still compare equal; "" for "".
func Of(path string) string {
	if path == "" {
		return ""
	}
	if r, err := filepath.EvalSymlinks(path); err == nil {
		return r
	}
	return filepath.Clean(path)
}

// Within says whether path is dir or in it, by its spelling or by both
// real paths: a folder reached through a link to dir is in it, and so is
// a link inside dir that leads out (removing dir removes the link). It
// answers for what removing or keeping dir does to path, never for what
// may be read there: a link out counts. Names are compared as spelled, so
// a spelling in another case isn't in it, even on a volume that ignores
// case.
func Within(path, dir string) bool {
	if under(path, dir) {
		return true
	}
	return under(Of(path), Of(dir))
}

// under says whether path is dir or in it, by name.
func under(path, dir string) bool {
	if path == "" || dir == "" {
		return false
	}
	rel, err := filepath.Rel(dir, path)
	return err == nil && filepath.IsLocal(rel)
}
