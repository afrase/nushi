package filelock

import (
	"os"
	"reflect"
	"testing"
)

// A sample /proc/locks: each kind of lock held, a waiter, a lease and a
// delegation, a device past two hex digits (an NVMe partition's 259:5 is
// 103:05), and lines it can't read.
func TestParseLocks(t *testing.T) {
	b, err := os.ReadFile("testdata/proc-locks")
	if err != nil {
		t.Fatal(err)
	}
	want := []lock{
		{pid: 812, major: 0x00, minor: 0x1a, inode: 1043},
		{pid: 49564, major: 0x00, minor: 0x3b, inode: 98970},
		{pid: -1, major: 0x00, minor: 0x06, inode: 9},
		{pid: 1203, major: 0x103, minor: 0x105, inode: 277315},
		{pid: 1204, major: 0x00, minor: 0x26, inode: 277315},
	}
	if got := parseLocks(b); !reflect.DeepEqual(got, want) {
		t.Errorf("parseLocks =\n%+v\nwant\n%+v", got, want)
	}
	if got := parseLocks(nil); got != nil {
		t.Errorf("parseLocks(nil) = %+v", got)
	}
}

func TestOnFile(t *testing.T) {
	locks := []lock{
		{pid: 49564, major: 0, minor: 0x3b, inode: 98970},
		{pid: 1204, major: 0, minor: 0x26, inode: 277315}, // btrfs: the filesystem's device
		{pid: -1, major: 0, minor: 0x26, inode: 4242},     // an open file description's
	}
	holder := func(want int) func(int) bool { return func(pid int) bool { return pid == want } }
	never := func(int) bool { return false }
	for _, c := range []struct {
		name         string
		major, minor uint32
		inode        uint64
		holds        func(int) bool
		want         bool
	}{
		{"device and inode", 0, 0x3b, 98970, never, true},
		{"another inode", 0, 0x3b, 98971, holder(49564), false},
		{"a subvolume's device, its holder has it open", 0, 0x35, 277315, holder(1204), true},
		{"a subvolume's device, its holder hasn't it open", 0, 0x35, 277315, never, false},
		{"another device, an open file description's", 0, 0x35, 4242, holder(-1), false},
		{"nothing listed", 0, 0x3b, 1, never, false},
	} {
		if got := onFile(locks, c.major, c.minor, c.inode, c.holds); got != c.want {
			t.Errorf("%s: onFile = %v, want %v", c.name, got, c.want)
		}
	}
}
