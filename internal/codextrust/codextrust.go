// Package codextrust tells whether Codex trusts a folder, and what a
// folder brings along for Codex to run there. It only reads Codex's files
// (Codex 0.160.1 through codex-acp 2.2.2; ADR 0029):
//   - Codex reads a .codex folder in each folder from the project's root
//     down to the session's cwd (config.toml, rules, hooks.json; for a
//     linked worktree the main checkout's hooks), loading those of a
//     trusted project; codex-acp tells Codex to trust every session's cwd;
//   - trust is projects.<path>.trust_level = "trusted" in Codex's
//     config.toml ($CODEX_HOME, else ~/.codex), the path being the folder,
//     its project root or its repository's main checkout;
package codextrust

import (
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"syscall"

	"github.com/BurntSushi/toml"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// Trust reads Codex's trust record and a folder's .codex files.
type Trust struct{}

// Key is what Nushi keeps "Start anyway" for Codex under: the folder and
// a hash of every file its card showed (marked as Codex's), so a folder
// below it, or a file added or changed since, asks again; trusting a
// folder for Claude doesn't trust it for Codex.
func (Trust) Key(folder string) string {
	h := sha256.New()
	for _, f := range files(folder) {
		fmt.Fprintf(h, "%s\x00%d\x00%s\x00", f.path, len(f.text), f.text)
	}
	return fmt.Sprintf("codex:%s#%x", git.RealPath(folder), h.Sum(nil))
}

// configFile is Codex's own config.
func configFile() string {
	if dir := os.Getenv("CODEX_HOME"); dir != "" {
		return filepath.Join(dir, "config.toml")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".codex", "config.toml")
}

// Trusted says whether folder is trusted: by Codex, or by one of also,
// keys Nushi was told to trust.
func (t Trust) Trusted(folder string, also []string) (bool, error) {
	if slices.Contains(also, t.Key(folder)) {
		return true, nil
	}
	var cfg struct {
		Projects map[string]struct {
			TrustLevel string `toml:"trust_level"`
		} `toml:"projects"`
	}
	b, err := readFile(configFile())
	if err == nil {
		_, err = toml.Decode(string(b), &cfg)
	}
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return false, fmt.Errorf("reading Codex's config: %w", err)
	}
	real := git.RealPath(folder)
	top, key := git.TrustRoot(real)
	for _, dir := range []string{real, folder, top, key} {
		if dir != "" && cfg.Projects[dir].TrustLevel == "trusted" {
			return true, nil
		}
	}
	return false, nil
}

// Runs lists what Codex reads from the .codex folders of a chat in folder:
// each from the project's root down to folder (Codex's project layers; for
// a linked worktree also the main checkout's, which its hooks come from).
// Every file in them that isn't empty shows whole (Nushi doesn't guess
// what Codex makes of it); a config.toml's MCP servers and the
// environment it sets show above it too.
func (Trust) Runs(folder string) ([]model.FolderRun, error) {
	var out []model.FolderRun
	for _, f := range files(folder) {
		if filepath.Base(f.path) == "config.toml" {
			out = append(out, configRuns(f.path, f.text)...)
		}
		out = append(out, model.FolderRun{File: f.path, What: "Read by Codex", Command: whole(f.path, f.text)})
	}
	return out, nil
}

type file struct {
	path string
	text []byte // its contents, or why it can't be read
}

// files returns the files of the .codex folders Codex reads for a session
// in folder (see Runs), empty ones left out.
func files(folder string) []file {
	real := git.RealPath(folder)
	top, main := git.TrustRoot(real)
	dirs := []string{real}
	for dir := real; top != "" && dir != top && dir != filepath.Dir(dir); {
		dir = filepath.Dir(dir)
		dirs = append([]string{dir}, dirs...)
	}
	if top != "" && main != top { // a linked worktree: its main checkout's too
		for _, dir := range slices.Clone(dirs) {
			if rel, err := filepath.Rel(top, dir); err == nil {
				dirs = append(dirs, filepath.Join(main, rel))
			}
		}
	}
	home := git.RealPath(filepath.Dir(configFile()))
	var out []file
	for _, dir := range dirs {
		root := git.RealPath(filepath.Join(dir, ".codex"))
		if fi, err := os.Stat(root); err != nil || !fi.IsDir() || root == home {
			continue // Codex's own config isn't the folder's
		}
		filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			switch {
			case err != nil:
				out = append(out, file{path, []byte(err.Error())})
			case d.Type()&fs.ModeSymlink != 0:
				target, _ := os.Readlink(path)
				if fi, err := os.Stat(path); err == nil && fi.Mode().IsRegular() {
					b, _ := readFile(path)
					out = append(out, file{path, b})
				} else {
					out = append(out, file{path, []byte("a link to " + target)})
				}
			case d.Type().IsRegular():
				b, err := readFile(path)
				if err != nil {
					b = []byte(err.Error())
				}
				if len(b) > 0 {
					out = append(out, file{path, b})
				}
			case !d.IsDir():
				out = append(out, file{path, []byte("not a regular file")})
			}
			return nil
		})
	}
	return out
}

// configRuns is a cheap summary of a config.toml (the file itself shows
// whole below it): the MCP servers it starts and the environment it gives
// commands. One that doesn't parse has none.
func configRuns(path string, b []byte) []model.FolderRun {
	var cfg struct {
		MCPServers map[string]struct {
			Command string   `toml:"command"`
			Args    []string `toml:"args"`
			Helper  string   `toml:"http_headers_helper"`
		} `toml:"mcp_servers"`
		Env struct {
			Set map[string]any `toml:"set"`
		} `toml:"shell_environment_policy"`
	}
	if _, err := toml.Decode(string(b), &cfg); err != nil {
		return nil
	}
	var out []model.FolderRun
	for _, name := range slices.Sorted(maps.Keys(cfg.MCPServers)) {
		s := cfg.MCPServers[name]
		if s.Command != "" {
			out = append(out, model.FolderRun{File: path, What: "MCP server " + name, Command: strings.Join(append([]string{s.Command}, s.Args...), " ")})
		}
		if s.Helper != "" {
			out = append(out, model.FolderRun{File: path, What: "Headers helper of MCP server " + name, Command: s.Helper})
		}
	}
	if len(cfg.Env.Set) > 0 {
		out = append(out, model.FolderRun{File: path, What: "Environment for commands", Command: strings.Join(slices.Sorted(maps.Keys(cfg.Env.Set)), " ")})
	}
	return out
}

// shown is the most of a file the trust card shows: all of it, or nothing
// but where it is, never a part that would look like all of it.
const shown = 256 << 10

func whole(path string, b []byte) string {
	if len(b) > shown {
		return fmt.Sprintf("too large to show (%d KB): read %s", (len(b)+1023)>>10, path)
	}
	return string(b)
}

const maxFile = 64 << 20

// readFile reads a regular file of at most 64 MiB, without waiting on a
// fifo.
func readFile(path string) ([]byte, error) {
	f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NONBLOCK, 0)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() || fi.Size() > maxFile {
		return nil, fmt.Errorf("%s isn't a regular file of at most 64 MiB", path)
	}
	return io.ReadAll(io.LimitReader(f, maxFile))
}
