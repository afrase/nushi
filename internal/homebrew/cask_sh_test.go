package homebrew

import (
	"errors"
	"os/exec"
	"slices"
	"strings"
	"testing"
)

// caskSh runs tools/cask.sh, which release.yml runs once a release is
// published: what it writes goes to every Homebrew user, and no other job
// runs it. It needs no network.
func caskSh(t *testing.T, args ...string) (string, error) {
	t.Helper()
	cmd := exec.Command("sh", append([]string{"../../tools/cask.sh"}, args...)...)
	var stderr strings.Builder
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return string(out), errors.Join(err, errors.New(stderr.String()))
	}
	return string(out), nil
}

// Which casks a release updates (ADR 0108): the latest release both,
// unless a beta of a later version is out; the newest beta nushi@beta
// alone; an older tag built again, none.
func TestCaskShWhich(t *testing.T) {
	for _, tc := range []struct {
		name, tag, latest, beta string
		want                    []string
	}{
		{"the latest, no beta", "v0.30.0", "v0.30.0", "", []string{"nushi", "nushi@beta"}},
		{"the latest, an older beta", "v0.30.0", "v0.30.0", "v0.30.0-beta.2", []string{"nushi", "nushi@beta"}},
		{"the latest, a newer beta out", "v0.30.0", "v0.30.0", "v0.31.0-beta.1", []string{"nushi"}},
		{"the latest, by the numbers", "v0.10.0", "v0.10.0", "v0.9.5-beta.1", []string{"nushi", "nushi@beta"}},
		{"the newest beta", "v0.31.0-beta.1", "v0.30.0", "v0.31.0-beta.1", []string{"nushi@beta"}},
		{"an older beta built again", "v0.30.0-beta.2", "v0.30.0", "v0.31.0-beta.1", nil},
		{"a beta of the latest's version", "v0.30.0-beta.2", "v0.30.0", "v0.30.0-beta.2", nil},
		{"an older release built again", "v0.29.0", "v0.30.0", "", nil},
	} {
		out, err := caskSh(t, "which", tc.tag, tc.latest, tc.beta)
		if err != nil {
			t.Errorf("%s: %v", tc.name, err)
			continue
		}
		if got := strings.Fields(out); !slices.Equal(got, tc.want) {
			t.Errorf("%s: %q, want %q", tc.name, got, tc.want)
		}
	}
}

// Each cask is the template filled in, conflicting with the other; a cask
// it doesn't know is refused.
func TestCaskShWrite(t *testing.T) {
	sha := strings.Repeat("ab", 32)
	for cask, other := range map[string]string{"nushi": "nushi@beta", "nushi@beta": "nushi"} {
		out, err := caskSh(t, "write", cask, "0.31.0-beta.1", sha)
		if err != nil {
			t.Fatalf("%s: %v", cask, err)
		}
		for _, want := range []string{`cask "` + cask + `" do`, `version "0.31.0-beta.1"`, `sha256 "` + sha + `"`, `conflicts_with cask: "` + other + `"`} {
			if !strings.Contains(out, want) {
				t.Errorf("%s: no %s in\n%s", cask, want, out)
			}
		}
		if strings.Contains(out, "@CASK@") || strings.Contains(out, "@OTHER@") || strings.Contains(out, "@VERSION@") || strings.Contains(out, "@SHA256@") {
			t.Errorf("%s: a placeholder left in\n%s", cask, out)
		}
	}
	for _, args := range [][]string{{"write", "nushi-nightly", "1.0.0", sha}, {"nonsense"}, nil} {
		var exit *exec.ExitError
		if _, err := caskSh(t, args...); !errors.As(err, &exit) || exit.ExitCode() == 0 {
			t.Errorf("%q: %v, want a failure", args, err)
		}
	}
}
