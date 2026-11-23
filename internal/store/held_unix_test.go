//go:build unix

package store

import (
	"os"
	"sync"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// held runs read, which reads the file at path, while that file is a fifo
// no one has written yet: read stays inside the read until the test
// releases it with content. held returns once read is in it, and release
// waits for read to return.
func held(t *testing.T, path string, read func()) (release func(content string)) {
	t.Helper()
	testcheck.Fifo(t, path)
	done := make(chan struct{})
	go func() {
		defer close(done)
		read()
	}()
	var w *os.File
	testcheck.Wait(t, "the read to open the fifo", func() bool {
		f, err := os.OpenFile(path, os.O_WRONLY|syscall.O_NONBLOCK, 0) // fails until a reader has it open
		w = f
		return err == nil
	})
	var once sync.Once
	release = func(content string) {
		once.Do(func() {
			_, _ = w.WriteString(content)
			_ = w.Close()
			<-done
		})
	}
	t.Cleanup(func() { release("") })
	return release
}

// answers says f returned while a read is held, failing the test if it
// doesn't within testcheck.Wait's time.
func answers(t *testing.T, what string, f func()) {
	t.Helper()
	done := make(chan struct{})
	go func() {
		defer close(done)
		f()
	}()
	testcheck.Wait(t, what+" to answer while another file's read is held", func() bool {
		select {
		case <-done:
			return true
		default:
			return false
		}
	})
}
