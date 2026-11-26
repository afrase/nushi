package jsonsettings

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"testing"
)

// A settings file Nushi makes for an agent (Claude's, Ante's, PiG's) is
// the owner's alone, in a folder that is too; one that exists keeps its
// mode.
func TestEditMakesPrivateFiles(t *testing.T) {
	path := filepath.Join(t.TempDir(), "agent", "settings.json")
	set := func(m map[string]json.RawMessage) error { m["k"] = json.RawMessage(`1`); return nil }
	created, err := Edit(path, set)
	if err != nil || !created {
		t.Fatal(created, err)
	}
	mode := func(p string) os.FileMode {
		fi, err := os.Stat(p)
		if err != nil {
			t.Fatal(err)
		}
		return fi.Mode().Perm()
	}
	if got := mode(path); got != 0o600 {
		t.Errorf("a new file is %o", got)
	}
	if got := mode(filepath.Dir(path)); got != 0o700 {
		t.Errorf("a new folder is %o", got)
	}
	if err := os.Chmod(path, 0o644); err != nil {
		t.Fatal(err)
	}
	if created, err := Edit(path, set); err != nil || created {
		t.Fatal(created, err)
	}
	if got := mode(path); got != 0o644 {
		t.Errorf("an existing file became %o", got)
	}
	if b, _ := os.ReadFile(path); string(b) != "{\n  \"k\": 1\n}\n" {
		t.Errorf("wrote %q", b)
	}
}

// A missing settings file is empty; one that isn't JSON doesn't read.
func TestRead(t *testing.T) {
	dir := t.TempDir()
	v := map[string]int{"kept": 1}
	if err := Read(filepath.Join(dir, "none.json"), &v); err != nil || v["kept"] != 1 {
		t.Errorf("missing: %v %v", v, err)
	}
	bad := filepath.Join(dir, "bad.json")
	if err := os.WriteFile(bad, []byte("{"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := Read(bad, &v); err == nil || err.Error() != bad+" doesn't read: unexpected end of JSON input" {
		t.Errorf("bad: %v", err)
	}
	good := filepath.Join(dir, "good.json")
	if err := os.WriteFile(good, []byte(`{"k":2}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := Read(good, &v); err != nil || v["k"] != 2 {
		t.Errorf("good: %v %v", v, err)
	}
}

// Edits at once each keep the others': twenty keys, each set by its own
// Edit, are all in the file after (mu, from the read to the write).
func TestEditsAtOnce(t *testing.T) {
	path := filepath.Join(t.TempDir(), "settings.json")
	var wg sync.WaitGroup
	errs := make(chan error, 20)
	for i := range 20 {
		wg.Go(func() {
			_, err := Edit(path, func(m map[string]json.RawMessage) error {
				m[fmt.Sprintf("k%d", i)] = json.RawMessage(`true`)
				return nil
			})
			errs <- err
		})
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			t.Fatal(err)
		}
	}
	var got map[string]bool
	if err := Read(path, &got); err != nil || len(got) != 20 {
		t.Errorf("%d keys of 20, %v", len(got), err)
	}
}

// A file in a folder (a repository's .pig/mcp.json) that is a link is
// written as PiG writes it: one that stays in the folder is followed, its
// target replaced with the target's mode and the link kept; one that
// leads out is refused in plain words, nothing written anywhere.
func TestEditInFollowsALinkInsideTheFolder(t *testing.T) {
	set := func(m map[string]json.RawMessage) error { m["k"] = json.RawMessage(`2`); return nil }
	for _, c := range []struct{ name, target string }{
		{"relative", "../conf.json"},
		{"absolute", ""}, // the folder's conf.json, by its whole path
	} {
		base, _ := filepath.EvalSymlinks(t.TempDir())
		conf := filepath.Join(base, "conf.json")
		if err := os.WriteFile(conf, []byte(`{"k": 1}`), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := os.MkdirAll(filepath.Join(base, ".pig"), 0o755); err != nil {
			t.Fatal(err)
		}
		target := c.target
		if target == "" {
			target = conf
		}
		link := filepath.Join(base, ".pig", "mcp.json")
		if err := os.Symlink(target, link); err != nil {
			t.Fatal(err)
		}
		if _, err := EditIn(base, filepath.Join(".pig", "mcp.json"), set); err != nil {
			t.Fatalf("%s: %v", c.name, err)
		}
		fi, err := os.Lstat(link)
		if err != nil || fi.Mode()&os.ModeSymlink == 0 {
			t.Errorf("%s: the link went: %v %v", c.name, fi, err)
		}
		fi, _ = os.Stat(conf)
		if b, _ := os.ReadFile(conf); string(b) != `{"k": 2}` || fi.Mode().Perm() != 0o600 {
			t.Errorf("%s: the target is %q, %v", c.name, b, fi.Mode())
		}
	}
	base, outside := t.TempDir(), t.TempDir()
	victim := filepath.Join(outside, "victim.json")
	if err := os.WriteFile(victim, []byte(`{"k": 1}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(base, ".pig"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(victim, filepath.Join(base, ".pig", "mcp.json")); err != nil {
		t.Fatal(err)
	}
	_, err := EditIn(base, filepath.Join(".pig", "mcp.json"), set)
	if err == nil || err.Error() != filepath.Join(base, ".pig", "mcp.json")+" is a link out of its folder: Nushi changes it only inside the folder" {
		t.Errorf("a link out: %v", err)
	}
	if b, _ := os.ReadFile(victim); string(b) != `{"k": 1}` {
		t.Errorf("the file outside became %q", b)
	}
}
