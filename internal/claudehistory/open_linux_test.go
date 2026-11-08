package claudehistory

import (
	"os"
	"os/exec"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// started agrees with ps's lstart, which Claude Code records as
// procStart (ps -o lstart= in the C locale, in UTC).
func TestStartedIsLstart(t *testing.T) {
	ps, err := exec.LookPath("ps")
	if err != nil {
		t.Skip("no ps to compare with")
	}
	cmd := exec.Command(ps, "-o", "lstart=", "-p", strconv.Itoa(os.Getpid()))
	cmd.Env = append(os.Environ(), "LC_ALL=C", "TZ=UTC")
	out, err := cmd.Output()
	if err != nil {
		t.Skipf("ps doesn't give lstart (busybox's?): %v", err)
	}
	want, err := time.ParseInLocation("Mon Jan 2 15:04:05 2006", strings.Join(strings.Fields(string(out)), " "), time.UTC)
	testcheck.NoErr(t, err)
	got, ok := started(os.Getpid())
	if !ok || !got.Truncate(time.Second).Equal(want) {
		t.Fatalf("started %v %v, ps says %v", got, ok, want)
	}
}

// The domain is Claude Code's shape on Linux: darwin, the machine id and
// the pid namespace's link.
func TestDomain(t *testing.T) {
	d := domain()
	if !strings.HasPrefix(d, "darwin:") || !strings.HasSuffix(d, "]") || strings.Count(d, ":") != 3 {
		t.Fatalf("domain %q", d)
	}
}
