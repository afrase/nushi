package folderfiles

import (
	"bytes"
	"crypto/sha256"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// Hash reads a regular file whole for its sum and keeps its head; a link
// or a fifo has no sum, and says why.
func TestHash(t *testing.T) {
	dir := t.TempDir()
	path := func(name string) string { return filepath.Join(dir, name) }
	text := strings.Repeat("x", Shown+10)
	testcheck.Write(t, path("file"), text)
	testcheck.NoErr(t, os.Symlink("file", path("link")))
	testcheck.NoErr(t, syscall.Mkfifo(path("fifo"), 0o600))
	sum := sha256.Sum256([]byte(text))
	if f := Hash(path("file")); !bytes.Equal(f.Sum, sum[:]) || string(f.Text) != text[:Shown+1] {
		t.Errorf("file: %d bytes, sum %x", len(f.Text), f.Sum)
	}
	for _, name := range []string{"link", "fifo"} {
		if f := Hash(path(name)); f.Sum != nil || string(f.Text) != "not a regular file" {
			t.Errorf("%s: %q, sum %x", name, f.Text, f.Sum)
		}
	}
	if f := Hash(path("none")); f.Sum != nil || len(f.Text) == 0 {
		t.Errorf("none: %q, sum %x", f.Text, f.Sum)
	}
}

// tree makes a folder's files (a path to its text) and links (a path to
// the link's text) in a temp folder, and returns it.
func tree(t *testing.T, files, links map[string]string) string {
	t.Helper()
	dir, err := filepath.EvalSymlinks(t.TempDir())
	testcheck.NoErr(t, err)
	for name, text := range files {
		testcheck.Write(t, filepath.Join(dir, name), text)
	}
	for name, target := range links {
		testcheck.NoErr(t, os.MkdirAll(filepath.Dir(filepath.Join(dir, name)), 0o700))
		testcheck.NoErr(t, os.Symlink(target, filepath.Join(dir, name)))
	}
	return dir
}

// skillRoots is the two places of skills in dir, as a card's walk has
// them.
func skillRoots(dir string) []string {
	return []string{filepath.Join(dir, ".agents", "skills"), filepath.Join(dir, ".claude", "skills")}
}

// A link into what the walk lists is remembered: a skill linked to the
// one in another place, that whole place linked, or a link to such a
// link. The link shows where it leads, and Walk itself still vouches for
// none.
func TestALinkIntoTheWalkIsRemembered(t *testing.T) {
	skill := map[string]string{".agents/skills/a/SKILL.md": "a skill"}
	for name, links := range map[string]map[string]string{
		"a linked skill":   {".claude/skills/a": "../../.agents/skills/a"},
		"a linked place":   {".claude/skills": "../.agents/skills"},
		"a linked file":    {".claude/skills/a.md": "../../.agents/skills/a/SKILL.md"},
		"a link to a link": {".claude/skills/a": "b", ".claude/skills/b": "../../.agents/skills/a"},
		"a link in itself": {".agents/skills/again": "a"},
	} {
		dir := tree(t, skill, links)
		files := WalkLinked(skillRoots(dir), "the agent")
		if len(files) != 1+len(links) || Key("agent", dir, files) == "" {
			t.Errorf("%s: %d files, key %q", name, len(files), Key("agent", dir, files))
		}
		for _, f := range files {
			leads := "which the agent follows to " + filepath.Join(dir, ".agents", "skills")
			if _, isLink := links[strings.TrimPrefix(f.Path, dir+"/")]; isLink != f.Link || f.Sum == nil ||
				(isLink && !strings.Contains(string(f.Text), leads)) {
				t.Errorf("%s: %s is %q, a link %v, sum %x", name, f.Path, f.Text, f.Link, f.Sum)
			}
		}
		if Key("agent", dir, Walk(skillRoots(dir), "the agent")) != "" {
			t.Errorf("%s: Walk remembers a link", name)
		}
	}
}

// A link that leads out of what the walk lists has no sum, wherever it is
// and however it gets there: the card doesn't show what the agent loads
// through it.
func TestALinkOutOfTheWalkIsNeverRemembered(t *testing.T) {
	files := map[string]string{
		".agents/skills/a/SKILL.md": "a skill",
		".agents/other/SKILL.md":    "beside the place",
		"elsewhere/SKILL.md":        "outside",
	}
	for name, links := range map[string]map[string]string{
		"out of the folder":          {".claude/skills/a": "../../elsewhere"},
		"beside a place":             {".claude/skills/a": "../../.agents/other"},
		"above a place":              {".claude/skills/a": "../../.agents"},
		"to a link that leads out":   {".claude/skills/a": "b", ".claude/skills/b": "../../elsewhere"},
		"into a place that's a link": {".claude/skills": "../elsewhere", ".agents/skills/b": "../../.claude/skills/SKILL.md"},
		"to nothing":                 {".claude/skills/a": "../../.agents/skills/gone"},
		"in a circle":                {".claude/skills/a": "b", ".claude/skills/b": "a"},
	} {
		dir := tree(t, files, links)
		got := WalkLinked(skillRoots(dir), "the agent")
		if key := Key("agent", dir, got); key != "" || len(got) != 1+len(links) {
			t.Errorf("%s: %d files, key %q", name, len(got), key)
		}
		for _, f := range got {
			if f.Link && (f.Sum != nil || !strings.HasSuffix(string(f.Text), ", which the agent follows")) {
				t.Errorf("%s: %s is %q, sum %x", name, f.Path, f.Text, f.Sum)
			}
		}
	}
}

// A remembered link asks again when it leads elsewhere, also when its own
// text is the same and a link further on changed, and when what it leads
// to changes.
func TestALinkThatLeadsElsewhereAsksAgain(t *testing.T) {
	dir := tree(t, map[string]string{
		".agents/skills/a/SKILL.md": "a skill",
		".agents/skills/b/SKILL.md": "a skill", // the same text: only where the link leads differs
	}, map[string]string{".claude/skills/s": "via", ".claude/skills/via": "../../.agents/skills/a"})
	look := func() (key string, s []byte) {
		t.Helper()
		files := WalkLinked(skillRoots(dir), "the agent")
		for _, f := range files {
			if f.Path == filepath.Join(dir, ".claude", "skills", "s") {
				s = f.Sum
			}
		}
		if key = Key("agent", dir, files); key == "" || s == nil {
			t.Fatalf("key %q, the link's sum %x", key, s)
		}
		return key, s
	}
	key, sum := look()
	if again, same := look(); again != key || !bytes.Equal(same, sum) {
		t.Error("the key changed with nothing changed")
	}
	via := filepath.Join(dir, ".claude", "skills", "via")
	testcheck.NoErr(t, os.Remove(via))
	testcheck.NoErr(t, os.Symlink("../../.agents/skills/b", via))
	moved, movedSum := look()
	if moved == key || bytes.Equal(movedSum, sum) {
		t.Errorf("a link further on changed: key the same %v, the link's sum the same %v", moved == key, bytes.Equal(movedSum, sum))
	}
	testcheck.Write(t, filepath.Join(dir, ".agents", "skills", "b", "SKILL.md"), "another skill")
	if changed, same := look(); changed == moved || !bytes.Equal(same, movedSum) {
		t.Errorf("what the link leads to changed: key the same %v", changed == moved)
	}
}
