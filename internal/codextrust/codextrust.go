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
// a hash of every file its card shows, each whole (marked as Codex's), so
// a folder below it, or a file added or changed since, asks again; trusting
// a folder for Claude doesn't trust it for Codex. It is "" when the hash
// can't cover what Codex reads (a link, a file it can't read, anything but
// a regular file): such a folder isn't remembered, and asks every time.
func (Trust) Key(folder string) string { return key(folder, files(folder)) }

func key(folder string, fs []file) string {
	h := sha256.New()
	for _, f := range fs {
		if f.sum == nil {
			return ""
		}
		fmt.Fprintf(h, "%s\x00%x\x00", f.path, f.sum)
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
	if key := t.Key(folder); key != "" && slices.Contains(also, key) {
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
// environment it sets show above it too. What Key can't cover says so.
func (Trust) Runs(folder string) ([]model.FolderRun, string, error) {
	var out []model.FolderRun
	fs := files(folder)
	for _, f := range fs {
		switch {
		case f.sum == nil:
			out = append(out, model.FolderRun{File: f.path, What: "Nushi can't vouch for this, so it asks every time", Command: string(f.text)})
		case filepath.Base(f.path) == "config.toml":
			out = append(out, configRuns(f.path, f.text)...)
			fallthrough
		default:
			out = append(out, model.FolderRun{File: f.path, What: "Read by Codex", Command: whole(f.path, f.text)})
		}
	}
	return out, key(folder, fs), nil
}

type file struct {
	path string
	text []byte // what the card shows: its first shown+1 bytes, or why sum is nil
	sum  []byte // the SHA-256 of all of it; nil when it can't be hashed (not a regular file)
}

// files returns the files of the .codex folders Codex reads for a session
// in folder (see Runs), empty ones left out. Links aren't followed: a link
// is a file without a sum, as is anything but a regular file.
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
		root := filepath.Join(dir, ".codex")
		fi, err := os.Lstat(root)
		switch {
		case err != nil || git.RealPath(root) == home:
			continue // none, or Codex's own config, not the folder's
		case fi.Mode()&fs.ModeSymlink != 0:
			target, _ := os.Readlink(root)
			out = append(out, file{path: root, text: []byte("a link to " + target + ", which Codex follows")})
			continue
		case !fi.IsDir():
			continue
		}
		filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			switch {
			case err != nil:
				out = append(out, file{path: path, text: []byte(err.Error())})
			case d.Type()&fs.ModeSymlink != 0:
				target, _ := os.Readlink(path)
				out = append(out, file{path: path, text: []byte("a link to " + target + ", which Codex follows")})
			case d.Type().IsRegular():
				if f := hashFile(path); len(f.text) > 0 || f.sum == nil {
					out = append(out, f)
				}
			case !d.IsDir():
				out = append(out, file{path: path, text: []byte("not a regular file")})
			}
			return nil
		})
	}
	return out
}

// hashFile reads a regular file, without following a link or waiting on a
// fifo: its SHA-256, whole, and its first shown+1 bytes.
func hashFile(path string) file {
	f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
	if err != nil {
		return file{path: path, text: []byte(err.Error())}
	}
	defer f.Close()
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() {
		return file{path: path, text: []byte("not a regular file")}
	}
	h := sha256.New()
	var head capped
	if _, err := io.Copy(io.MultiWriter(h, &head), f); err != nil {
		return file{path: path, text: []byte(err.Error())}
	}
	return file{path: path, text: head.b, sum: h.Sum(nil)}
}

// capped keeps the first shown+1 bytes written to it.
type capped struct{ b []byte }

func (c *capped) Write(p []byte) (int, error) {
	if room := shown + 1 - len(c.b); room > 0 {
		c.b = append(c.b, p[:min(room, len(p))]...)
	}
	return len(p), nil
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
		return fmt.Sprintf("too large to show: read %s", path)
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
