package agents

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/readonly"
)

// fakeCLI writes a program into dir that prints out for --version and
// tries to leave a file behind.
func fakeCLI(t *testing.T, dir, name, out string) string {
	t.Helper()
	p := filepath.Join(dir, name)
	script := "#!/bin/sh\ntouch " + filepath.Join(dir, name+".wrote") + " 2>/dev/null\n" +
		"[ \"$1\" = auth ] && { echo '{\"loggedIn\": true}'; exit 0; }\nprintf '%s' '" + out + "'\n"
	if err := os.WriteFile(p, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return p
}

// Agents found on a PATH of fakes: installed with a version, missing,
// odd version output, found off PATH, too old, missing what they run
// under; and nothing they tried to write was written.
func TestList(t *testing.T) {
	bin, other := t.TempDir(), t.TempDir()
	fakeCLI(t, bin, "claude", "2.1.310 (Claude Code)\n")
	fakeCLI(t, bin, "codex", "codex-cli 0.163.0-alpha.2\nmore\n")
	fakeCLI(t, bin, "odd", "Odd, no version here\n")
	off := fakeCLI(t, other, "ante", "ante 0.2.9")
	fakeCLI(t, bin, "omp", "18.12.6")
	t.Setenv("PATH", bin+":/usr/bin:/bin")
	signedIn := func(run func(...string) ([]byte, error)) string {
		out, err := run("auth", "status")
		if err != nil || !strings.Contains(string(out), `"loggedIn": true`) {
			return "no"
		}
		return "yes"
	}
	svc := New([]Agent{
		{Name: "claude", CLI: "claude", SignedIn: signedIn},
		{Name: "codex", CLI: "codex"},
		{Name: "odd", CLI: "odd"},
		{Name: "ante", CLI: "ante", Also: []string{filepath.Join(other, "nope"), off}, Min: "0.2.14"},
		{Name: "omp", CLI: "omp", Needs: "bun"},
		{Name: "gone", CLI: "gone"},
	}, readonly.Output)
	want := []Status{
		{Path: bin + "/claude", Version: "2.1.310", SignedIn: "yes"},
		{Path: bin + "/codex", Version: "0.163.0-alpha.2"},
		{Path: bin + "/odd"},
		{Path: off, Version: "0.2.9", Problem: "Needs 0.2.14 or newer"},
		{Path: bin + "/omp", Version: "18.12.6", Problem: "Needs Bun"},
		{Problem: "Not installed"},
	}
	for i, got := range svc.List(context.Background()) {
		w := want[i]
		if got.Path != w.Path || got.Version != w.Version || got.Problem != w.Problem || got.SignedIn != w.SignedIn {
			t.Errorf("%s: %+v, want %+v", got.Name, got, w)
		}
	}
	for _, d := range []string{bin, other} {
		if wrote, _ := filepath.Glob(filepath.Join(d, "*.wrote")); len(wrote) > 0 {
			t.Errorf("a probe wrote %s", wrote)
		}
	}
}

func TestOlder(t *testing.T) {
	for _, c := range []struct {
		a, b string
		want bool
	}{{"0.2.9", "0.2.14", true}, {"0.2.14", "0.2.14", false}, {"1.0", "0.9.9", false}, {"0.2.14-rc1", "0.2.15", true}, {"2.1", "2.1.1", true}} {
		if older(c.a, c.b) != c.want {
			t.Errorf("older(%s, %s) isn't %v", c.a, c.b, c.want)
		}
	}
}
