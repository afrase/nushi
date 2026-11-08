package ante

import (
	"path/filepath"

	"github.com/afrase/nushi/internal/procfs"
)

// openFiles reads the open files of every process /proc lists and
// returns the id (of) of each of files one has open: a link that is the
// file's path, or the path with its links resolved, as the kernel names
// it. Only the user's own processes can be read, which is where an Ante
// runs.
func openFiles(files []string, of func(file string) string) map[string]string {
	out := map[string]string{}
	if len(files) == 0 {
		return out
	}
	byPath := make(map[string]string, 2*len(files))
	for _, f := range files {
		byPath[f] = f
		if resolved, err := filepath.EvalSymlinks(f); err == nil {
			byPath[resolved] = f
		}
	}
	for _, p := range procfs.All() {
		for _, link := range procfs.Links(p.Pid) {
			if f, ok := byPath[link]; ok {
				out[of(f)] = "another app"
			}
		}
	}
	return out
}
