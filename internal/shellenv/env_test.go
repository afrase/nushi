package shellenv

import (
	"slices"
	"testing"
)

func TestOffIsBaseAlone(t *testing.T) {
	e := Off([]string{"PATH=/fake/bin", "NUSHI_DATA=/x"})
	e.Start()
	e.Refresh(t.Context(), 0)
	if got := e.Environ(); !slices.Contains(got, "PATH=/fake/bin") {
		t.Fatalf("Environ() = %v, want the base PATH", got)
	}
	if st := e.Status(); !st.Read.IsZero() || st.Problem != "" {
		t.Fatalf("Status() = %+v: never read", st)
	}
}
