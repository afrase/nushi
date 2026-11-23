package testcheck

import (
	"fmt"
	"testing"
)

// ended is a test that records how Lacks ended it, without ending this one.
type ended struct {
	testing.TB
	fatal, skip string
}

func (e *ended) Helper()                        {}
func (e *ended) Fatalf(format string, a ...any) { e.fatal = fmt.Sprintf(format, a...) }
func (e *ended) Skip(a ...any)                  { e.skip = a[0].(string) }

// Lacks fails in CI and skips elsewhere, saying what was missing.
func TestLacks(t *testing.T) {
	t.Setenv("CI", "true")
	e := &ended{TB: t}
	Lacks(e, "no gio here")
	if e.fatal != "in CI, whose jobs should have it: no gio here" {
		t.Errorf("in CI it failed with %q", e.fatal)
	}
	t.Setenv("CI", "")
	e = &ended{TB: t}
	Lacks(e, "no gio here")
	if e.fatal != "" || e.skip != "no gio here" {
		t.Errorf("outside CI: fatal %q, skip %q", e.fatal, e.skip)
	}
}
