package opencodeskills

import (
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/regularfile"
	"github.com/afrase/nushi/internal/skillfile"
)

// found is one skill in a place.
type found struct {
	skillfile.File
	id string
	// path is the skill's folder. A skill in one file has that file: a
	// lone <name>.md, and a SKILL.md right in the place, whose folder is
	// the place itself and never a skill's to move.
	path string
	// file is its Markdown file: of two with one id in a place, opencode
	// keeps the one whose file sorts last.
	file   string
	linked string
}

const (
	// maxDepth is how many folders below a place opencode looks.
	maxDepth = 6
	// maxFolders is the most folders Nushi reads in one place. opencode
	// has no such limit; a link to / in a place would have the listing
	// read the disk.
	maxFolders = 2000
	// maxFile is the largest skill file read, as skillfile's.
	maxFile = 4 << 20
)

// skipped are the names opencode reads nothing under, besides those with
// a leading dot.
var skipped = []string{"node_modules", "venv", "__pycache__"}

// scan reads the skills in root as opencode does (docs/facts/opencode.md):
// a folder holding a SKILL.md is one skill and nothing below it is read;
// any other folder is a group, down to maxDepth; a <name>.md right in
// root is a skill named for the file. A SKILL.md right in root makes the
// place one skill, named for the place's folder: it is listed as a skill
// in one file, so nothing takes the place for a skill's folder (Delete
// would move every skill in it). Links are followed, but for a
// project's place (links false) a linked group stays out, as its linked
// places do: a skill found through one would be a folder somewhere else,
// and Delete would move that. A linked skill folder is still listed. One
// skill an id comes back, in the order of their files.
func scan(root string, links bool) []found {
	type level struct {
		dir   string
		depth int
	}
	var out []found
	queue := []level{{root, 0}}
	for i := 0; i < len(queue) && i < maxFolders; i++ {
		at := queue[i]
		groups, files := entries(at.dir)
		if slices.Contains(files, "SKILL.md") {
			file := filepath.Join(at.dir, "SKILL.md")
			path := at.dir
			if at.depth == 0 {
				path = file
			}
			out = add(out, filepath.Base(at.dir), path, file)
			continue
		}
		if !links && at.depth > 0 && linked(at.dir) {
			continue
		}
		for _, name := range files {
			if stem, ok := strings.CutSuffix(name, ".md"); ok && at.depth == 0 {
				file := filepath.Join(at.dir, name)
				out = add(out, stem, file, file)
			}
		}
		for _, name := range groups {
			if at.depth < maxDepth {
				queue = append(queue, level{filepath.Join(at.dir, name), at.depth + 1})
			}
		}
	}
	slices.SortFunc(out, func(a, b found) int { return strings.Compare(b.file, a.file) })
	seen := map[string]bool{}
	out = slices.DeleteFunc(out, func(f found) bool {
		dup := seen[f.id]
		seen[f.id] = true
		return dup
	})
	slices.Reverse(out)
	return out
}

// entries are the folders and the regular files in dir that opencode
// looks at, a link counted as what it leads to. A name with control or
// invisible characters is left out, as skillfile.List does: it could pose
// as another in a confirmation.
func entries(dir string) (folders, files []string) {
	list, _ := os.ReadDir(dir)
	for _, e := range list {
		name := e.Name()
		if strings.HasPrefix(name, ".") || slices.Contains(skipped, name) || skillfile.Clean(name) != name {
			continue
		}
		mode := e.Type()
		if mode&os.ModeSymlink != 0 {
			fi, err := os.Stat(filepath.Join(dir, name))
			if err != nil {
				continue
			}
			mode = fi.Mode()
		}
		switch {
		case mode.IsDir():
			folders = append(folders, name)
		case mode.IsRegular():
			files = append(files, name)
		}
	}
	return folders, files
}

// add reads the skill id from its file; opencode skips an empty one.
func add(out []found, id, path, file string) []found {
	b, err := regularfile.Read(file, maxFile)
	if err != nil || len(b) == 0 {
		return out
	}
	f := found{File: skillfile.Parse(b), id: id, path: path, file: file}
	if linked(path) {
		target, _ := os.Readlink(path)
		f.linked = skillfile.Clean(target)
	}
	return append(out, f)
}

// linked says whether path is itself a link.
func linked(path string) bool {
	fi, err := os.Lstat(path)
	return err == nil && fi.Mode()&os.ModeSymlink != 0
}
