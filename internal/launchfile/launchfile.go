package launchfile

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/tailscale/hujson"

	"github.com/afrase/nushi/internal/regularfile"
)

// The launch files, relative to the folder, in the order they win a name
// both use: Nushi's (ADR 0052's shared .agents folder), then Claude
// desktop's.
const (
	AgentsFile = ".agents/launch.json"
	ClaudeFile = ".claude/launch.json"
)

// maxFile is the most of a launch file read: one is a few hundred bytes.
const maxFile = 1 << 20

// Launch is what a folder's launch files say.
type Launch struct {
	// Entries are the dev servers, merged by written name (without case)
	// with .agents' winning: .agents' in their order, then .claude's not
	// named there. A derived name may repeat another entry's (Claude
	// takes the first of a name). A server is addressed by its index
	// here, never by a name that fails ValidName.
	Entries []Entry
	// Files are the launch files found, each with what kept it from being
	// read, if anything.
	Files []File
}

// File is one launch file found.
type File struct {
	Path     string // AgentsFile or ClaudeFile
	FromMain bool   // read from the main checkout (Read's main)
	// Err says why the file couldn't be read: not a regular file, a link
	// out of the folder, too large, not JSON with comments, not an object,
	// or "configurations" not a list. Nil when its entries are listed.
	Err error
}

// Read reads folder's launch files (an absolute path). main is the same
// folder in the repository's main checkout when folder is in a worktree
// of it, else empty: a worktree has only what's committed, so when it has
// neither launch file, the main checkout's are read in their place (read
// only, and resolved in folder). A missing file is no error; one that
// can't be read is listed with its error, and a wrong entry with its
// Problem. The error is folder's own, or a main that isn't absolute.
func Read(folder, main string) (Launch, error) {
	if !filepath.IsAbs(folder) {
		return Launch{}, fmt.Errorf("launch files: %s is not an absolute path", folder)
	}
	if main != "" && !filepath.IsAbs(main) {
		return Launch{}, fmt.Errorf("launch files: main checkout %s is not an absolute path", main)
	}
	folder = filepath.Clean(folder)
	root, err := os.OpenRoot(folder)
	if err != nil {
		return Launch{}, fmt.Errorf("launch files: %w", err)
	}
	defer root.Close() //nolint:errcheck // read-only
	files := readFiles(root, false)
	if len(files) == 0 && main != "" {
		if mainRoot, err := os.OpenRoot(main); err == nil {
			files = readFiles(mainRoot, true)
			mainRoot.Close() //nolint:errcheck // read-only
		}
	}
	at := place{folder: folder, root: root}
	var l Launch
	won := map[string]string{} // a name, without case, to the file that has it
	for _, f := range files {
		l.Files = append(l.Files, f.File)
		for i, raw := range f.configurations {
			e := at.entry(raw)
			e.Source = Source{Path: f.Path, FromMain: f.FromMain, Index: i}
			// Only a written name claims: a derived one (two nameless
			// entries' "preview") may repeat, and never hides another.
			key := strings.ToLower(e.Name)
			if e.Name != "" && !e.NameDerived {
				switch won[key] {
				case "":
					won[key] = f.Path
				case f.Path:
					e.Problem, e.Hash = "an entry before it in this file has the same name", ""
				default:
					continue // .agents' entry of that name wins
				}
			}
			l.Entries = append(l.Entries, e)
		}
	}
	return l, nil
}

// found is a launch file found, and its configurations when it read.
type found struct {
	File
	configurations []json.RawMessage
}

// readFiles reads the launch files found in root, .agents' first.
func readFiles(root *os.Root, fromMain bool) []found {
	var files []found
	for _, path := range []string{AgentsFile, ClaudeFile} {
		b, err := regularfile.ReadIn(root, path, maxFile)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		f := found{Path: path, FromMain: fromMain}
		if err == nil {
			f.configurations, err = configurations(b)
		}
		f.Err = err
		files = append(files, f)
	}
	return files
}

// configurations is a launch file's list of entries, read as Claude reads
// it: JSON with comments and trailing commas, an object whose
// configurations, if present, is a list. version and autoVerify are left
// alone (ADR 0095).
func configurations(b []byte) ([]json.RawMessage, error) {
	std, err := hujson.Standardize(b)
	if err != nil {
		return nil, syntaxError(err)
	}
	var top map[string]json.RawMessage
	if err := json.Unmarshal(std, &top); err != nil || top == nil {
		return nil, errors.New("not a JSON object")
	}
	raw, ok := top["configurations"]
	if !ok {
		return nil, nil
	}
	var list []json.RawMessage
	if err := json.Unmarshal(raw, &list); err != nil || list == nil {
		return nil, errors.New(`"configurations" must be a list`)
	}
	return list, nil
}

// syntaxError is hujson's err in fixed words with only its place: its
// own text quotes a character of the file.
func syntaxError(err error) error {
	var line, column int
	if _, scanErr := fmt.Sscanf(err.Error(), "hujson: line %d, column %d:", &line, &column); scanErr != nil {
		return errors.New("not JSON with comments")
	}
	return fmt.Errorf("not JSON with comments (line %d, column %d)", line, column)
}
