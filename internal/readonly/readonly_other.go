//go:build !darwin

package readonly

import (
	"context"
	"errors"
	"fmt"
	"runtime"
)

// Output runs nothing: this OS has no sandbox to keep the program from
// writing.
func Output(context.Context, []string, string, ...string) ([]byte, error) {
	return nil, fmt.Errorf("running a program read-only on %s: %w", runtime.GOOS, errors.ErrUnsupported)
}
