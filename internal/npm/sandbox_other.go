//go:build !darwin && !linux

package npm

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"runtime"
)

// writingOnlyIn fails: this OS has no sandbox to keep npm's writes in dir,
// and npm doesn't run without one.
func writingOnlyIn(context.Context, string, string, ...string) (*exec.Cmd, error) {
	return nil, fmt.Errorf("installing with npm on %s: no sandbox: %w", runtime.GOOS, errors.ErrUnsupported)
}
