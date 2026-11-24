//go:build unix

package main

import (
	"context"
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/procgroup"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/testcheck"
)

// loginShellNamed writes a fake login shell called name into a new
// folder: profile runs in every login shell, rc only in an interactive
// one (as zsh's .zprofile and .zshrc, or fish's config.fish and its
// `status is-interactive` block), then it runs the line it was given.
func loginShellNamed(t *testing.T, name, profile, rc string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), name)
	testcheck.Write(t, path, `#!/bin/sh
if [ "$1 $2 $3" = "-l -i -c" ]; then i=1; line=$4
elif [ "$1 $2" = "-l -c" ]; then i=; line=$3
else echo "wrong flags: $*" >&2; exit 64
fi
`+profile+`
if [ -n "$i" ]; then :
`+rc+`
fi
exec /bin/sh -c "$line"
`)
	testcheck.NoErr(t, os.Chmod(path, 0o700))
	return path
}

// startDaemon starts this test binary as the app's launcher starts the
// daemon (nushid -login, the data folder in NUSHID_DATA as Linux's app
// passes it), from launcher's environment, with shell the user's login
// shell and timeout shellenv's cap, and says what the daemon started with; false when it hadn't started once hold was over. It fails
// the test when the daemon left the data folder the launcher chose.
func startDaemon(t *testing.T, shell string, launcher []string, timeout, hold time.Duration) (started, bool) {
	t.Helper()
	dir := t.TempDir()
	report := filepath.Join(t.TempDir(), "report.json")
	self, err := os.Executable()
	testcheck.NoErr(t, err)
	env := append(slices.Clone(launcher), "NUSHID_DATA="+dir,
		startedReport+"="+report, startedShell+"="+shell, startedTimeout+"="+timeout.String())
	ctx, cancel := context.WithTimeout(t.Context(), hold)
	defer cancel()
	cmd := exec.CommandContext(ctx, self)
	cmd.Env = env
	procgroup.Bound(cmd) // a shell that hangs goes with what it started
	_ = cmd.Run()        // how it ended is in the report, or in there being none
	b, err := os.ReadFile(report)
	if errors.Is(err, fs.ErrNotExist) {
		return started{}, false
	}
	testcheck.NoErr(t, err)
	var s started
	testcheck.NoErr(t, json.Unmarshal(b, &s))
	if s.Folder != dir {
		t.Errorf("the data folder is %s, not the launcher's %s", s.Folder, dir)
	}
	return s, true
}

// picked are the variables the cases below look at; the rest (HOME, what
// a shell sets for itself) aren't what they're about.
var picked = []string{"PATH", "LAUNCHER", "FROM_PROFILE", "FROM_RC", "NUSHI_DATA", "XDG_DATA_HOME"}

// pick is env's picked variables, "" for one it hasn't.
func pick(env []string) map[string]string {
	m := map[string]string{}
	for _, name := range picked {
		m[name] = shellenv.Get(env, name)
	}
	return m
}

// vars is picked's variables, "" but for those kv sets ("NAME=value").
func vars(kv ...string) map[string]string {
	m := map[string]string{}
	for _, name := range picked {
		m[name] = ""
	}
	for _, v := range kv {
		name, value, _ := strings.Cut(v, "=")
		m[name] = value
	}
	return m
}

// What the daemon's own environment and an agent's are when the app's
// launcher starts it (nushid -login) from launchd's bare environment, for
// login shells that set things in their profile, only when interactive,
// print, hang or fail, and with NUSHI_SHELL_ENV=off. The daemon has what
// its agents have: the interactive shell's, else a plain login shell's,
// else its launcher's (ADR 0048).
func TestWhatTheDaemonStartsWith(t *testing.T) {
	zshProfile := `export PATH="/profile/bin:$PATH" FROM_PROFILE=yes NUSHI_DATA=/profile/nushi XDG_DATA_HOME=/profile/data`
	zshRC := `export PATH="/rc/bin:$PATH" FROM_RC=yes`
	// fish_add_path adds a folder once.
	fishConfig := `case ":$PATH:" in *:/fish/bin:*) ;; *) export PATH="/fish/bin:$PATH" ;; esac`
	const long, short = time.Minute, 500 * time.Millisecond
	for _, c := range []struct {
		name, shell, profile, rc string
		off                      bool          // the launcher sets NUSHI_SHELL_ENV to off
		timeout, hold            time.Duration // shellenv's cap; how long the test waits for a start
		started                  bool
		daemon, agent            map[string]string
		problem                  string // what Settings › Agents says went wrong, in part
	}{
		{
			name: "a profile and an rc", shell: "zsh", profile: zshProfile, rc: zshRC, timeout: long, hold: long, started: true,
			// The profile's NUSHI_DATA is Nushi's own: never the daemon's (its dev mode).
			daemon: vars("PATH=/rc/bin:/profile/bin:/usr/bin:/bin", "LAUNCHER=yes", "FROM_PROFILE=yes", "FROM_RC=yes", "XDG_DATA_HOME=/profile/data"),
			agent:  vars("PATH=/rc/bin:/profile/bin:/usr/bin:/bin", "LAUNCHER=yes", "FROM_PROFILE=yes", "FROM_RC=yes", "XDG_DATA_HOME=/profile/data"),
		},
		{
			name: "fish", shell: "fish", profile: fishConfig, rc: "export FROM_RC=yes", timeout: long, hold: long, started: true,
			daemon: vars("PATH=/fish/bin:/usr/bin:/bin", "LAUNCHER=yes", "FROM_RC=yes"),
			agent:  vars("PATH=/fish/bin:/usr/bin:/bin", "LAUNCHER=yes", "FROM_RC=yes"),
		},
		{
			name: "a profile that prints", shell: "zsh", timeout: long, hold: long, started: true,
			profile: `echo "Welcome, friend"; echo "a warning" >&2; printf 'nushi-env-start-0000 noise\0'; export FROM_PROFILE=yes`,
			daemon:  vars("PATH=/usr/bin:/bin", "LAUNCHER=yes", "FROM_PROFILE=yes"),
			agent:   vars("PATH=/usr/bin:/bin", "LAUNCHER=yes", "FROM_PROFILE=yes"),
		},
		{
			name: "a profile that hangs", shell: "zsh", profile: "sleep 300", timeout: short, hold: long, started: true,
			daemon:  vars("PATH=/usr/bin:/bin", "LAUNCHER=yes"),
			agent:   vars("PATH=/usr/bin:/bin", "LAUNCHER=yes"),
			problem: "zsh took over 500ms",
		},
		{
			name: "an rc that hangs", shell: "zsh", profile: "export FROM_PROFILE=yes", rc: "sleep 300", timeout: short, hold: long, started: true,
			daemon:  vars("PATH=/usr/bin:/bin", "LAUNCHER=yes", "FROM_PROFILE=yes"),
			agent:   vars("PATH=/usr/bin:/bin", "LAUNCHER=yes", "FROM_PROFILE=yes"),
			problem: "zsh took over 500ms",
		},
		{
			name: "a profile that fails", shell: "zsh", profile: "exit 3", timeout: long, hold: long, started: true,
			daemon:  vars("PATH=/usr/bin:/bin", "LAUNCHER=yes"),
			agent:   vars("PATH=/usr/bin:/bin", "LAUNCHER=yes"),
			problem: "zsh exited with status 3 before printing its environment",
		},
		{
			name: "an rc that fails", shell: "zsh", profile: "export FROM_PROFILE=yes", rc: "exit 3", timeout: long, hold: long, started: true,
			daemon:  vars("PATH=/usr/bin:/bin", "LAUNCHER=yes", "FROM_PROFILE=yes"),
			agent:   vars("PATH=/usr/bin:/bin", "LAUNCHER=yes", "FROM_PROFILE=yes"),
			problem: "zsh exited with status 3 before printing its environment",
		},
		{
			name: "NUSHI_SHELL_ENV=off", shell: "zsh", profile: zshProfile, rc: zshRC, off: true, timeout: long, hold: long, started: true,
			// The environment the daemon was started with: no shell runs.
			daemon: vars("PATH=/usr/bin:/bin", "LAUNCHER=yes"),
			agent:  vars("PATH=/usr/bin:/bin", "LAUNCHER=yes"),
		},
	} {
		t.Run(c.name, func(t *testing.T) {
			t.Parallel()
			launcher := []string{"PATH=/usr/bin:/bin", "HOME=" + t.TempDir(), "LAUNCHER=yes"} // launchd's, and the launcher's own
			if c.off {
				launcher = append(launcher, "NUSHI_SHELL_ENV=off")
			}
			s, ok := startDaemon(t, loginShellNamed(t, c.shell, c.profile, c.rc), launcher, c.timeout, c.hold)
			if ok != c.started {
				t.Fatalf("started: %v", ok)
			}
			if !ok {
				return
			}
			if got := pick(s.Daemon); !mapsEqual(got, c.daemon) {
				t.Errorf("the daemon's own:\n%v\nwant\n%v", got, c.daemon)
			}
			if got := pick(s.Agent); !mapsEqual(got, c.agent) {
				t.Errorf("an agent's:\n%v\nwant\n%v", got, c.agent)
			}
			if !strings.Contains(s.Problem, c.problem) || (c.problem == "") != (s.Problem == "") {
				t.Errorf("problem %q, want %q", s.Problem, c.problem)
			}
			if slices.ContainsFunc(s.Agent, func(kv string) bool { return strings.HasPrefix(kv, "NUSHI") }) {
				t.Errorf("an agent gets Nushi's own variables: %q", s.Agent)
			}
		})
	}
}

// Claude's history folder is read from the environment the daemon has
// once the login shell's is applied: a CLAUDE_CONFIG_DIR the user's
// profile or rc exports is where the daemon looks for Claude's sessions,
// as their agents write them.
func TestClaudesHistoryFolderIsTheShells(t *testing.T) {
	home := t.TempDir()
	for name, c := range map[string]struct{ profile, rc, want string }{
		"in the profile": {profile: "export CLAUDE_CONFIG_DIR=/profile/claude", want: "/profile/claude/projects"},
		"in the rc":      {rc: "export CLAUDE_CONFIG_DIR=/rc/claude", want: "/rc/claude/projects"},
		"nowhere":        {want: filepath.Join(home, ".claude", "projects")},
	} {
		t.Run(name, func(t *testing.T) {
			launcher := []string{"PATH=/usr/bin:/bin", "HOME=" + home}
			s, ok := startDaemon(t, loginShellNamed(t, "zsh", c.profile, c.rc), launcher, time.Minute, time.Minute)
			if !ok {
				t.Fatal("it didn't start")
			}
			if s.Projects != c.want {
				t.Errorf("Claude's projects are in %s, want %s", s.Projects, c.want)
			}
		})
	}
}

// A variable the launcher passes and the user's profile or rc unsets
// (Linux's desktop session passes its whole environment: a proxy, an
// SSH_ASKPASS) is gone for the daemon and its agents, as it was when the
// daemon started through the login shell. One the shell keeps, or every
// variable when no reading worked, stays.
func TestAVariableTheShellUnsetsIsGone(t *testing.T) {
	for name, c := range map[string]struct {
		profile, rc string
		timeout     time.Duration
		want        string
	}{
		"unset in the profile": {profile: "unset HTTP_PROXY", timeout: time.Minute},
		"unset in the rc":      {rc: "unset HTTP_PROXY", timeout: time.Minute},
		"kept":                 {profile: "export FROM_PROFILE=yes", timeout: time.Minute, want: "http://launcher:1"},
		"no reading worked":    {profile: "unset HTTP_PROXY; exit 3", timeout: time.Minute, want: "http://launcher:1"},
	} {
		t.Run(name, func(t *testing.T) {
			launcher := []string{"PATH=/usr/bin:/bin", "HOME=" + t.TempDir(), "HTTP_PROXY=http://launcher:1"}
			s, ok := startDaemon(t, loginShellNamed(t, "bash", c.profile, c.rc), launcher, c.timeout, time.Minute)
			if !ok {
				t.Fatal("it didn't start")
			}
			if got := shellenv.Get(s.Daemon, "HTTP_PROXY"); got != c.want {
				t.Errorf("the daemon's HTTP_PROXY is %q, want %q", got, c.want)
			}
			if got := shellenv.Get(s.Agent, "HTTP_PROXY"); got != c.want {
				t.Errorf("an agent's HTTP_PROXY is %q, want %q", got, c.want)
			}
			if shellenv.Get(s.Daemon, "HOME") == "" || shellenv.Get(s.Agent, "PWD") != shellenv.Get(s.Daemon, "PWD") {
				t.Errorf("the daemon's own HOME or PWD went: %q", s.Daemon)
			}
		})
	}
}

// limitsShell writes a fake login shell whose profile runs in the shell
// that then runs the reading's line (so a function it defines stands in
// for umask or ulimit, as a user's own may).
func limitsShell(t *testing.T, profile string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "bash")
	testcheck.Write(t, path, `#!/bin/sh
if [ "$1 $2 $3" = "-l -i -c" ]; then line=$4
elif [ "$1 $2" = "-l -c" ]; then line=$3
else echo "wrong flags: $*" >&2; exit 64
fi
`+profile+`
eval "$line"
`)
	testcheck.NoErr(t, os.Chmod(path, 0o700))
	return path
}

// launched is the umask and soft open-files limit a process this test
// starts has (Go gives a child the limit it was itself started with).
func launched(t *testing.T) (umask string, openFiles int) {
	t.Helper()
	out, err := exec.CommandContext(t.Context(), "/bin/sh", "-c", "umask; ulimit -S -n").Output()
	testcheck.NoErr(t, err)
	lines := strings.Fields(string(out))
	if len(lines) != 2 {
		t.Fatalf("sh printed %q", out)
	}
	n, err := strconv.Atoi(lines[1])
	if err != nil {
		n = -1 // unlimited
	}
	return lines[0], n
}

// A umask and an open-files limit the user's profile sets reach every
// agent, as when the daemon started through the login shell (on Mac and
// Linux; Windows has neither). No setting, or one the daemon can't read,
// leaves both as the daemon was launched with.
func TestAgentsGetTheShellsUmaskAndOpenFiles(t *testing.T) {
	umask, openFiles := launched(t)
	want := 4096
	if openFiles == want {
		want = 4000
	}
	limits := func(umask string, openFiles int) string {
		if openFiles < 0 {
			return umask + "\nunlimited\n"
		}
		return umask + "\n" + strconv.Itoa(openFiles) + "\n"
	}
	for name, c := range map[string]struct{ profile, want string }{
		"set":     {"umask 077; ulimit -S -n " + strconv.Itoa(want), limits("0077", want)},
		"not set": {"", limits(umask, openFiles)},
		"garbage": {"umask() { echo 0x9z; }; ulimit() { echo lots; }", limits(umask, openFiles)},
	} {
		t.Run(name, func(t *testing.T) {
			launcher := []string{"PATH=/usr/bin:/bin", "HOME=" + t.TempDir()}
			s, ok := startDaemon(t, limitsShell(t, c.profile), launcher, time.Minute, time.Minute)
			if !ok {
				t.Fatal("it didn't start")
			}
			if s.AgentLimits != c.want || s.Problem != "" {
				t.Errorf("an agent has umask and open files %q, want %q (problem %q)", s.AgentLimits, c.want, s.Problem)
			}
		})
	}
}

func mapsEqual(a, b map[string]string) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		if w, ok := b[k]; !ok || w != v {
			return false
		}
	}
	return true
}
