package folderfiles

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// hash reads a regular file whole for its sum and size, and keeps its
// text only when the card shows it, which is whole; a link or a fifo has
// no sum, and says why; of a file longer than its limit it reads nothing.
func TestHash(t *testing.T) {
	dir := t.TempDir()
	path := func(name string) string { return filepath.Join(dir, name) }
	shown, large := strings.Repeat("x", Shown), strings.Repeat("x", Shown+10)
	testcheck.Write(t, path("shown"), shown)
	testcheck.Write(t, path("large"), large)
	testcheck.NoErr(t, os.Symlink("shown", path("link")))
	testcheck.NoErr(t, syscall.Mkfifo(path("fifo"), 0o600))
	for name, text := range map[string]string{"shown": shown, "large": large} {
		sum := sha256.Sum256([]byte(text))
		f, fits := hash(path(name), maxBytes)
		if !fits || !bytes.Equal(f.Sum, sum[:]) || f.Size != int64(len(text)) {
			t.Errorf("%s: fits %v, %d bytes, sum %x", name, fits, f.Size, f.Sum)
		}
		if kept := Run(f, "Read").Command; name == "shown" && kept != text ||
			name == "large" && (f.Text != nil || kept != "too large to show: read "+path(name)) {
			t.Errorf("%s: keeps %d bytes, shows %.40q", name, len(f.Text), kept)
		}
	}
	for _, name := range []string{"link", "fifo"} {
		if f, fits := hash(path(name), maxBytes); !fits || f.Sum != nil || string(f.Text) != "not a regular file" {
			t.Errorf("%s: %q, sum %x", name, f.Text, f.Sum)
		}
	}
	if f, fits := hash(path("none"), maxBytes); !fits || f.Sum != nil || len(f.Text) == 0 {
		t.Errorf("none: %q, sum %x", f.Text, f.Sum)
	}
	if f, fits := hash(path("shown"), Shown); !fits || f.Sum == nil {
		t.Errorf("a file of its limit: fits %v, sum %x", fits, f.Sum)
	}
	if f, fits := hash(path("shown"), Shown-1); fits || f.Sum != nil || f.Text != nil {
		t.Errorf("a file over its limit: fits %v, %d bytes kept, sum %x", fits, len(f.Text), f.Sum)
	}
}

// stopped says whether files ends with the row of a walk that stopped at
// path: without a sum, so no key.
func stopped(files []File, path string) bool {
	if len(files) == 0 {
		return false
	}
	last := files[len(files)-1]
	return last.Path == path && last.Sum == nil && strings.HasPrefix(string(last.Text), "not read, nor what comes after it") &&
		Key("agent", filepath.Dir(path), files) == ""
}

// A walk meets at most maxFiles files, folders and links: with one more,
// its last row says the rest wasn't read, nothing after it is, and the
// folder has no key.
func TestAWalkMeetsOnlySoManyFiles(t *testing.T) {
	dir, after := t.TempDir(), t.TempDir()
	testcheck.Write(t, filepath.Join(after, "later"), "in the next place")
	testcheck.NoErr(t, os.Mkdir(filepath.Join(dir, "sub"), 0o700))
	for i := range maxFiles - 2 { // with dir and sub, all a walk meets
		testcheck.Write(t, filepath.Join(dir, "sub", fmt.Sprintf("f%04d", i)), "x")
	}
	files := Walk([]string{dir}, "the agent")
	if len(files) != maxFiles-2 || Key("agent", dir, files) == "" {
		t.Fatalf("at the cap: %d files, key %q", len(files), Key("agent", dir, files))
	}
	over := filepath.Join(dir, "sub", "g")
	testcheck.Write(t, over, "x")
	if files := Walk([]string{dir, after}, "the agent"); len(files) != maxFiles-1 || !stopped(files, over) {
		t.Errorf("a file over the cap: %d files, the last %+v", len(files), files[len(files)-1])
	}
	// What has no row counts too: a folder, an empty file.
	empty := t.TempDir()
	for i := range maxFiles / 2 {
		testcheck.NoErr(t, os.Mkdir(filepath.Join(empty, fmt.Sprintf("d%04d", i)), 0o700))
		testcheck.Write(t, filepath.Join(empty, fmt.Sprintf("e%04d", i)), "")
	}
	if files := Walk([]string{empty, after}, "the agent"); len(files) != 1 || !stopped(files, filepath.Join(empty, fmt.Sprintf("e%04d", maxFiles/2-1))) {
		t.Errorf("folders and empty files over the cap: %d files %+v", len(files), files)
	}
}

// A walk reads at most maxBytes: the file that would pass it isn't read,
// nor anything after it, and the folder has no key.
func TestAWalkReadsOnlySoManyBytes(t *testing.T) {
	sparse := func(path string, size int64) {
		t.Helper()
		testcheck.Write(t, path, "")
		testcheck.NoErr(t, os.Truncate(path, size))
	}
	dir, after := t.TempDir(), t.TempDir()
	testcheck.Write(t, filepath.Join(after, "later"), "in the next place")
	sparse(filepath.Join(dir, "a"), maxBytes)
	files := Walk([]string{dir}, "the agent")
	if len(files) != 1 || files[0].Size != maxBytes || files[0].Text != nil || Key("agent", dir, files) == "" {
		t.Fatalf("at the cap: %d files, key %q", len(files), Key("agent", dir, files))
	}
	over := filepath.Join(dir, "b")
	testcheck.Write(t, over, "x")
	if files := Walk([]string{dir, after}, "the agent"); len(files) != 2 || !stopped(files, over) {
		t.Errorf("a byte over the cap: %d files, the last %+v", len(files), files[len(files)-1])
	}
	huge := filepath.Join(t.TempDir(), "huge")
	sparse(huge, 1<<36) // never read: 64 GiB would outlast the test
	if files := Walk([]string{huge, after}, "the agent"); len(files) != 1 || !stopped(files, huge) {
		t.Errorf("a file over the cap by itself: %d files %+v", len(files), files)
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
