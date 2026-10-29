package mdwrite

import (
	"strings"
	"testing"
	"time"
)

// TestFenceOfALongRun: a fence is longer than the longest run of
// backticks it holds, found in one pass; growing it one Contains at a
// time took minutes on a long run.
func TestFenceOfALongRun(t *testing.T) {
	start := time.Now()
	run := strings.Repeat("`", 1<<20)
	got := Fence("a ``` b "+run, "")
	if !strings.HasPrefix(got, run+"`\n") || !strings.HasSuffix(got, "\n"+run+"`") {
		t.Fatalf("fence of %d", strings.Index(got, "\n"))
	}
	if Fence("x", "go") != "```go\nx\n```" || Code("a`b") != "``a`b``" || Code("``") != "``` `` ```" {
		t.Fatal(Fence("x", "go"), Code("a`b"), Code("``"))
	}
	if d := time.Since(start); d > 2*time.Second {
		t.Fatalf("took %s", d)
	}
}
