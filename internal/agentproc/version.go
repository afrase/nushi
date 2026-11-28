package agentproc

import (
	"context"
	"fmt"
	"os/exec"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/procgroup"
)

// Version is what `bin --version` printed, trimmed: a bridge's check of
// the program it speaks to (Ante's host, pi). It has 10 s.
func Version(bin string) (string, error) {
	out, err := Output(bin, nil, "", "--version")
	return strings.TrimSpace(string(out)), err
}

// Output is what `bin args...` printed on stdout, its stdin empty: a
// bridge asking the program what it is. env, when not nil, is its whole
// environment, and dir, when not "", its working folder (Bare's); nil
// and "", this process's. It has 10 s, and what it started ends with it.
func Output(bin string, env []string, dir string, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, args...) //nolint:gosec // the agent's own CLI, asked what it is
	cmd.Env, cmd.Dir = env, dir
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("couldn't run %s %s: %w", bin, strings.Join(args, " "), err)
	}
	return out, nil
}

// Bare is an environment of env's PATH and set alone, and set's HOME as
// the working folder ("" when set has none): for a run that must reach no
// key and none of the user's settings, and read no folder of theirs (a
// program that took its arguments for a prompt would read the working
// folder's AGENTS.md and name the folder).
func Bare(env, set []string) (environ []string, dir string) {
	environ = slices.Clone(set)
	for _, kv := range set {
		if home, ok := strings.CutPrefix(kv, "HOME="); ok {
			dir = home
		}
	}
	for _, kv := range env {
		if strings.HasPrefix(kv, "PATH=") {
			environ = append(environ, kv)
		}
	}
	return environ, dir
}

// Numbers reads a version's three numbers, a prerelease's tag left out;
// nil if it hasn't three.
func Numbers(v string) []int {
	v, _, _ = strings.Cut(v, "-")
	parts := strings.Split(v, ".")
	if len(parts) != 3 {
		return nil
	}
	out := make([]int, 3)
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil {
			return nil
		}
		out[i] = n
	}
	return out
}

// Older says version v comes before least, by their first three numbers: a
// part left out counts as 0 ("2.1" is 2.1.0), and a pre-release's tag or
// build metadata is left out ("0.3.0-rc.1" is 0.3.0, so it meets a
// minimum of 0.3.0). A version that isn't one, or a minimum, is an error.
func Older(v, least string) (bool, error) {
	got, err := triple(v)
	if err != nil {
		return false, err
	}
	want, err := triple(least)
	if err != nil {
		return false, err
	}
	return slices.Compare(got[:], want[:]) < 0, nil
}

// triple is a version's first three numbers, a part left out 0.
func triple(v string) ([3]int, error) {
	var out [3]int
	core := v
	if i := strings.IndexAny(core, "-+"); i >= 0 {
		core = core[:i]
	}
	parts := strings.Split(core, ".")
	if len(parts) > 3 {
		parts = parts[:3]
	}
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil || strings.Trim(p, "0123456789") != "" { // Atoi takes a sign
			return out, fmt.Errorf("%q isn't a version", v)
		}
		out[i] = n
	}
	return out, nil
}
