//go:build !darwin && !linux

package sysproxy

import (
	"net/url"
	"time"
)

// systemLookup reads no settings on this OS: a direct connection.
func systemLookup(*url.URL, bool) ([]*url.URL, time.Duration) {
	return []*url.URL{nil}, 5 * time.Minute
}
