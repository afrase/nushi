package filelock

import (
	"os"
	"path/filepath"
	"testing"

	"golang.org/x/sys/unix"
)

func TestHeld(t *testing.T) {
	path := filepath.Join(t.TempDir(), "x.lock")
	if err := os.WriteFile(path, nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if Held(path) || Held(path+".none") {
		t.Fatal("held before anyone locked it")
	}
	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := unix.Flock(int(f.Fd()), unix.LOCK_EX); err != nil {
		t.Fatal(err)
	}
	if !Held(path) {
		t.Error("a flock lock wasn't seen")
	}
	if err := f.Close(); err != nil { // lets go
		t.Fatal(err)
	}
	if Held(path) {
		t.Error("held after it was let go")
	}
}
