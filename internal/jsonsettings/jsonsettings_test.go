package jsonsettings

import (
	"encoding/json"
	"os"
	"path/filepath"
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
