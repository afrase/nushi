package terminal

import (
	"os"

	"golang.org/x/sys/unix"

	"github.com/afrase/nushi/internal/procfs"
)

// device is the terminal's device number as /proc/<pid>/stat's tty_nr
// says it of what runs on it.
func device(tty *os.File) (int32, error) {
	var st unix.Stat_t
	if err := unix.Fstat(int(tty.Fd()), &st); err != nil {
		return 0, err
	}
	return ttyNr(unix.Major(st.Rdev), unix.Minor(st.Rdev)), nil
}

// ttyNr encodes a device number as the kernel writes tty_nr
// (new_encode_dev): the minor's low 8 bits, the major's 12 above them,
// then the minor's other 12. Rebuilt from the major and minor rather than
// cut from st_rdev, whose layout is the C library's, not the kernel's.
func ttyNr(major, minor uint32) int32 {
	return int32(minor&0xff | major&0xfff<<8 | (minor&^0xff)<<12) //nolint:gosec // 32 bits by construction: a 12-bit major and a 20-bit minor, as tty_nr holds them
}

// name returns a process's name (its stat's comm), or "".
func name(pid int) string {
	if s, err := procfs.ReadStat(pid); err == nil {
		return s.Comm
	}
	return ""
}

// onTerminal lists the processes whose controlling terminal is t's (their
// stat's tty_nr). The program itself is among them while it runs; once
// it has ended its pid isn't added, since it may name another process by
// then.
func (t *Terminal) onTerminal() []int {
	var pids []int
	for _, s := range procfs.All() {
		if s.TTY != 0 && int32(s.TTY) == t.tty { //nolint:gosec // tty_nr is a 32-bit field of the kernel's
			pids = append(pids, s.Pid)
		}
	}
	return pids
}
