package footprint

import (
	"os"
	"os/exec"
	"slices"
	"testing"
)

func TestTree(t *testing.T) {
	child := exec.Command("sleep", "5")
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = child.Process.Kill() })
	self := Of(os.Getpid())
	p, err := Snapshot()
	if err != nil {
		t.Fatal(err)
	}
	if self == 0 || !slices.Contains(p.Children(os.Getpid()), child.Process.Pid) || p.Tree(os.Getpid()) <= self {
		t.Errorf("self %d, children %v, tree %d", self, p.Children(os.Getpid()), p.Tree(os.Getpid()))
	}
	if Of(1) != 0 { // launchd: another user's
		t.Error("read launchd's footprint")
	}
}
