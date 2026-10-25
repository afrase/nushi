package antetrust

import (
	"os"
	"path/filepath"
	"testing"
)

func TestTheNearestSettingsShowWhole(t *testing.T) {
	var tr Trust
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	t.Setenv("ANTE_HOME", filepath.Join(repo, "home", ".ante"))
	sub := filepath.Join(repo, "a", "b")
	noErr(t, os.MkdirAll(sub, 0o700))
	if runs, key, _ := tr.Runs(sub); len(runs) != 0 || key == "" {
		t.Errorf("no settings: runs %v, key %q", runs, key)
	}
	noErr(t, os.MkdirAll(filepath.Join(repo, ".ante"), 0o700))
	settings := filepath.Join(repo, ".ante", "settings.json")
	noErr(t, os.WriteFile(settings, []byte(`{"tools":["Bash"]}`), 0o600))
	runs, key, _ := tr.Runs(sub)
	if len(runs) != 1 || runs[0].File != settings || runs[0].Command != `{"tools":["Bash"]}` || key == "" {
		t.Fatalf("runs %v, key %q", runs, key)
	}
	if ok, _ := tr.Trusted(sub, []string{key}); !ok {
		t.Error("Start anyway didn't take")
	}
	noErr(t, os.WriteFile(settings, []byte(`{"tools":["Bash","Write"]}`), 0o600))
	if ok, _ := tr.Trusted(sub, []string{key}); ok {
		t.Error("a changed file is still trusted")
	}

	// Ante's own settings, in its home, aren't the folder's.
	home := filepath.Join(repo, "home")
	noErr(t, os.MkdirAll(filepath.Join(home, ".ante"), 0o700))
	noErr(t, os.WriteFile(filepath.Join(home, ".ante", "settings.json"), []byte(`{"model":"x"}`), 0o600))
	if runs, _, _ := tr.Runs(home); len(runs) != 1 || runs[0].File != settings {
		t.Errorf("home: %v", runs)
	}

	// A .ante that is a link can't be vouched for.
	linked := filepath.Join(repo, "c")
	noErr(t, os.MkdirAll(linked, 0o700))
	noErr(t, os.Symlink(filepath.Join(repo, ".ante"), filepath.Join(linked, ".ante")))
	if runs, key, _ := tr.Runs(linked); len(runs) != 1 || key != "" {
		t.Errorf("link: runs %v, key %q", runs, key)
	}
}
