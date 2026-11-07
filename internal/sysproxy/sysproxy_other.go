//go:build !darwin

package sysproxy

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"runtime"
	"time"
)

// systemLookup reads no settings on this OS: a direct connection.
func systemLookup(*url.URL, bool) ([]*url.URL, time.Duration) {
	return []*url.URL{nil}, 5 * time.Minute
}

// evaluate can't run a PAC file on this OS.
func evaluate(context.Context, []byte, url.URL) ([]*url.URL, error) {
	return nil, fmt.Errorf("evaluating a PAC file on %s: %w", runtime.GOOS, errors.ErrUnsupported)
}
