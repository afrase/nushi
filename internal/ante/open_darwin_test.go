package ante

import "time"

// lsof has taken longer than the app waits for it on a CI Mac busy with
// every package's tests: a test waits for its answer, however long.
func init() { //nolint:gochecknoinits // a per-OS setting of the shared tests, which build everywhere
	lsofTimeout = time.Minute
}
