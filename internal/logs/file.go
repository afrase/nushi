package logs

import (
	"fmt"
	"os"
	"sync"

	"golang.org/x/sys/unix"
)

// MaxSize is how large the log grows before it rotates, and Keep how many
// older copies stay beside it (nushid.log.1 the newer).
const (
	MaxSize = 10 << 20
	Keep    = 2
)

// File is a log file that rotates once it would pass max bytes. With std,
// the process's stdout and stderr follow it: the Go runtime writes a crash
// (a panic nobody recovered, a fatal error) to fd 2, and it lands in the
// log file of the moment, not in a copy rotated away.
type File struct {
	path string
	max  int64
	std  bool

	mu   sync.Mutex
	f    *os.File
	size int64
}

// Open opens the log at path for appending, as the launcher's `>>` does.
func Open(path string, std bool) (*File, error) {
	l := &File{path: path, max: MaxSize, std: std}
	err := l.open()
	return l, err
}

func (l *File) open() error {
	f, err := os.OpenFile(l.path, os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0o600)
	if err != nil {
		return err
	}
	st, err := f.Stat()
	if err != nil {
		f.Close()
		return err
	}
	if l.std {
		for _, fd := range []int{1, 2} {
			if err := unix.Dup2(int(f.Fd()), fd); err != nil {
				f.Close()
				return fmt.Errorf("log: stderr: %w", err)
			}
		}
	}
	if l.f != nil {
		l.f.Close()
	}
	l.f, l.size = f, st.Size()
	return nil
}

// Write appends p, rotating first when p would take the file past max.
// A failed rotation keeps writing to the file it has.
func (l *File) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.size > 0 && l.size+int64(len(p)) > l.max {
		l.rotate()
	}
	n, err := l.f.Write(p)
	l.size += int64(n)
	return n, err
}

// rotate moves path to path.1, path.1 to path.2 and so on, the oldest
// dropped, and starts path again.
func (l *File) rotate() {
	for i := Keep; i > 1; i-- {
		os.Rename(fmt.Sprintf("%s.%d", l.path, i-1), fmt.Sprintf("%s.%d", l.path, i))
	}
	if os.Rename(l.path, l.path+".1") == nil {
		l.open()
	}
}

func (l *File) Close() error {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.f.Close()
}
