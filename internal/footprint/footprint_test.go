package footprint

import (
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// childEnv makes this test binary, run again by TestTree, wait to be
// killed instead of running tests.
const childEnv = "NUSHI_FOOTPRINT_HELPER"

func TestMain(m *testing.M) {
	if os.Getenv(childEnv) == "1" {
		time.Sleep(time.Minute)
		os.Exit(0)
	}
	m.Run()
}

// This process's footprint reads, a child it started is among its
// children, and the tree's is more than this process's alone.
func TestTree(t *testing.T) {
	child := exec.Command(os.Args[0])
	child.Env = append(os.Environ(), childEnv+"=1")
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

// A tree whose parent ids loop (ids given again) is walked once.
func TestTreeOfALoop(t *testing.T) {
	p := Processes{children: map[int][]int{os.Getpid(): {1 << 30}, 1 << 30: {os.Getpid()}}}
	if got, want := p.Tree(os.Getpid()), Of(os.Getpid()); got > want+want/2 {
		t.Errorf("tree %d, this process %d", got, want)
	}
}
