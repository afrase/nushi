//go:build !darwin && !linux

package claudemcp

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
)

// Terminal has no script(1) whose arguments are known here.
func Terminal(context.Context, []string, ...string) (*exec.Cmd, error) {
	return nil, fmt.Errorf("no terminal for a sign-in on this system: %w", errors.ErrUnsupported)
}
