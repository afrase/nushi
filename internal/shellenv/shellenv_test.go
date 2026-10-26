package shellenv

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"
)

// fakeShell writes a shell named name into a new folder: it checks it was
// asked for a login, interactive shell, prints what a noisy config would
// (a mark of the wrong reading among it), then runs the line with sh,
// ONLY_IN_SHELL exported and PATH grown, as a config would.
func fakeShell(t *testing.T, name, body string) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, name)
	script := "#!/bin/sh\n" + body + "\n" +
		`[ "$1 $2 $3" = "-l -i -c" ] || { echo "wrong flags: $*" >&2; exit 64; }
echo "Welcome to $0, friend"
printf 'nushi-env-start-0000 noise\0'
export ONLY_IN_SHELL='a value
on two lines' PATH="/shell/bin:$PATH" SHLVL=9
exec /bin/sh -c "$4"
`
	if err := os.WriteFile(path, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestReadSkipsWhatTheConfigPrints(t *testing.T) {
	for _, name := range []string{"fish", "zsh"} {
		vars, err := Read(context.Background(), fakeShell(t, name, ""), []string{"PATH=/usr/bin:/bin", "BASE=1", "NUSHI_DATA=/d"}, 5*time.Second)
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if got := Get(vars, "ONLY_IN_SHELL"); got != "a value\non two lines" {
			t.Errorf("%s: ONLY_IN_SHELL %q", name, got)
		}
		if got := Get(vars, "PATH"); got != "/shell/bin:/usr/bin:/bin" {
			t.Errorf("%s: PATH %q", name, got)
		}
		if Get(vars, "BASE") != "1" || Get(vars, Resolving) != "" || Get(vars, "NUSHI_DATA") != "" || Get(vars, "SHLVL") != "" {
			t.Errorf("%s: %q", name, vars)
		}
	}
}

func TestParse(t *testing.T) {
	out := "noise nushi-env-start-x\x00echoed\nnushi-env-start-xA=1\x00B=two\nlines\x00=bad\x00noequals\x00_=/usr/bin/env\x00NUSHID_BIN=/n\x00C=\x00nushi-env-end-x"
	vars, err := parse([]byte(out), "nushi-env-start-x", "nushi-env-end-x")
	if err != nil || !slices.Equal(vars, []string{"A=1", "B=two\nlines", "C="}) {
		t.Errorf("%q, %v", vars, err)
	}
	for _, bad := range []string{"", "nushi-env-start-x A=1", "A=1 nushi-env-end-x"} {
		if _, err := parse([]byte(bad), "nushi-env-start-x", "nushi-env-end-x"); err == nil {
			t.Errorf("%q: no error", bad)
		}
	}
}

func TestReadFails(t *testing.T) {
	base := []string{"PATH=/usr/bin:/bin"}
	for _, c := range []struct{ body, want string }{
		{"sleep 30", "zsh took over 1s"},
		{"exit 3", "zsh exited with status 3 before printing its environment"},
		{"echo all is well; exit 0", "zsh: no environment in what it printed"},
	} {
		start := time.Now()
		_, err := Read(context.Background(), fakeShell(t, "zsh", c.body), base, time.Second)
		if err == nil || err.Error() != c.want {
			t.Errorf("%q: %v", c.body, err)
		}
		if time.Since(start) > 3*time.Second {
			t.Errorf("%q took %s", c.body, time.Since(start))
		}
	}
	if _, err := Read(context.Background(), "/no/such/shell", base, time.Second); err == nil || !strings.Contains(err.Error(), "couldn't start") {
		t.Errorf("a missing shell: %v", err)
	}
}

// The real shells that are here, each with a config of its own in a temp
// home printing first and exporting a variable.
func TestRealShells(t *testing.T) {
	home := t.TempDir()
	files := map[string]string{
		".zshrc":                    "echo zsh says hi\nexport ONLY_IN_SHELL=zsh",
		".bash_profile":             "echo bash says hi\nexport ONLY_IN_SHELL=bash",
		".config/fish/config.fish":  "echo fish says hi\nif status is-interactive; set -gx ONLY_IN_SHELL fish; end",
		".local/share/fish/.keep":   "",
		"Library/Preferences/.keep": "",
	}
	for name, body := range files {
		p := filepath.Join(home, name)
		if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body+"\n"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	base := []string{"HOME=" + home, "PATH=/usr/bin:/bin:/usr/sbin:/sbin", "XDG_CONFIG_HOME=" + filepath.Join(home, ".config"),
		"XDG_DATA_HOME=" + filepath.Join(home, ".local", "share"), "ZDOTDIR=" + home}
	for _, name := range []string{"zsh", "bash", "fish"} {
		shell, err := exec.LookPath(name)
		if err != nil {
			t.Logf("no %s here", name)
			continue
		}
		vars, err := Read(context.Background(), shell, base, 10*time.Second)
		if err != nil || Get(vars, "ONLY_IN_SHELL") != name || Get(vars, "HOME") != home {
			t.Errorf("%s: %v, ONLY_IN_SHELL=%q", name, err, Get(vars, "ONLY_IN_SHELL"))
		}
	}
}

func TestMergeAndOwn(t *testing.T) {
	got := Merge([]string{"PATH=/usr/bin", "HOME=/h", "NUSHI_DATA=/d", "NUSHID_LOG=/l", "KEEP=1"},
		[]string{"PATH=/shell/bin:/usr/bin", "KEY=k", "NUSHI_TOOLS_KEY=t", "NUSHI_SOCKET=/s"})
	if !slices.Equal(got, []string{"PATH=/shell/bin:/usr/bin", "HOME=/h", "KEEP=1", "KEY=k"}) {
		t.Errorf("%q", got)
	}
}

func TestLookPath(t *testing.T) {
	dir := t.TempDir()
	prog := filepath.Join(dir, "node")
	if err := os.WriteFile(prog, []byte("#!/bin/sh\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "plain"), nil, 0o600); err != nil {
		t.Fatal(err)
	}
	env := []string{"PATH=/nowhere::" + dir}
	if LookPath("node", env) != prog || LookPath("plain", env) != "" || LookPath("node", nil) != "" || LookPath(prog, nil) != prog {
		t.Error("LookPath")
	}
}

func TestEnv(t *testing.T) {
	shell := fakeShell(t, "fish", `[ -e "$HANG" ] && sleep 30`)
	hang := filepath.Join(t.TempDir(), "hang")
	e := New(shell, []string{"PATH=/usr/bin:/bin", "ONLY_IN_SHELL=daemon's", "NUSHI_DATA=/d", "HANG=" + hang})
	e.Start()
	env := e.Environ()
	if Get(env, "ONLY_IN_SHELL") != "a value\non two lines" || Get(env, "NUSHI_DATA") != "" || e.Status().Problem != "" || e.Status().Read.IsZero() {
		t.Fatalf("%q, %+v", env, e.Status())
	}
	if e.LookPath("sh") != "/bin/sh" {
		t.Error("LookPath")
	}
	// Read again only when older than asked; a failure keeps the last
	// reading and says why.
	if err := os.WriteFile(hang, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	Timeout = 500 * time.Millisecond
	defer func() { Timeout = 5 * time.Second }()
	read := e.Status().Read
	e.Refresh(context.Background(), time.Minute)
	if e.Status().Read != read {
		t.Error("read again within the minute")
	}
	e.Refresh(context.Background(), 0)
	if st := e.Status(); st.Problem != "fish took over 500ms" || Get(e.Environ(), "ONLY_IN_SHELL") != "a value\non two lines" {
		t.Errorf("%+v", st)
	}
}

// A shell that never worked leaves the daemon's environment.
func TestEnvFallsBack(t *testing.T) {
	Timeout = 500 * time.Millisecond
	defer func() { Timeout = 5 * time.Second }()
	e := New(fakeShell(t, "zsh", "sleep 30"), []string{"PATH=/usr/bin:/bin", "A=1", "NUSHI_LOG=debug"})
	e.Start()
	if env := e.Environ(); !slices.Equal(env, []string{"PATH=/usr/bin:/bin", "A=1"}) || e.Status().Problem == "" {
		t.Errorf("%q, %+v", env, e.Status())
	}
}
