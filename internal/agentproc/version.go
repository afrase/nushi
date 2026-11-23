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
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, "--version")
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("couldn't run %s --version: %w", bin, err)
	}
	return strings.TrimSpace(string(out)), nil
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

// Older says version v comes before min, by their first three numbers: a
// part left out counts as 0 ("2.1" is 2.1.0), and a pre-release's tag or
// build metadata is left out ("0.3.0-rc.1" is 0.3.0, so it meets a
// minimum of 0.3.0). A version that isn't one, or a minimum, is an error.
func Older(v, min string) (bool, error) {
	got, err := triple(v)
	if err != nil {
		return false, err
	}
	want, err := triple(min)
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
