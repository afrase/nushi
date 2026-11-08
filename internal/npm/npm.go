// Package npm installs npm packages into a folder from a lockfile, as `npm
// ci` does, so every package's version and hash is the lockfile's. Nothing
// outside the folder's parent is touched: npm runs under macOS's sandbox
// (sandbox_darwin.go) or Linux's bubblewrap (sandbox_linux.go) with every
// other file write denied (another OS has no sandbox, so no install, ADR
// 0097); its cache goes to a folder of the install's own, removed after,
// and it keeps no logs; no install scripts
// run; optional dependencies (prebuilt programs for each platform) are
// left out. It runs the npm on PATH, which reads the user's npm settings (a
// registry or proxy of their own).
package npm

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/procgroup"
)

// Installer installs with npm in Environ's environment (the agents';
// nil: the daemon's), Env added (tests: their own npmrc and registry).
type Installer struct {
	Environ func() []string
	Env     []string
}

// Install installs lock's package.json and package-lock.json into a new
// folder beside folder; once that has worked, ready runs and the new folder
// replaces folder.
func (in Installer) Install(ctx context.Context, lock fs.FS, folder string, ready func()) error {
	parent, name := filepath.Split(folder)
	if err := os.MkdirAll(parent, 0o700); err != nil {
		return err
	}
	stale, _ := filepath.Glob(filepath.Join(parent, "."+name+"-*")) // a run that didn't finish
	for _, p := range stale {
		_ = os.RemoveAll(p) // a leftover; the next run tries again
	}
	tmp, err := os.MkdirTemp(parent, "."+name+"-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp) //nolint:errcheck // a temp folder; the next run removes what stays
	for _, f := range []string{"package.json", "package-lock.json"} {
		b, err := fs.ReadFile(lock, f)
		if err == nil {
			err = os.WriteFile(filepath.Join(tmp, f), b, 0o600)
		}
		if err != nil {
			return err
		}
	}
	// npm's cache and temp files go in the new folder, the one place the
	// sandbox lets it write (the system's temp folder is read-only there).
	cache, temp := filepath.Join(tmp, ".npm"), filepath.Join(tmp, ".tmp")
	if err := os.Mkdir(temp, 0o700); err != nil {
		return err
	}
	env := os.Environ()
	if in.Environ != nil {
		env = in.Environ()
	}
	cmd, err := writingOnlyIn(ctx, slices.Concat(env, in.Env, []string{"TMPDIR=" + temp}), parent, "npm", "ci", "--omit=optional", "--omit=dev", "--ignore-scripts",
		"--no-audit", "--no-fund", "--update-notifier=false", "--logs-max=0", "--cache", cache)
	if err != nil {
		return err
	}
	cmd.Dir = tmp
	procgroup.Bound(cmd)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("npm ci: %w: %s", err, tail(string(out), 6))
	}
	if err := errors.Join(os.RemoveAll(cache), os.RemoveAll(temp)); err != nil {
		return err
	}
	ready()
	old := tmp + ".old"
	if err := os.Rename(folder, old); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	if err := os.Rename(tmp, folder); err != nil {
		if back := os.Rename(old, folder); back != nil && !errors.Is(back, fs.ErrNotExist) {
			return fmt.Errorf("%w; putting the old one back failed too: %w", err, back)
		}
		return err
	}
	return os.RemoveAll(old)
}

// Installed says which version of pkg folder has, and where its program
// bin is; "" for both when it hasn't.
func (Installer) Installed(folder, pkg, bin string) (version, program string) {
	dir := filepath.Join(folder, "node_modules", filepath.FromSlash(pkg))
	b, err := os.ReadFile(filepath.Join(dir, "package.json")) //nolint:gosec // an adapter's package.json in the data folder
	var p struct {
		Version string          `json:"version"`
		Bin     json.RawMessage `json:"bin"`
	}
	if err != nil || json.Unmarshal(b, &p) != nil {
		return "", ""
	}
	var bins map[string]string
	if json.Unmarshal(p.Bin, &bins) != nil { // a lone program, named after the package
		var one string
		_ = json.Unmarshal(p.Bin, &one)
		bins = map[string]string{pkg[strings.LastIndex(pkg, "/")+1:]: one}
	}
	rel := filepath.Clean(filepath.FromSlash(bins[bin]))
	if bins[bin] == "" || !filepath.IsLocal(rel) {
		return "", ""
	}
	return p.Version, filepath.Join(dir, rel)
}

// Remove removes folder.
func (Installer) Remove(folder string) error { return os.RemoveAll(folder) }

// tail returns s's last n lines.
func tail(s string, n int) string {
	lines := strings.Split(strings.TrimSpace(s), "\n")
	return strings.Join(lines[max(0, len(lines)-n):], "\n")
}
