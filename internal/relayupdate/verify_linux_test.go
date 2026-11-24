package relayupdate

import (
	"context"
	"runtime"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// The real verifier passes a real program of this machine's, reading it
// only, and stops once the update's context has ended.
func TestCheckBinaryOnLinux(t *testing.T) {
	if _, ok := machines[runtime.GOARCH]; !ok {
		t.Skip("a release has no relay for " + runtime.GOARCH)
	}
	prog := fakeRelay(t, "linux", runtime.GOARCH)
	testcheck.NoErr(t, CheckBinary(t.Context(), prog))
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	if err := CheckBinary(ctx, prog); err == nil {
		t.Error("an ended update passed")
	}
}
