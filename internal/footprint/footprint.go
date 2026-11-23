// Package footprint reads how much memory processes take. On macOS it
// is their physical footprint (phys_footprint), what Activity Monitor
// shows as Memory, with no cgo: proc_pid_rusage is the proc_info system
// call, and the process list is sysctl's kern.proc.all
// (footprint_darwin.go). On Linux it is each process's proportional set
// size and swapped-out share, from /proc/<pid>/smaps_rollup, and the
// process list is /proc's stat files (footprint_linux.go). On Windows it
// is each process's private bytes (GetProcessMemoryInfo), and the process
// list is Toolhelp's snapshot (footprint_windows.go, ADR 0133). It builds
// for those three only (ADR 0124).
package footprint

// Processes is a snapshot of which process started which.
type Processes struct {
	children map[int][]int // by the parent's id
	// isChild says whether child, whose parent id is parent, is that
	// process's child, where the id can name another (Windows: the
	// parent ended, and its id was given again); nil where it can't.
	isChild func(parent, child int) bool
}

// Tree returns the footprint of pid and every process under it, each
// counted once.
func (p Processes) Tree(pid int) uint64 { return p.tree(pid, map[int]bool{}) }

func (p Processes) tree(pid int, seen map[int]bool) uint64 {
	if seen[pid] {
		return 0
	}
	seen[pid] = true
	n := Of(pid)
	for _, child := range p.Children(pid) {
		n += p.tree(child, seen)
	}
	return n
}

// Children returns the processes pid started.
func (p Processes) Children(pid int) []int {
	var out []int
	for _, c := range p.children[pid] {
		if c != pid && (p.isChild == nil || p.isChild(pid, c)) { // the kernel's own process 0 is its own parent
			out = append(out, c)
		}
	}
	return out
}
