//go:build unix

package relayupdate

import (
	"os"
	"syscall"
)

// copyOwner gives name the owner and group of the file old describes,
// when running as root (another account can't, and its files are its own
// already).
func copyOwner(name string, old os.FileInfo) error {
	st, ok := old.Sys().(*syscall.Stat_t)
	if os.Geteuid() != 0 || !ok {
		return nil
	}
	return os.Chown(name, int(st.Uid), int(st.Gid))
}
