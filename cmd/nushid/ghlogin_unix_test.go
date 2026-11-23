//go:build unix

package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// fakeGh is a gh that answers `auth token --hostname <host>` alone: the
// environment's GH_TOKEN as gh would give it, else a made-up login token
// for github.com, else no token. With FAKE_GH_BLOCK set it marks that it
// started, then waits on that fifo, for a read cut short.
const fakeGh = `#!/bin/sh
[ "$*" = "auth token --hostname $4" ] && [ $# -eq 4 ] || { echo "unexpected: $*" >&2; exit 2; }
if [ -n "$FAKE_GH_BLOCK" ]; then : > "$FAKE_GH_BLOCK.started"; exec /bin/cat "$FAKE_GH_BLOCK"; fi
if [ -n "$NUSHI_DATA" ]; then echo "Nushi's own variables reached gh" >&2; exit 3; fi
case "$4" in
github.com) printf '  %s\n' "${GH_TOKEN:-gho_fake_login}" ;;
*) echo "no oauth token found for $4" >&2; exit 1 ;;
esac
`

// fakeGhEnv is an environment whose PATH holds only fakeGh.
func fakeGhEnv(t *testing.T) []string {
	t.Helper()
	bin := filepath.Join(t.TempDir(), "bin")
	testcheck.Write(t, filepath.Join(bin, "gh"), fakeGh)
	testcheck.NoErr(t, os.Chmod(filepath.Join(bin, "gh"), 0o700))
	return []string{"PATH=" + bin, "GH_CONFIG_DIR=" + t.TempDir(), "NUSHI_DATA=/nowhere"}
}

// A host's token is what `gh auth token --hostname` prints, gh found on
// the PATH and run in the daemon's environment (without Nushi's own
// variables), so gh's own rules pick the environment's token too; gh
// having none is no token, not an error.
func TestGhToken(t *testing.T) {
	env := fakeGhEnv(t)
	for _, tc := range []struct {
		env         []string
		host, token string
	}{
		{env, "github.com", "gho_fake_login"},
		{append(env, "GH_TOKEN=ghp_fake_env"), "github.com", "ghp_fake_env"},
		{env, "ghe.example", ""},
	} {
		token, source, err := testLogin(tc.env...).Token(t.Context(), tc.host)
		if token != tc.token || source != "gh" || err != nil {
			t.Errorf("%s: %q %q %v, want %q", tc.host, token, source, err, tc.token)
		}
	}

	// GH_PATH names gh, as it did for go-gh, before the PATH is looked at.
	other := append([]string{"PATH=" + t.TempDir(), "GH_PATH=" + filepath.Join(env[0][len("PATH="):], "gh")}, env[1:]...)
	if token, _, err := testLogin(other...).Token(t.Context(), "github.com"); token != "gho_fake_login" || err != nil {
		t.Fatalf("GH_PATH: %q %v", token, err)
	}
}

// A `gh auth token` the request cuts short is an error (gh didn't say),
// not gh having no token, and it ends with gh killed.
func TestGhTokenCutShort(t *testing.T) {
	block := filepath.Join(t.TempDir(), "block")
	testcheck.Fifo(t, block)
	g := testLogin(append(fakeGhEnv(t), "FAKE_GH_BLOCK="+block)...)
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()
	type read struct {
		token string
		err   error
	}
	done := make(chan read, 1)
	go func() {
		token, _, err := g.Token(ctx, "github.com")
		done <- read{token, err}
	}()
	testcheck.Wait(t, "gh to start", func() bool { _, err := os.Stat(block + ".started"); return err == nil })
	cancel()
	r := <-done
	if r.token != "" || !errors.Is(r.err, context.Canceled) {
		t.Fatalf("%q %v", r.token, r.err)
	}
}

// oldGh is a gh older than `gh auth token` (added in gh 2.17), or one
// that can't run in the daemon's environment: it fails whatever it's asked.
const oldGh = `#!/bin/sh
echo "unknown command \"token\" for \"gh auth\"" >&2
exit 1
`

// A gh that fails while a token only gh would read is there (the
// environment's, or one in its hosts.yml) is an error that says so, as
// with gh gone, never a quiet "no token"; with no such token, gh failing
// is still no token. gh's own words aren't in it.
func TestGhTokenGhFails(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "hosts.yml"), hostsYML)
	bin := filepath.Join(t.TempDir(), "bin")
	testcheck.Write(t, filepath.Join(bin, "gh"), oldGh)
	testcheck.NoErr(t, os.Chmod(filepath.Join(bin, "gh"), 0o700))
	base := []string{"PATH=" + bin, "GH_CONFIG_DIR=" + dir}
	for _, tc := range []struct {
		env  []string
		host string
		why  string // in the error; "" for none
	}{
		{nil, "github.com", ""},
		{[]string{"GH_TOKEN=x"}, "github.com", "GH_TOKEN is set"},
		{[]string{"GH_ENTERPRISE_TOKEN=x"}, "ghe.example", "GH_ENTERPRISE_TOKEN is set"},
		{nil, "git.corp.example", "gh's config has a token for git.corp.example"},
	} {
		token, source, err := testLogin(append(slices.Clone(base), tc.env...)...).Token(t.Context(), tc.host)
		if token != "" || source != "gh" {
			t.Errorf("%q %s: %q %q", tc.env, tc.host, token, source)
		}
		switch {
		case tc.why == "" && err != nil:
			t.Errorf("%q %s: %v", tc.env, tc.host, err)
		case tc.why != "" && (err == nil || !strings.Contains(err.Error(), tc.why) || !strings.Contains(err.Error(), "update gh") || strings.Contains(err.Error(), "unknown command")):
			t.Errorf("%q %s: %v, want it to say %q and not gh's words", tc.env, tc.host, err, tc.why)
		}
	}
}
