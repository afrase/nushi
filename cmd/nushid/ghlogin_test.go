package main

import (
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/testcheck"
)

// hostsYML is a hosts.yml as gh writes it: one host's token in the
// keychain (no oauth_token), another's kept in the file. The tokens are
// made up.
const hostsYML = `github.com:
    users:
        octo:
    git_protocol: https
    user: octo
git.corp.example:
    users:
        octo:
            oauth_token: gho_fake_in_file
    oauth_token: gho_fake_in_file
    user: octo
`

// testLogin is a ghLogin on env alone: gh found on env's PATH.
func testLogin(env ...string) ghLogin {
	return ghLogin{env: func() []string { return env }, lookPath: func(name string) string { return shellenv.LookPath(name, env) }}
}

// gh's hosts are hosts.yml's keys, in the folder gh would read, with
// GH_HOST and, with an environment token, github.com, as go-gh had them;
// a login since shows on the next call.
func TestGhHosts(t *testing.T) {
	dir := t.TempDir()
	sorted := func(g ghLogin) string {
		h := g.Hosts()
		slices.Sort(h)
		return strings.Join(h, " ")
	}
	testcheck.Write(t, filepath.Join(dir, "own", "hosts.yml"), hostsYML)
	testcheck.Write(t, filepath.Join(dir, "xdg", "gh", "hosts.yml"), "xdg.example:\n    user: octo\n")
	testcheck.Write(t, filepath.Join(dir, "home", ".config", "gh", "hosts.yml"), "home.example:\n    user: octo\n")
	home := "HOME=" + filepath.Join(dir, "home")
	for _, tc := range []struct {
		env  []string
		want string
	}{
		{[]string{home, "GH_CONFIG_DIR=" + filepath.Join(dir, "own"), "XDG_CONFIG_HOME=" + filepath.Join(dir, "xdg")}, "git.corp.example github.com"},
		{[]string{home, "XDG_CONFIG_HOME=" + filepath.Join(dir, "xdg")}, "xdg.example"},
		{[]string{home}, "home.example"},
		{[]string{home, "GH_HOST=ghe.example", "GH_TOKEN=x"}, "ghe.example github.com home.example"},
		{[]string{home, "GITHUB_TOKEN=x"}, "github.com home.example"},
		{[]string{"GH_CONFIG_DIR=" + filepath.Join(dir, "none"), "GH_ENTERPRISE_TOKEN=x"}, ""},
	} {
		if got := sorted(testLogin(tc.env...)); got != tc.want {
			t.Errorf("Hosts with %q = %q, want %q", tc.env, got, tc.want)
		}
	}

	g := testLogin("GH_CONFIG_DIR=" + filepath.Join(dir, "later"))
	if got := sorted(g); got != "" {
		t.Fatalf("no hosts.yml: %q", got)
	}
	testcheck.Write(t, filepath.Join(dir, "later", "hosts.yml"), "github.com:\n    user: octo\n") // gh auth login
	if got := sorted(g); got != "github.com" {
		t.Fatalf("after a login: %q", got)
	}
	testcheck.Write(t, filepath.Join(dir, "later", "hosts.yml"), "- not\n- gh's\n")
	if got := sorted(g); got != "" {
		t.Fatalf("a hosts.yml that isn't gh's: %q", got)
	}
}

// With no gh, a host has no token, as before; but a token only gh would
// have read (the environment's, by gh's rule for the host, or one in its
// hosts.yml) is an error that says so, for Settings › GitHub to show.
func TestGhTokenWithoutGh(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "hosts.yml"), hostsYML)
	base := []string{"PATH=" + filepath.Join(dir, "bin"), "GH_CONFIG_DIR=" + dir}
	for _, tc := range []struct {
		env  []string
		host string
		why  string // in the error; "" for none
	}{
		{nil, "github.com", ""},
		{[]string{"GH_TOKEN=x"}, "github.com", "GH_TOKEN is set"},
		{[]string{"GITHUB_TOKEN=x"}, "corp.ghe.com", "GITHUB_TOKEN is set"},
		{[]string{"GH_TOKEN=x"}, "ghe.example", ""},
		{[]string{"GH_ENTERPRISE_TOKEN=x"}, "ghe.example", "GH_ENTERPRISE_TOKEN is set"},
		{[]string{"GITHUB_ENTERPRISE_TOKEN=x"}, "github.com", ""},
		{nil, "git.corp.example", "gh's config has a token for git.corp.example"},
	} {
		token, source, err := testLogin(append(slices.Clone(base), tc.env...)...).Token(t.Context(), tc.host)
		if token != "" || source != "gh" {
			t.Errorf("%q %s: %q %q", tc.env, tc.host, token, source)
		}
		switch {
		case tc.why == "" && err != nil:
			t.Errorf("%q %s: %v", tc.env, tc.host, err)
		case tc.why != "" && (err == nil || !strings.Contains(err.Error(), tc.why) || !strings.Contains(err.Error(), "install gh")):
			t.Errorf("%q %s: %v, want it to say %q", tc.env, tc.host, err, tc.why)
		}
	}
}
