// Package omptrust says what a folder brings along for oh-my-pi to run
// there (omp 18.12.6, read in its source; ADR 0031). omp keeps no record
// of trusted folders, and loads a project's code without asking:
// extensions, hooks, custom tools, command modules and LSP servers, from
// its own .omp and from .claude, .codex, .gemini and .opencode, and
// settings (which can name more extensions, and the shell) from those and
// .cursor. MCP configs it ignores in ACP mode. The card shows every such
// file whole, in each folder from the repository's root down to the chat's
// (the folder alone outside a repository); instructions (AGENTS.md,
// skills, rules, .md commands) it leaves out, as Claude's card does.
package omptrust

import (
	"io/fs"
	"os"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/internal/folderfiles"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// Trust reads what a folder has omp run.
type Trust struct{}

// Key is what "Start anyway" for omp is kept under (folderfiles.Key).
func (Trust) Key(folder string) string { return folderfiles.Key("omp", folder, files(folder)) }

// Trusted says whether "Start anyway" covers folder as it is now.
func (t Trust) Trusted(folder string, also []string) (bool, error) {
	key := t.Key(folder)
	return key != "" && slices.Contains(also, key), nil
}

// Runs shows every file omp loads code or settings from for folder.
func (Trust) Runs(folder string) ([]model.FolderRun, string, error) {
	fs := files(folder)
	var out []model.FolderRun
	for _, f := range fs {
		out = append(out, folderfiles.Run(f, "Loaded by omp"))
	}
	return out, folderfiles.Key("omp", folder, fs), nil
}

var lsp = []string{"lsp.json", "lsp.yaml", "lsp.yml", ".lsp.json", ".lsp.yaml", ".lsp.yml"}

func files(folder string) []folderfiles.File {
	real := git.RealPath(folder)
	top, _ := git.TrustRoot(real)
	dirs := []string{real}
	for dir := real; top != "" && dir != top && dir != filepath.Dir(dir); {
		dir = filepath.Dir(dir)
		dirs = append([]string{dir}, dirs...)
	}
	home, _ := os.UserHomeDir()
	home = git.RealPath(home)
	var roots []string
	add := func(dir string, names ...string) {
		for _, n := range names {
			roots = append(roots, filepath.Join(dir, n))
		}
	}
	for _, dir := range dirs {
		if dir == home { // omp's and the other agents' own config, never a project's
			continue
		}
		add(dir, ".omp", "opencode.json", "opencode.jsonc", "ssh.json", ".ssh.json")
		add(dir, lsp...)
		for _, c := range []string{".claude", ".codex", ".gemini", ".opencode", ".cursor"} {
			cdir := filepath.Join(dir, c)
			if fi, err := os.Lstat(cdir); err != nil {
				continue
			} else if fi.Mode()&fs.ModeSymlink != 0 { // omp follows it: can't vouch for it
				roots = append(roots, cdir)
				continue
			}
			add(cdir, "extensions", "hooks", "tools", "plugins", "settings.json", "config.toml", "opencode.json", "opencode.jsonc")
			add(cdir, lsp...)
			modules, _ := filepath.Glob(filepath.Join(cdir, "commands", "*", "index.*"))
			for _, m := range modules {
				if ext := filepath.Ext(m); slices.Contains([]string{".ts", ".js", ".mjs", ".cjs"}, ext) {
					roots = append(roots, m)
				}
			}
		}
	}
	return folderfiles.Walk(roots, "omp")
}
