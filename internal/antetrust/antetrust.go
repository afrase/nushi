// Package antetrust says what a folder brings along for Ante (0.2.14,
// checked; ADR 0031). Ante keeps no record of trusted folders. A folder's
// own settings are the nearest `.ante/settings.json` from it up, layered
// over the user's; Ante drops from it what would widen what it may do
// (permission mode, allow rules, MCP servers, system prompt, model,
// provider), and has no hooks. The card shows that file whole all the
// same: it is what the folder sets for Ante, and Nushi can't check the
// closed binary that reads it.
package antetrust

import (
	"io/fs"
	"os"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/folderfiles"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// Trust reads a folder's settings for Ante.
type Trust struct{}

// Key is what "Start anyway" for Ante is kept under (folderfiles.Key).
func (Trust) Key(folder string) string { return folderfiles.Key("ante", folder, files(folder)) }

// Trusted says whether "Start anyway" covers folder as it is now.
func (t Trust) Trusted(folder string, also []string) (bool, error) {
	key := t.Key(folder)
	return key != "" && slices.Contains(also, key), nil
}

// Runs shows the folder's settings for Ante, if it has any.
func (Trust) Runs(folder string) ([]model.FolderRun, string, error) {
	fs := files(folder)
	var out []model.FolderRun
	for _, f := range fs {
		out = append(out, folderfiles.Run(f, "Read by Ante, which ignores what would let it do more"))
	}
	return out, folderfiles.Key("ante", folder, fs), nil
}

// files is the nearest .ante/settings.json from folder up (a .ante that is
// a link counts, as Ante follows it), not the user's own in Ante's home.
func files(folder string) []folderfiles.File {
	home, _ := os.UserHomeDir()
	own := []string{git.RealPath(ante.Home()), git.RealPath(filepath.Join(home, ".ante"))}
	for dir := git.RealPath(folder); ; dir = filepath.Dir(dir) {
		root := filepath.Join(dir, ".ante")
		if !slices.Contains(own, git.RealPath(root)) {
			if fi, err := os.Lstat(root); err == nil && fi.Mode()&fs.ModeSymlink != 0 {
				return folderfiles.Walk([]string{root}, "Ante")
			}
			if _, err := os.Lstat(filepath.Join(root, "settings.json")); err == nil {
				return folderfiles.Walk([]string{filepath.Join(root, "settings.json")}, "Ante")
			}
		}
		if dir == filepath.Dir(dir) {
			return nil
		}
	}
}
