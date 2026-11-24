package relayupdate

import (
	"runtime"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// The real verifier passes a real program of this machine's that answers
// as the version, and refuses one that answers otherwise.
func TestCheckBinaryOnLinux(t *testing.T) {
	if _, ok := machines[runtime.GOARCH]; !ok {
		t.Skip("a release has no relay for " + runtime.GOARCH)
	}
	prog := fakeRelay(t, "linux", runtime.GOARCH, "1.3.0")
	testcheck.NoErr(t, CheckBinary(t.Context(), prog, "1.3.0"))
	if err := CheckBinary(t.Context(), prog, "1.3.1"); err == nil {
		t.Error("the wrong version passed")
	}
}
