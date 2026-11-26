package pi

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A folder's own config loads as the program decides (docs/facts/pig.md's
// Trust): the nearest decision in trust.json, made on real paths, else
// defaultProjectTrust "always" in your settings; nothing that can't be read
// decides.
func TestTrustsAsTheProgramDoes(t *testing.T) {
	home := t.TempDir()
	agent := filepath.Join(home, "agent")
	t.Setenv("PIG_CODING_AGENT_DIR", agent)
	repo := filepath.Join(home, "repo")
	for _, d := range []string{"sub", "no", "no/deeper"} {
		testcheck.NoErr(t, os.MkdirAll(filepath.Join(repo, d), 0o700))
	}
	link := filepath.Join(home, "link")
	testcheck.NoErr(t, os.Symlink(repo, link))
	resolved, err := filepath.EvalSymlinks(repo)
	testcheck.NoErr(t, err)
	if PiG.Trusts(repo) {
		t.Error("trusted with no decision")
	}
	testcheck.Write(t, filepath.Join(agent, "trust.json"), `{"`+resolved+`": true, "`+filepath.Join(resolved, "no")+`": false}`)
	for folder, want := range map[string]bool{
		repo: true, filepath.Join(repo, "sub"): true, filepath.Join(link, "sub"): true,
		filepath.Join(repo, "no"): false, filepath.Join(repo, "no", "deeper"): false, home: false,
	} {
		if got := PiG.Trusts(folder); got != want {
			t.Errorf("%s: trusted %v, want %v", folder, got, want)
		}
	}
	// A key with a trailing slash matches, as PiG's does (the review's
	// probe of pig 0.8.0, 2026-11-26).
	testcheck.Write(t, filepath.Join(agent, "trust.json"), `{"`+resolved+`/": true, "`+filepath.Join(resolved, "no")+`/": false}`)
	if !PiG.Trusts(filepath.Join(repo, "sub")) || PiG.Trusts(filepath.Join(repo, "no")) {
		t.Error("a key with a trailing slash decides nothing")
	}
	// Two keys that clean to the same folder: the exact one wins, either
	// way round, as in pig 0.8.0 (`diagnose`, the second review's probe);
	// each map order is tried, so a draw would show.
	for _, c := range []struct {
		keys string
		want bool
	}{
		{`{"` + resolved + `": false, "` + resolved + `/": true}`, false},
		{`{"` + resolved + `/": false, "` + resolved + `": true}`, true},
	} {
		testcheck.Write(t, filepath.Join(agent, "trust.json"), c.keys)
		for range 50 {
			if got := PiG.Trusts(repo); got != c.want {
				t.Fatalf("%s: trusted %v, want %v", c.keys, got, c.want)
			}
		}
	}
	testcheck.Write(t, filepath.Join(agent, "trust.json"), `{"`+filepath.Join(resolved, "no")+`": false}`)
	testcheck.Write(t, filepath.Join(agent, "settings.json"), `{"defaultProjectTrust": "always"}`)
	if !PiG.Trusts(home) || PiG.Trusts(filepath.Join(repo, "no")) {
		t.Error(`"always" should trust what no decision covers, and only that`)
	}
	testcheck.Write(t, filepath.Join(agent, "trust.json"), `not JSON`)
	testcheck.Write(t, filepath.Join(agent, "settings.json"), `not JSON`)
	if PiG.Trusts(repo) {
		t.Error("trusted from files that don't read")
	}
}
