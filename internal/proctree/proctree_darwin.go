package proctree

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"time"

	"golang.org/x/sys/unix"
)

// all lists every process, from sysctl's kern.proc.all.
func all() ([]proc, error) {
	ks, err := unix.SysctlKinfoProcSlice("kern.proc.all")
	if err != nil {
		return nil, fmt.Errorf("listing processes: %w", err)
	}
	ps := make([]proc, 0, len(ks))
	for _, k := range ks {
		ps = append(ps, proc{ppid: int(k.Eproc.Ppid), Pid: int(k.Proc.P_pid), Pgid: int(k.Eproc.Pgid),
			Started: time.Unix(k.Proc.P_starttime.Sec, int64(k.Proc.P_starttime.Usec)*1000)})
	}
	return ps, nil
}

// Args reads a process's command line, nil when it can't be read (it
// ended, or it isn't the user's). kern.procargs2 is argc (an int32), the
// executable's path and NULs up to the next multiple of 8, then argc
// strings and the environment, each ended by a NUL: an empty first
// argument is one NUL more, which a cut at the first non-NUL would take
// for padding.
func Args(pid int) []string {
	b, err := unix.SysctlRaw("kern.procargs2", pid)
	if err != nil || len(b) < 4 {
		return nil
	}
	argc := int(binary.LittleEndian.Uint32(b))
	b = b[4:]
	i := bytes.IndexByte(b, 0)
	start := (i + 1 + 7) &^ 7
	if i < 0 || start > len(b) || len(bytes.Trim(b[i:start], "\x00")) > 0 {
		return nil
	}
	b = b[start:]
	out := make([]string, 0, min(argc, 256))
	for range argc {
		i := bytes.IndexByte(b, 0)
		if i < 0 {
			return nil
		}
		out = append(out, string(b[:i]))
		b = b[i+1:]
	}
	return out
}
