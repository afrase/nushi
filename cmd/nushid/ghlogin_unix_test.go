//go:build unix

package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
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
