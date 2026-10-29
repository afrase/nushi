// Package skillfile reads skills in the shape the agents share (the Agent
// Skills format): a folder holding a SKILL.md whose YAML front matter has
// a name and a description, in a skills folder (a "root") such as
// .claude/skills, $CODEX_HOME/skills or a repository's .agents/skills.
// What each agent makes of them (which roots, which name wins, how one is
// turned off) is its reader's: internal/claudeskills, codexskills,
// piskills. A skill's text is its author's: Clean drops what could
// disguise it, and nothing here renders or runs it.
package skillfile

import (
	"bytes"
	"cmp"
	"context"
	"crypto/rand"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"unicode"
	"unicode/utf8"

	"gopkg.in/yaml.v3"

	"github.com/afrase/nushi/internal/procgroup"
	"github.com/afrase/nushi/internal/regularfile"
)

// File is what a SKILL.md says of its skill.
type File struct {
	// Name is the front matter's name ("" without one).
	Name string
	// Description is the front matter's description, else the first line
	// of the text, cleaned (Clean) and cut to maxDescription.
	Description string
	// WhenToUse is Claude's when_to_use, which it lists with the
	// description.
	WhenToUse string
	// NoModel is disable-model-invocation: the author keeps the agent
	// from using the skill on its own.
	NoModel bool
	// Described says the description is the front matter's (some agents
	// skip a skill without one).
	Described bool
}

// Folder is one skill in a root.
type Folder struct {
	File
	// Dir is the skill's folder, root/<Entry>.
	Dir, Entry string
	// Linked is where Dir points when it is a symlink (as the link says,
	// maybe relative); "" for a real folder.
	Linked string
	// FileLinked says SKILL.md itself is a symlink (Codex skips those).
	FileLinked bool
}

// List reads the skills in root: each folder in it (or link to one) not
// named with a leading dot, holding a SKILL.md that is a regular file (a
// link to one counts, as for the agents). The root is followed if it is a
// link: callers leave out a project's linked roots (Roots), and keep
// yours (a dotfiles link to your skills folder is yours).
func List(root string) []Folder {
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil
	}
	var out []Folder
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), ".") || Clean(e.Name()) != e.Name() {
			continue // a name with control or invisible characters could pose as another in a confirmation
		}
		dir := filepath.Join(root, e.Name())
		b, err := regularfile.Read(filepath.Join(dir, "SKILL.md"), maxFile) // a fifo or device fails at once
		if err != nil {
			continue
		}
		f := Folder{File: Parse(b), Dir: dir, Entry: e.Name()}
		if e.Type()&os.ModeSymlink != 0 {
			target, _ := os.Readlink(dir)
			f.Linked = Clean(target)
		}
		if fi, err := os.Lstat(filepath.Join(dir, "SKILL.md")); err == nil && fi.Mode()&os.ModeSymlink != 0 {
			f.FileLinked = true
		}
		out = append(out, f)
	}
	return out
}

// maxFile is the largest SKILL.md read.
const maxFile = 4 << 20

// maxDescription is the most of a description kept.
const maxDescription = 4000

// Parse reads a SKILL.md's front matter: what doesn't decode stays empty.
// Without a description, the first line of the text after it stands in.
func Parse(b []byte) File {
	var f File
	body := b
	if rest, ok := bytes.CutPrefix(b, []byte("---")); ok {
		if yamlText, after, ok := bytes.Cut(rest, []byte("\n---")); ok {
			var fm struct {
				Name        string `yaml:"name"`
				Description string `yaml:"description"`
				WhenToUse   string `yaml:"when_to_use"`
				NoModel     bool   `yaml:"disable-model-invocation"`
			}
			_ = yaml.Unmarshal(yamlText, &fm) // what doesn't decode stays empty
			f = File{Name: strings.TrimSpace(Clean(fm.Name)), Description: fm.Description, WhenToUse: fm.WhenToUse, NoModel: fm.NoModel}
			body = after
		}
	}
	f.Described = strings.TrimSpace(f.Description) != ""
	if !f.Described {
		for line := range strings.SplitSeq(string(body), "\n") {
			if line = strings.TrimSpace(strings.TrimLeft(line, "-# ")); line != "" {
				f.Description = line
				break
			}
		}
	}
	f.Description = strings.TrimSpace(Clean(f.Description))
	if len(f.Description) > maxDescription {
		f.Description = strings.ToValidUTF8(f.Description[:maxDescription], "") + "…"
	}
	return f
}

// Clean keeps text's characters, a line break or tab as a space, but drops
// control and bidirectional-override characters: the text is its
// author's, shown as plain text, and shouldn't be able to reorder or hide
// what's around it (bidi marks and overrides, zero-width characters, line
// and paragraph separators).
func Clean(text string) string {
	return strings.Map(func(r rune) rune {
		switch {
		case r == '\n' || r == '\t' || r == 0x2028 || r == 0x2029:
			return ' '
		case unicode.IsControl(r), r >= 0x202A && r <= 0x202E, r >= 0x2066 && r <= 0x2069, r >= 0x200B && r <= 0x200F,
			r == 0x061C, r == 0x2060, r == 0xFEFF:
			return -1
		}
		return r
	}, text)
}

// Tokens is about what listing text costs: Claude Code 2.1.310's /skills
// gave 5 to 21 tokens for skills whose name and description were 14 to 62
// characters, about 0.35 a character. Other agents list skills alike
// (name and description in the system prompt), so the estimate stands
// for them too.
func Tokens(text string) int {
	return int(math.Round(float64(utf8.RuneCountInString(text)) * 0.35))
}

// Roots are the skills folders rel (".agents/skills") in folder and each
// folder above it up to top, nearest first; top "" goes up to /. A root
// whose path below its folder has a symlink (.agents, or .agents/skills)
// is left out: a repository's link could point the listing, and Delete,
// anywhere. folder should be a real path.
func Roots(folder, top, rel string) []string {
	var roots []string
	for dir := folder; ; dir = filepath.Dir(dir) {
		if !Linked(dir, rel) {
			roots = append(roots, filepath.Join(dir, rel))
		}
		if dir == top || dir == filepath.Dir(dir) {
			return roots
		}
	}
}

// Linked says some folder on rel's way down from dir is a symlink (or
// can't be looked at). A missing one isn't.
func Linked(dir, rel string) bool {
	p := dir
	for part := range strings.SplitSeq(filepath.Clean(rel), string(filepath.Separator)) {
		p = filepath.Join(p, part)
		fi, err := os.Lstat(p)
		if os.IsNotExist(err) {
			return false
		}
		if err != nil || fi.Mode()&os.ModeSymlink != 0 {
			return true
		}
	}
	return false
}

// Top is the folder of the nearest .git (a folder or a worktree's file) at
// or above folder, or "" outside git. It reads the files rather than ask
// git, which a repository's own config could steer.
func Top(folder string) string {
	for dir := folder; ; dir = filepath.Dir(dir) {
		if _, err := os.Lstat(filepath.Join(dir, ".git")); err == nil {
			return dir
		}
		if dir == filepath.Dir(dir) {
			return ""
		}
	}
}

// TrashProgram moves a file to the Trash (macOS's; tests swap in their
// own).
var TrashProgram = "/usr/bin/trash"

// Trash moves a skill's folder (or the link in its place, not what it
// points at) to the Trash: only a folder right in one of the project's
// roots or yours, not named with a leading dot, holding a SKILL.md. One of
// yours may be reached through a link (your dotfiles'); a project's root
// must not be one. A project's skill is first moved, through an os.Root of
// its repository (or the folder holding the root), into a fresh folder
// there, and trashed from it: a root swapped for a link after the check
// can't make the Trash take something outside.
func Trash(ctx context.Context, project, yours []string, path string) error {
	name := filepath.Base(path)
	root := filepath.Dir(path)
	if !filepath.IsAbs(path) || filepath.Clean(path) != path || strings.HasPrefix(name, ".") ||
		!slices.Contains(project, root) && !slices.Contains(yours, root) {
		return fmt.Errorf("%s isn't a skill's folder", path)
	}
	if _, err := os.Stat(filepath.Join(path, "SKILL.md")); err != nil {
		return fmt.Errorf("%s isn't a skill's folder", path)
	}
	if !slices.Contains(project, root) {
		return trash(ctx, path)
	}
	if resolved, err := filepath.EvalSymlinks(root); err != nil || resolved != root {
		return fmt.Errorf("%s is a symlink; not moving what's in it", root)
	}
	base := cmp.Or(Top(root), filepath.Dir(filepath.Dir(root)))
	r, err := os.OpenRoot(base)
	if err != nil {
		return err
	}
	defer r.Close() //nolint:errcheck // done with it
	rel, err := filepath.Rel(base, path)
	if err != nil {
		return err
	}
	stage := ".nushi-trash-" + rand.Text()
	if err := r.Mkdir(stage, 0o700); err != nil {
		return err
	}
	defer r.Remove(stage) //nolint:errcheck // empty once trashed; left if the move back failed
	staged := filepath.Join(stage, name)
	if err := r.Rename(rel, staged); err != nil {
		return fmt.Errorf("moving %s: %w", path, err)
	}
	if err := trash(ctx, filepath.Join(base, staged)); err != nil {
		if back := r.Rename(staged, rel); back != nil {
			return fmt.Errorf("%w; it is in %s", err, filepath.Join(base, stage))
		}
		return err
	}
	return nil
}

// trash runs the Trash on path (a link itself goes, not its target).
func trash(ctx context.Context, path string) error {
	cmd := exec.CommandContext(ctx, TrashProgram, path) //nolint:gosec // an absolute path checked by the caller
	procgroup.Bound(cmd)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("moving %s to the Trash: %s", path, strings.TrimSpace(string(out)))
	}
	if _, err := os.Lstat(path); err == nil {
		return fmt.Errorf("%s is still there", path)
	}
	return nil
}
