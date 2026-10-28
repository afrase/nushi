package filelock

import (
	"os"
	"path/filepath"
	"testing"
	"time"

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

func TestLock(t *testing.T) {
	path := filepath.Join(t.TempDir(), "settings.json.lock")
	unlock, err := Lock(path, 0)
	if err != nil {
		t.Fatal(err)
	}
	if !Held(path) {
		t.Error("not held once locked")
	}
	if _, err := Lock(path, 50*time.Millisecond); err == nil {
		t.Error("locked twice")
	}
	go func() { time.Sleep(50 * time.Millisecond); unlock() }()
	again, err := Lock(path, 2*time.Second) // waits for the first to let go
	if err != nil {
		t.Fatal(err)
	}
	again()
}
