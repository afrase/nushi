// Package footprint reads how much memory processes take on macOS: their
// physical footprint (phys_footprint), what Activity Monitor shows as
// Memory. It needs no cgo: proc_pid_rusage is the proc_info system call,
// and the process list is sysctl's kern.proc.all (footprint_darwin.go);
// another OS reads nothing (footprint_other.go, ADR 0097).
package footprint

// Processes is a snapshot of which process started which.
type Processes map[int][]int // children by parent

// Tree returns the footprint of pid and every process under it.
func (p Processes) Tree(pid int) uint64 {
	n := Of(pid)
	for _, child := range p[pid] {
		if child != pid { // the kernel's own process 0 is its own parent
			n += p.Tree(child)
		}
	}
	return n
}

// Children returns the processes pid started.
func (p Processes) Children(pid int) []int { return p[pid] }
