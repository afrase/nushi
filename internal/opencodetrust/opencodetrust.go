// Package opencodetrust says what a folder brings along for opencode to
// run there (opencode 2.2.6 as `opencode acp`, seen and read in its source:
// docs/facts/opencode.md; ADR 0031). opencode asks nothing and keeps no
// record of trusted folders: opening a folder imports its plugins into
// opencode's own process and starts its local MCP servers at once, and its
// agents are allowed every tool unless told otherwise, so what a folder
// tells them (agents, commands, skills) they do unasked. It loads, from
// the chat's folder and every folder above it up to /, past the
// repository's root:
//   - opencode.json and opencode.jsonc, there and in .opencode: plugins,
//     MCP servers, permission rules, the shell, formatters, LSP servers,
//     commands, and {file:…} and {env:…}, which copy a file or a variable
//     into a value;
//   - .opencode's plugin(s), agent(s), mode(s), command(s) and skill(s)
//     folders, and tool(s), which 2.2.6 no longer loads but an older
//     opencode does (the CLI is the user's own);
//   - .claude/skills and .agents/skills.
//
// The card shows every such file whole, and above a config or a command
// what it has opencode run. It leaves out the user's own, which no folder
// brings (the home folder's opencode.json, .opencode, .claude and .agents,
// and opencode's config folder), and AGENTS.md, as the other agents' cards
// leave it out. Nothing is written, and no link followed: a link shows as
// one, and is remembered only when it leads into what the card shows.
package opencodetrust

import (
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/folderfiles"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/opencode"
)

// Trust reads what a folder has opencode run.
type Trust struct{}

// Key is what "Start anyway" for opencode is kept under (folderfiles.Key).
func (Trust) Key(folder string) string { return folderfiles.Key("opencode", folder, files(folder)) }

// Trusted is false: opencode keeps no trust record, and the trust feature
// looks for Start anyway's key itself.
func (Trust) Trusted(string, []string) (bool, error) { return false, nil }

// Runs shows every file opencode loads for a chat in folder, whole, and
// above a config or a command what it runs (a cheap summary: a file too
// large to show has none, and the key covers the file either way).
func (Trust) Runs(folder string) ([]model.FolderRun, string, error) {
	fs := files(folder)
	var out []model.FolderRun
	for _, f := range fs {
		if f.Sum != nil && !f.Link && f.Size <= folderfiles.Shown {
			switch {
			case isConfig(f.Path):
				out = append(out, configRuns(f.Path, f.Text)...)
			case isCommand(f.Path):
				out = append(out, commandRuns(f.Path, f.Text)...)
			}
		}
		out = append(out, folderfiles.Run(f, "Loaded by opencode"))
	}
	return out, folderfiles.Key("opencode", folder, fs), nil
}

// inConfigFolder is what opencode loads from a .opencode folder, each
// folder under either spelling.
var inConfigFolder = []string{
	"opencode.json", "opencode.jsonc", "plugin", "plugins", "tool", "tools",
	"agent", "agents", "mode", "modes", "command", "commands", "skill", "skills",
}

// files returns what opencode loads for a chat in folder (see the
// package's comment), the outermost folder's first; empty files are left
// out. A link is a file without a sum, as is anything but a regular file:
// such a folder can't be remembered. The exception is a link into what is
// listed here (folderfiles.WalkLinked): a skill in .claude/skills linked
// to the one in .agents/skills, as Nushi's own "Link for Claude…" makes
// it (ADR 0052), or that whole folder linked, would else ask at every
// start.
func files(folder string) []folderfiles.File {
	home, _ := os.UserHomeDir()
	home = git.RealPath(home)
	// opencode walks no folders for a chat in its own config folder.
	own := git.RealPath(opencode.ConfigDir(home))
	var roots []string
	// opencode walks up from the folder as the chat names it: where a link
	// in that path makes those other folders than the real path's, both
	// count.
	dirs := upToRoot(git.RealPath(folder))
	for _, dir := range upToRoot(filepath.Clean(folder)) {
		if dir = git.RealPath(dir); !slices.Contains(dirs, dir) {
			dirs = append(dirs, dir)
		}
	}
	for _, dir := range dirs {
		if dir == home || dir == own { // the user's own, which no folder brings
			continue
		}
		roots = append(roots, filepath.Join(dir, "opencode.json"), filepath.Join(dir, "opencode.jsonc"))
		roots = append(roots, inside(filepath.Join(dir, ".opencode"), inConfigFolder...)...)
		roots = append(roots, inside(filepath.Join(dir, ".claude"), "skills")...)
		roots = append(roots, inside(filepath.Join(dir, ".agents"), "skills")...)
	}
	return folderfiles.WalkLinked(roots, "opencode")
}

// upToRoot is dir and every folder above it, / first: opencode's walk
// doesn't stop at the repository's root or at the home folder.
func upToRoot(dir string) []string {
	dirs := []string{dir}
	for dir != filepath.Dir(dir) {
		dir = filepath.Dir(dir)
		dirs = append(dirs, dir)
	}
	slices.Reverse(dirs)
	return dirs
}

// inside is names in dir, or dir alone when it is a link: opencode
// follows it, and Nushi can't vouch for where it leads (dir is no place
// the card lists whole, so no link to one is remembered).
func inside(dir string, names ...string) []string {
	if fi, err := os.Lstat(dir); err == nil && fi.Mode()&fs.ModeSymlink != 0 {
		return []string{dir}
	}
	out := make([]string, len(names))
	for i, name := range names {
		out[i] = filepath.Join(dir, name)
	}
	return out
}

// isConfig says whether path is named as opencode's config is. One so
// named among a skill's files gets a summary too, which costs nothing.
func isConfig(path string) bool {
	return slices.Contains([]string{"opencode.json", "opencode.jsonc"}, filepath.Base(path))
}

// isCommand says whether path is a command's Markdown in a .opencode
// folder.
func isCommand(path string) bool {
	slashed := filepath.ToSlash(path)
	return strings.HasSuffix(slashed, ".md") &&
		(strings.Contains(slashed, "/.opencode/command/") || strings.Contains(slashed, "/.opencode/commands/"))
}
