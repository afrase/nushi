package footprint

import (
	"bytes"
	"strconv"
)

// sumKB adds up the fields names of a /proc file made of "Name: value kB"
// lines (smaps_rollup, status), in bytes. It is false when the first of
// names isn't there (a kernel thread's status has no VmRSS); a later one
// missing counts as 0. It builds on every OS so its tests run on the Mac
// too; only footprint_linux.go reads such files.
func sumKB(b []byte, names ...string) (uint64, bool) {
	var sum uint64
	for i, name := range names {
		n, ok := fieldKB(b, name)
		if !ok && i == 0 {
			return 0, false
		}
		sum += n
	}
	return sum, true
}

// fieldKB is field name of such a file, in bytes.
func fieldKB(b []byte, name string) (uint64, bool) {
	for line := range bytes.Lines(b) {
		v, ok := bytes.CutPrefix(line, []byte(name+":"))
		if !ok {
			continue
		}
		f := bytes.Fields(v)
		if len(f) != 2 || string(f[1]) != "kB" {
			return 0, false
		}
		n, err := strconv.ParseUint(string(f[0]), 10, 54) // kB that fit in a uint64's bytes
		if err != nil {
			return 0, false
		}
		return n << 10, true
	}
	return 0, false
}
