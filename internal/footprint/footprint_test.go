package footprint

import (
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// This process's footprint reads, a child it started is among its
// children, and the tree's is more than this process's alone.
func TestTree(t *testing.T) {
	child := exec.Command("sleep", "5")
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = child.Process.Kill(); _ = child.Wait() })
	self := Of(os.Getpid())
	p, err := Snapshot()
	if err != nil {
		t.Fatal(err)
	}
	if self == 0 || !slices.Contains(p.Children(os.Getpid()), child.Process.Pid) || p.Tree(os.Getpid()) <= self {
		t.Errorf("self %d, children %v, tree %d", self, p.Children(os.Getpid()), p.Tree(os.Getpid()))
	}
}

// The samples are a real cat's smaps_rollup and status, their swap
// figures made up (the machine had none in use).
func TestSumKB(t *testing.T) {
	read := func(name string) []byte {
		b, err := os.ReadFile(filepath.Join("testdata", name))
		testcheck.NoErr(t, err)
		return b
	}
	for _, tc := range []struct {
		file  string
		names []string
		want  uint64
		ok    bool
	}{
		{"smaps_rollup", []string{"Pss", "SwapPss"}, (1959 + 12) << 10, true},
		{"smaps_rollup", []string{"Pss_Anon"}, 1148 << 10, true},           // not taken for Pss
		{"smaps_rollup", []string{"Pss", "NoSuchField"}, 1959 << 10, true}, // a later one missing counts 0
		{"status", []string{"VmRSS", "VmSwap"}, (3956 + 34) << 10, true},
		{"status", []string{"Pid"}, 0, false}, // not in kB
		{"status-kthread", []string{"VmRSS", "VmSwap"}, 0, false},
	} {
		if got, ok := sumKB(read(tc.file), tc.names...); got != tc.want || ok != tc.ok {
			t.Errorf("%s %v: %d %v, want %d %v", tc.file, tc.names, got, ok, tc.want, tc.ok)
		}
	}
}
