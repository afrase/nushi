package git

import (
	"bytes"
	"cmp"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/procgroup"
)

// run runs git in dir, with hooks, fsmonitor, signature checks, external
// diff and textconv drivers, and fetching missing objects (a partial
// clone's promisor remote, whose transport the config picks) off. A folder that was downloaded rather than
// cloned brings its own .git/config, which could set any of them. Clean
// filters still run when git compares the work tree (git diff does), unless
// noFilters turns them off: Changes shows what git shows, as the user's
// own git diff would.
func run(ctx context.Context, dir string, args ...string) ([]byte, error) {
	return runTo(ctx, dir, nil, nil, args...)
}

// runTo is run with the config settings named in blank set empty, and the
// output going to out unless out is nil. The settings go through
// GIT_CONFIG_KEY_<n>, which keeps a name apart from its value whatever it
// holds ("=" too, which -c would split at).
func runTo(ctx context.Context, dir string, blank []string, out io.Writer, args ...string) ([]byte, error) {
	cmd := command(ctx, dir, blank, args...)
	var stdout bytes.Buffer
	cmd.Stdout = cmp.Or[io.Writer](out, &stdout)
	if err := finish(cmd, args[0]); err != nil {
		return nil, err
	}
	return stdout.Bytes(), nil
}

// finish runs cmd, git's subcommand what; when git fails, the error is
// what it said.
func finish(cmd *exec.Cmd, what string) error {
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if _, ok := errors.AsType[*exec.ExitError](err); ok {
			return fmt.Errorf("git %s: %s", what, strings.TrimSpace(stderr.String()))
		}
		return err
	}
	return nil
}

// command is git in dir as run runs it, with the settings named in blank
// set empty, killed with what it started when ctx ends.
func command(ctx context.Context, dir string, blank []string, args ...string) *exec.Cmd {
	global := []string{"-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null", "-c", "log.showSignature=false", "-C", dir}
	cmd := exec.CommandContext(ctx, "git", append(global, args...)...)
	cmd.Env = append(os.Environ(), "GIT_OPTIONAL_LOCKS=0", "GIT_NO_LAZY_FETCH=1", "GIT_CONFIG_COUNT="+strconv.Itoa(len(blank)))
	for i, name := range blank {
		cmd.Env = append(cmd.Env, fmt.Sprintf("GIT_CONFIG_KEY_%d=%s", i, name), fmt.Sprintf("GIT_CONFIG_VALUE_%d=", i))
	}
	procgroup.Bound(cmd)
	return cmd
}

// noFilters returns the config settings to blank that turn off the filter
// drivers a repository's own config defines (filter.<name>.clean, .smudge
// and .process, by the exact names git lists), for the git runs Nushi
// starts on its own. The user's (git-lfs, in the global config) stay. When git
// can't list them, it fails: nothing runs with them on.
func noFilters(ctx context.Context, dir string) ([]string, error) {
	cmd := exec.CommandContext(ctx, "git", "-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null", "-C", dir,
		"config", "--show-scope", "--name-only", "--get-regexp", `^filter\.`)
	cmd.Env = append(os.Environ(), "GIT_NO_LAZY_FETCH=1")
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	var exit *exec.ExitError
	if errors.As(err, &exit) && exit.ExitCode() == 1 && len(exit.Stderr) == 0 {
		return nil, nil // none
	}
	if err != nil {
		return nil, fmt.Errorf("listing the repository's filters: %w", err)
	}
	var config []string
	for line := range strings.Lines(string(out)) {
		scope, name, _ := strings.Cut(strings.TrimSpace(line), "\t")
		key := name[strings.LastIndex(name, ".")+1:]
		if scope != "global" && scope != "system" && (key == "clean" || key == "smudge" || key == "process") {
			config = append(config, name)
		}
	}
	return config, nil
}

// split splits git's NUL-separated output.
func split(out []byte) []string {
	s := strings.TrimSuffix(string(out), "\x00")
	if s == "" {
		return nil
	}
	return strings.Split(s, "\x00")
}
