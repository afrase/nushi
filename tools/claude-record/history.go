package main

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

// A scenario's history/ holds claude's transcripts as the run left them:
// history/<n>/ just before the nth request that reads them (a load, a
// resume or a fork), history/end/ once the run was over. The parity test
// gives them to Nushi's Go agent at the same points, since it reads the
// transcripts itself. Each is what claude's project folders held, the
// folders' names left out (they name the run's throwaway folder).

// history copies the transcripts in claude's projects folder to dst:
// each project folder's sessions and their subagents', not its memory.
// A projects folder claude hasn't made yet copies nothing.
func history(projects, dst string) error {
	folders, err := os.ReadDir(projects)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	for _, f := range folders {
		if !f.IsDir() {
			continue
		}
		src := filepath.Join(projects, f.Name())
		err := filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			rel, _ := filepath.Rel(src, path)
			switch {
			case d.IsDir() && rel == "memory":
				return filepath.SkipDir
			case !d.Type().IsRegular():
				return nil
			}
			b, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			to := filepath.Join(dst, rel)
			if err := os.MkdirAll(filepath.Dir(to), 0o755); err != nil {
				return err
			}
			return os.WriteFile(to, b, 0o644)
		})
		if err != nil {
			return fmt.Errorf("copying claude's history: %w", err)
		}
	}
	return nil
}
