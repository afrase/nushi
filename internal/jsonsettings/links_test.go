package jsonsettings

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// layout makes a folder's files and links: "name": "text" a file (0600),
// "name": "-> target" a link, "name/": a folder.
func layout(t *testing.T, base string, files map[string]string) {
	t.Helper()
	for name, v := range files {
		path := filepath.Join(base, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		var err error
		switch {
		case strings.HasSuffix(name, "/"):
			err = os.MkdirAll(path, 0o755)
		case strings.HasPrefix(v, "-> "):
			err = os.Symlink(strings.TrimPrefix(v, "-> "), path)
		default:
			err = os.WriteFile(path, []byte(v), 0o600)
		}
		if err != nil {
			t.Fatal(err)
		}
	}
}

func setK(m map[string]json.RawMessage) error { m["k"] = json.RawMessage(`2`); return nil }

// A link on the way to a repository's .pig/mcp.json is followed as the
// system follows it, the folders on its way resolved for real before its
// target is joined: Nushi writes the file PiG would write. Each row's
// "real" is what PiG 0.8.0's `pig mcp add -l` did in that layout (the
// second review's probe, rv2/links.txt).
func TestEditInWritesTheFilePiGWould(t *testing.T) {
	for _, c := range []struct {
		name    string
		files   map[string]string
		written string   // the file that ends {"k": 2}
		left    []string // files that must not exist after
		real    string   // what the real program did
	}{
		{"a linked .pig, a relative link in it",
			map[string]string{".pig": "-> sub/inner", "sub/inner/mcp.json": "-> ../x.json", "sub/x.json": `{"k": 1}`},
			"sub/x.json", []string{"x.json"}, "wrote sub/x.json"},
		{"a target through a linked folder, then ..",
			map[string]string{".pig/mcp.json": "-> ../deep/../conf.json", "deep": "-> a/b/c", "a/b/c/": "", "a/b/conf.json": `{"k": 1}`},
			"a/b/conf.json", []string{"conf.json"}, "wrote a/b/conf.json"},
		{"a chain of links inside",
			map[string]string{".pig/mcp.json": "-> ../b.json", "b.json": "-> c.json", "c.json": `{"k": 1}`},
			"c.json", nil, "wrote c.json"},
	} {
		base := t.TempDir()
		layout(t, base, c.files)
		if _, err := EditIn(base, filepath.Join(".pig", "mcp.json"), setK); err != nil {
			t.Errorf("%s: %v (PiG %s)", c.name, err, c.real)
			continue
		}
		if b, _ := os.ReadFile(filepath.Join(base, c.written)); string(b) != `{"k": 2}` {
			t.Errorf("%s: %s is %q (PiG %s)", c.name, c.written, b, c.real)
		}
		for _, l := range c.left {
			if _, err := os.Lstat(filepath.Join(base, l)); err == nil {
				t.Errorf("%s: made %s (PiG %s)", c.name, l, c.real)
			}
		}
	}
}

// What PiG refuses, or what would leave the folder, Nushi refuses in
// plain words and writes nothing anywhere: a link out (relative, whole,
// or a linked .pig that leads out), a link to nothing (no folder made
// for it), a read-only file through a link or not.
func TestEditInRefuses(t *testing.T) {
	outside := t.TempDir()
	victim := filepath.Join(outside, "victim.json")
	if err := os.WriteFile(victim, []byte(`{"k": 1}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(outside, "mcp.json"), []byte(`{"k": 1}`), 0o600); err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct {
		name  string
		files map[string]string
		mode  string // a file made read-only
		said  string // after the file's path
		real  string
	}{
		{"a relative link out", map[string]string{".pig/mcp.json": "-> ../../" + filepath.Base(outside) + "/victim.json"}, "",
			" is a link out of its folder: Nushi changes it only inside the folder", "outside the repository"},
		{"a whole link out", map[string]string{".pig/mcp.json": "-> " + victim}, "",
			" is a link out of its folder: Nushi changes it only inside the folder", "outside the repository"},
		{"a linked .pig out", map[string]string{".pig": "-> " + outside}, "",
			" is a link out of its folder: Nushi changes it only inside the folder", "outside the repository"},
		{"a link to nothing", map[string]string{".pig/mcp.json": "-> ../nowhere/deep/x.json"}, "",
			" is a link to a missing file: Nushi leaves it as it is", "ENOENT"},
		{"a link to a read-only file", map[string]string{".pig/mcp.json": "-> ../ro.json", "ro.json": `{"k": 1}`}, "ro.json",
			" is read-only: Nushi leaves it as it is", "EACCES"},
		{"a read-only file", map[string]string{".pig/mcp.json": `{"k": 1}`}, ".pig/mcp.json",
			" is read-only: Nushi leaves it as it is", "EACCES"},
		{"a link to itself", map[string]string{".pig/mcp.json": "-> mcp.json"}, "",
			"/.pig/mcp.json is a loop of links: Nushi leaves it as it is", "ELOOP"},
		{"a loop of linked folders", map[string]string{".pig": "-> d1", "d1": "-> .pig"}, "",
			"/.pig/mcp.json is a loop of links: Nushi leaves it as it is", "ELOOP"},
		// Nushi replaces a file whole, through a new one beside it: a folder
		// it can't write in is refused, file or not (PiG writes a file
		// that is there in place, and fails for a new one).
		{"a read-only folder, no file", map[string]string{".pig/": ""}, ".pig/",
			"/.pig can't be written: Nushi leaves it as it is", "EACCES"},
		{"a read-only folder, a writable file", map[string]string{".pig/mcp.json": `{"k": 1}`}, ".pig/",
			"/.pig can't be written: Nushi leaves it as it is", "wrote it in place"},
	} {
		base := t.TempDir()
		layout(t, base, c.files)
		if c.mode != "" {
			mode := os.FileMode(0o400)
			if strings.HasSuffix(c.mode, "/") {
				mode = 0o555
				t.Cleanup(func() { _ = os.Chmod(filepath.Join(base, c.mode), 0o755) })
			}
			if err := os.Chmod(filepath.Join(base, c.mode), mode); err != nil {
				t.Fatal(err)
			}
		}
		created, err := EditIn(base, filepath.Join(".pig", "mcp.json"), setK)
		if err == nil || !strings.HasSuffix(err.Error(), c.said) || !strings.HasPrefix(err.Error(), base) || created {
			t.Errorf("%s: %v, created %v (PiG: %s)", c.name, err, created, c.real)
		}
		if _, err := os.Lstat(filepath.Join(base, "nowhere")); err == nil {
			t.Errorf("%s: made the missing target's folder", c.name)
		}
		if c.mode != "" && !strings.HasSuffix(c.mode, "/") {
			if b, _ := os.ReadFile(filepath.Join(base, c.mode)); string(b) != `{"k": 1}` {
				t.Errorf("%s: wrote %q", c.name, b)
			}
		}
		if entries, _ := os.ReadDir(filepath.Join(base, ".pig")); len(entries) > 0 && entries[0].Name() != "mcp.json" {
			t.Errorf("%s: left %v", c.name, entries)
		}
	}
	for _, f := range []string{victim, filepath.Join(outside, "mcp.json")} {
		if b, _ := os.ReadFile(f); string(b) != `{"k": 1}` {
			t.Errorf("the file outside became %q", b)
		}
	}
}

// A folder swapped for a link out between the check and the write is
// held in by os.Root, and refused in the plain words of a link out.
func TestEditInRefusesALinkSwappedIn(t *testing.T) {
	base, outside := t.TempDir(), t.TempDir()
	layout(t, base, map[string]string{".pig/mcp.json": `{"k": 1}`})
	layout(t, outside, map[string]string{"mcp.json": `{"k": 1}`})
	created, err := EditIn(base, filepath.Join(".pig", "mcp.json"), func(m map[string]json.RawMessage) error {
		if err := os.Rename(filepath.Join(base, ".pig"), filepath.Join(base, "old.pig")); err != nil {
			return err
		}
		if err := os.Symlink(outside, filepath.Join(base, ".pig")); err != nil {
			return err
		}
		return setK(m)
	})
	want := filepath.Join(base, ".pig", "mcp.json") + " is a link out of its folder: Nushi changes it only inside the folder"
	if err == nil || err.Error() != want || created {
		t.Errorf("%v, created %v", err, created)
	}
	if b, _ := os.ReadFile(filepath.Join(outside, "mcp.json")); string(b) != `{"k": 1}` {
		t.Errorf("the file outside became %q", b)
	}
}

// A folder given through a link (macOS's /tmp, /var) is the folder it
// leads to: a whole link spelled either way stays inside.
func TestEditInAFolderGivenThroughALink(t *testing.T) {
	dir, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	alias := filepath.Join(t.TempDir(), "alias")
	if err := os.Symlink(dir, alias); err != nil {
		t.Fatal(err)
	}
	for _, spelled := range []string{dir, alias} {
		conf := filepath.Join(spelled, "conf.json")
		layout(t, dir, map[string]string{"conf.json": `{"k": 1}`})
		link := filepath.Join(dir, ".pig", "mcp.json")
		_ = os.Remove(link)
		layout(t, dir, map[string]string{".pig/mcp.json": "-> " + conf})
		for _, base := range []string{dir, alias} {
			if err := os.WriteFile(filepath.Join(dir, "conf.json"), []byte(`{"k": 1}`), 0o600); err != nil {
				t.Fatal(err)
			}
			if _, err := EditIn(base, filepath.Join(".pig", "mcp.json"), setK); err != nil {
				t.Errorf("link by %s, folder by %s: %v", spelled, base, err)
			}
			if b, _ := os.ReadFile(filepath.Join(dir, "conf.json")); string(b) != `{"k": 2}` {
				t.Errorf("link by %s, folder by %s: %q", spelled, base, b)
			}
		}
	}
}

// Your own files (PiG's, Claude's, Ante's) the same: a read-only one,
// through a link or not, and a link to nothing are refused, nothing made.
func TestEditRefusesWhatYouLocked(t *testing.T) {
	dir, err := filepath.EvalSymlinks(t.TempDir()) // the file named is the one the link leads to
	if err != nil {
		t.Fatal(err)
	}
	layout(t, dir, map[string]string{"ro.json": `{"k": 1}`, "link.json": "-> ro.json", "dangling.json": "-> gone/x.json",
		"loop.json": "-> loop.json", "cfg": "-> gone/x"})
	if err := os.Chmod(filepath.Join(dir, "ro.json"), 0o400); err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct{ name, said string }{
		{"ro.json", filepath.Join(dir, "ro.json") + " is read-only: Nushi leaves it as it is"},
		{"link.json", filepath.Join(dir, "ro.json") + " is read-only: Nushi leaves it as it is"},
		{"dangling.json", filepath.Join(dir, "dangling.json") + " is a link to a missing file: Nushi leaves it as it is"},
		{"loop.json", filepath.Join(dir, "loop.json") + " is a loop of links: Nushi leaves it as it is"},
		{filepath.Join("cfg", "settings.json"), filepath.Join(dir, "cfg") + " is a link to a missing folder: Nushi leaves it as it is"},
	} {
		if _, err := Edit(filepath.Join(dir, c.name), setK); err == nil || err.Error() != c.said {
			t.Errorf("%s: %v", c.name, err)
		}
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "ro.json")); string(b) != `{"k": 1}` {
		t.Errorf("wrote %q", b)
	}
	if _, err := os.Lstat(filepath.Join(dir, "gone")); err == nil {
		t.Error("made the missing target's folder")
	}
	if fi, err := os.Lstat(filepath.Join(dir, "dangling.json")); err != nil || fi.Mode()&os.ModeSymlink == 0 {
		t.Error("the link to nothing was replaced")
	}
}
