package homebrew

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// runner is a fake brew: it records what it's asked to run, and each
// command fails with what fail has for its first argument.
type runner struct {
	ran  [][]string
	env  []string
	says map[string]string
	fail map[string]error
}

func (r *runner) run(_ context.Context, env []string, name string, args ...string) ([]byte, error) {
	r.ran = append(r.ran, append([]string{name}, args...))
	r.env = env
	return []byte(r.says[args[0]]), r.fail[args[0]]
}

// mac is a Mac with Homebrew under two temp prefixes and the daemon
// running from /Applications/Nushi.app there; casks are made as
// "<prefix index>/<cask>[/<version>]".
func mac(t *testing.T, casks ...string) (*Brew, *runner) {
	t.Helper()
	root := t.TempDir()
	prefixes := []string{filepath.Join(root, "opt"), filepath.Join(root, "local")}
	for _, c := range casks {
		i, rest, _ := strings.Cut(c, "/")
		p := prefixes[0]
		if i == "1" {
			p = prefixes[1]
		}
		if err := os.MkdirAll(filepath.Join(p, "Caskroom", rest), 0o700); err != nil {
			t.Fatal(err)
		}
	}
	r := &runner{}
	apps := filepath.Join(root, "Applications")
	return &Brew{
		Prefixes: prefixes, Apps: []string{apps}, Exe: filepath.Join(apps, "Nushi.app", "Contents", "Helpers", "Nushi Daemon.app", "Contents", "MacOS", "nushid"),
		Env: func() []string { return []string{"HOME=/Users/me", "NONINTERACTIVE=0"} }, Run: r.run,
	}, r
}

// The cask that installed Nushi is the one whose Caskroom folder is
// there, the beta one first; none without one, and none for a daemon
// that doesn't run from a cask's Nushi.app, though the Mac still follows
// beta versions.
func TestInstalled(t *testing.T) {
	b, _ := mac(t)
	if b.Installed() != "" || b.Beta() {
		t.Fatalf("no cask: %q, beta %v", b.Installed(), b.Beta())
	}
	b, _ = mac(t, "0/nushi")
	if b.Installed() != Cask || b.Beta() {
		t.Fatalf("nushi: %q, beta %v", b.Installed(), b.Beta())
	}
	b, _ = mac(t, "0/nushi", "1/nushi@beta")
	if b.Installed() != BetaCask || !b.Beta() {
		t.Fatalf("both: %q, beta %v", b.Installed(), b.Beta())
	}
	for _, exe := range []string{"", "/Users/me/nushi/bin/nushid", filepath.Dir(b.Apps[0]) + "/Applications/Nushi.app.old/nushid",
		"/Users/me/nushi/app/build/Nushi.app/Contents/Helpers/Nushi Daemon.app/Contents/MacOS/nushid"} {
		b.Exe = exe
		if b.Installed() != "" || !b.Beta() {
			t.Fatalf("running from %q: %q, beta %v", exe, b.Installed(), b.Beta())
		}
	}
}

// A cask has a version when its Caskroom folder has one of that name; a
// name that leads elsewhere is never looked for.
func TestHas(t *testing.T) {
	b, _ := mac(t, "1/nushi@beta/0.29.0-beta.1", "0/other/1.0")
	for _, c := range []struct {
		cask, version string
		want          bool
	}{
		{BetaCask, "0.29.0-beta.1", true},
		{BetaCask, "0.29.0", false},
		{Cask, "0.29.0-beta.1", false},
		{"other", "1.0", false},
		{BetaCask, "", false},
		{BetaCask, ".", false},
		{BetaCask, "..", false},
		{BetaCask, "../nushi@beta/0.29.0-beta.1", false},
		{BetaCask, "0.29.0-beta.1/", false},
	} {
		if got := b.Has(c.cask, c.version); got != c.want {
			t.Errorf("Has(%q, %q) = %v", c.cask, c.version, got)
		}
	}
}

// An upgrade is `brew update`, then `brew upgrade --cask <cask>`, with
// the brew of the prefix that has the cask, in the given environment made
// quiet; any other cask's name runs nothing.
func TestUpgrade(t *testing.T) {
	b, r := mac(t, "1/nushi@beta/0.28.0")
	r.says = map[string]string{"update": "Already up-to-date.\n", "upgrade": "\x1b[34m==>\x1b[0m Upgrading nushi@beta\n"}
	out, err := b.Upgrade(t.Context(), BetaCask)
	if err != nil || out != "Already up-to-date.\n==> Upgrading nushi@beta\n" {
		t.Fatalf("%q %v", out, err)
	}
	brew := filepath.Join(b.Prefixes[1], "bin", "brew")
	if want := [][]string{{brew, "update"}, {brew, "upgrade", "--cask", "nushi@beta"}}; !slices.EqualFunc(r.ran, want, slices.Equal) {
		t.Fatalf("ran %q", r.ran)
	}
	if want := []string{"HOME=/Users/me", "NONINTERACTIVE=0", "NONINTERACTIVE=1", "HOMEBREW_NO_ASK=1", "HOMEBREW_NO_ENV_HINTS=1", "HOMEBREW_NO_COLOR=1"}; !slices.Equal(r.env, want) {
		t.Fatalf("env %q", r.env)
	}
	for _, cask := range []string{Cask, "nushi; rm -rf ~", "--force", "other", ""} {
		r.ran = nil
		if _, err := b.Upgrade(t.Context(), cask); err == nil || r.ran != nil {
			t.Fatalf("cask %q: %v, ran %q", cask, err, r.ran)
		}
	}
}

// A failure stops there and says why in a sentence: brew's own last
// "Error:" line, where to allow it when macOS refused, or how the command
// ended when it printed nothing. The output's end comes back whole.
func TestUpgradeFails(t *testing.T) {
	exit := errors.New("exit status 1")
	for _, c := range []struct {
		name, step, says string
		err              error
		want             string
		ran              int
	}{
		{"brew update", "update", "fatal: unable to access 'https://github.com/Homebrew/brew/'\nError: Fetching /opt/homebrew failed!\n", exit,
			"brew update: Fetching /opt/homebrew failed!", 1},
		{"brew upgrade", "upgrade", "==> Upgrading 1 outdated package\nError: nushi: Download failed on Cask 'nushi' with message: 404\nsome advice\n", exit,
			"brew upgrade: nushi: Download failed on Cask 'nushi' with message: 404", 2},
		{"no Error line", "upgrade", "==> Upgrading\nsomething went wrong\n\n", exit, "brew upgrade: something went wrong", 2},
		{"nothing printed", "update", "", errors.New("fork/exec /opt/homebrew/bin/brew: no such file or directory"),
			"brew update: fork/exec /opt/homebrew/bin/brew: no such file or directory", 1},
		{"App Management, Homebrew's words", "upgrade", "Error: Cannot change the ownership of '/Applications/Nushi.app' because your terminal does not have App Management permissions.\n", exit,
			"System Settings › Privacy & Security › App Management", 2},
		{"App Management, the system's", "upgrade", "Error: Operation not permitted @ apply2files - /Applications/Nushi.app/Contents\n", exit,
			"System Settings › Privacy & Security › App Management", 2},
	} {
		b, r := mac(t, "0/nushi/0.28.0")
		r.says = map[string]string{"update": "Updated 1 tap.\n", c.step: c.says}
		r.fail = map[string]error{c.step: c.err}
		out, err := b.Upgrade(t.Context(), Cask)
		if err == nil || !strings.Contains(err.Error(), c.want) || len(r.ran) != c.ran {
			t.Errorf("%s: %v, ran %q", c.name, err, r.ran)
		}
		if !strings.HasSuffix(out, c.says) {
			t.Errorf("%s: output %q", c.name, out)
		}
	}
	// Out of time, it says so rather than how the kill looked.
	b, r := mac(t, "0/nushi")
	r.fail = map[string]error{"update": errors.New("signal: killed")}
	late, cancel := context.WithTimeout(t.Context(), 0)
	defer cancel()
	if _, err := b.Upgrade(late, Cask); err == nil || err.Error() != "brew update took over 15 minutes" {
		t.Fatalf("out of time: %v", err)
	}
	// brew update's own "Operation not permitted" isn't the app's.
	b, r = mac(t, "0/nushi")
	r.says, r.fail = map[string]string{"update": "Error: Operation not permitted @ rb_sysopen\n"}, map[string]error{"update": exit}
	if _, err := b.Upgrade(t.Context(), Cask); err == nil || err.Error() != "brew update: Operation not permitted @ rb_sysopen" {
		t.Fatalf("brew update refused: %v", err)
	}
	// A token brew printed is hidden, in the sentence and the output.
	r.says = map[string]string{"update": "Error: bad credentials for ghp_" + strings.Repeat("a1B2", 9) + "\n"}
	if out, err := b.Upgrade(t.Context(), Cask); err == nil || strings.Contains(out+err.Error(), "ghp_") {
		t.Fatalf("a token: %q %v", out, err)
	}
	// A long last line is cut.
	b, r = mac(t, "0/nushi")
	r.says, r.fail = map[string]string{"update": "Error: " + strings.Repeat("é", 500)}, map[string]error{"update": exit}
	if _, err := b.Upgrade(t.Context(), Cask); err == nil || len([]rune(err.Error())) > 220 {
		t.Fatalf("a long line: %v", err)
	}
}

// What a command printed is kept from its end only.
func TestTail(t *testing.T) {
	w := &tail{max: 8}
	for _, s := range []string{"0123", "4567", "89ab", "cdefghij", "k"} {
		if n, err := w.Write([]byte(s)); n != len(s) || err != nil {
			t.Fatal(n, err)
		}
	}
	if got := string(w.end()); got != "defghijk" {
		t.Fatalf("%q", got)
	}
	if len(w.buf) > 16 {
		t.Fatalf("kept %d bytes", len(w.buf))
	}
}
