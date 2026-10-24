// Package codextrust tells whether Codex trusts a folder, and what a
// folder brings along for Codex to run there. It only reads Codex's files
// (Codex 0.160.1 through codex-acp 2.2.2; ADR 0029):
//   - Codex loads a project's .codex folders (config.toml, rules) only when
//     the project is trusted, and codex-acp tells Codex to trust every
//     session's cwd: a chat's own folder's .codex always loads, the ones
//     above it only when Codex's record trusts them;
//   - trust is projects.<path>.trust_level = "trusted" in Codex's
//     config.toml ($CODEX_HOME, else ~/.codex), the path being the folder,
//     its project root or its repository's main checkout;
//   - a folder's hooks run only once the user trusted each of them in Codex
//     (by its hash, in the user's own config), so they aren't listed.
package codextrust

import (
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

// Key is what Nushi keeps "Start anyway" for Codex under: Codex's key for
// the folder (its repository's main checkout, or the folder outside git),
// marked as Codex's, so trusting a folder for Claude doesn't trust it for
// Codex.
func (Trust) Key(folder string) string {
	_, key := git.TrustRoot(git.RealPath(folder))
	return "codex:" + key
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

// Runs lists what folder's .codex has Codex run or allow: its MCP servers
// (their command, or the helper that makes their headers), the environment
// its commands get (the names), its sandbox and approval settings, the
// plugins it turns on, and its rules for commands (each file whole). A
// config.toml Nushi can't read shows whole.
func (Trust) Runs(folder string) ([]model.FolderRun, error) {
	dir := filepath.Join(folder, ".codex")
	if git.RealPath(dir) == git.RealPath(filepath.Dir(configFile())) {
		return nil, nil // Codex's own config, not the folder's
	}
	out, err := configRuns(filepath.Join(dir, "config.toml"))
	if err != nil {
		return nil, err
	}
	rules, _ := filepath.Glob(filepath.Join(dir, "rules", "*.rules"))
	for _, path := range rules {
		b, err := readFile(path)
		text := whole(path, b)
		if err != nil {
			text = err.Error()
		}
		out = append(out, model.FolderRun{File: path, What: "Rules for commands", Command: text})
	}
	return out, nil
}

func configRuns(path string) ([]model.FolderRun, error) {
	b, err := readFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("reading %s: %w", path, err)
	}
	var cfg struct {
		MCPServers map[string]struct {
			Command string   `toml:"command"`
			Args    []string `toml:"args"`
			Helper  string   `toml:"http_headers_helper"`
			Enabled *bool    `toml:"enabled"`
		} `toml:"mcp_servers"`
		Env struct {
			Set map[string]any `toml:"set"`
		} `toml:"shell_environment_policy"`
		Plugins map[string]struct {
			Enabled bool `toml:"enabled"`
		} `toml:"plugins"`
	}
	meta, err := toml.Decode(string(b), &cfg)
	if err != nil { // Codex may read what Nushi can't: the card shows it all
		return []model.FolderRun{{File: path, What: "Settings Nushi couldn't read", Command: whole(path, b)}}, nil
	}
	var out []model.FolderRun
	for _, name := range slices.Sorted(maps.Keys(cfg.MCPServers)) {
		s := cfg.MCPServers[name]
		if s.Enabled != nil && !*s.Enabled {
			continue
		}
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
	var perms []string
	for _, key := range []string{"sandbox_mode", "approval_policy", "approvals_reviewer", "default_permissions", "permissions", "sandbox_workspace_write"} {
		if meta.IsDefined(key) {
			perms = append(perms, key)
		}
	}
	if len(perms) > 0 {
		out = append(out, model.FolderRun{File: path, What: "Sandbox and approval settings", Command: strings.Join(perms, " ")})
	}
	for _, id := range slices.Sorted(maps.Keys(cfg.Plugins)) {
		if cfg.Plugins[id].Enabled {
			out = append(out, model.FolderRun{File: path, What: "Plugin " + id, Command: "turned on (if installed)"})
		}
	}
	return out, nil
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
