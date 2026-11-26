package terminal

import (
	"bytes"
	"strconv"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// bare is a terminal with no program: what a test emits is its output.
func bare() *Terminal {
	return &Terminal{done: make(chan struct{}), subs: map[*sub]struct{}{}}
}

// replay is what an attach to t gets first.
func replay(t *Terminal) model.TerminalOutput {
	var first model.TerminalOutput
	t.FollowAt(nil, func(o model.TerminalOutput) bool { first = o; return false })
	return first
}

// Places count every byte the terminal emitted, across the kept window's
// trim: the window's first place and its length make the count, and
// followers that join while output comes each see places that follow on
// with no gap or overlap, from where they joined to the end.
func TestPlacesCountAcrossTheTrim(t *testing.T) {
	term := bare()
	const chunk, chunks = 7 << 10, 450 // about 3 MiB, with lines in it
	line := append(bytes.Repeat([]byte("x"), chunk-1), '\n')
	const total = int64(chunk * chunks)

	var wg sync.WaitGroup
	gaps := make(chan string, 64)
	follow := func() {
		next := int64(-1)
		term.FollowAt(nil, func(o model.TerminalOutput) bool {
			if next >= 0 && o.At != next {
				gaps <- "a piece at " + itoa(o.At) + ", want " + itoa(next)
			}
			next = o.At + int64(len(o.Data))
			return next < total
		})
		if next != total {
			gaps <- "a follower ended at " + itoa(next)
		}
	}
	for i := range chunks {
		if i%50 == 0 {
			wg.Go(follow)
		}
		term.emit(line)
	}
	wg.Wait()
	close(gaps)
	for g := range gaps {
		t.Error(g)
	}

	r := replay(term)
	if r.At+int64(len(r.Data)) != total || r.At <= 0 || len(r.Data) > 2*scrollback {
		t.Errorf("the window is %d bytes at %d; %d emitted", len(r.Data), r.At, total)
	}
	if r.Data[0] != 'x' || r.At%chunk != 0 {
		t.Errorf("the window starts mid-line, at %d", r.At)
	}
}

// A new terminal's first attach starts at 0 with no clear.
func TestAFreshTerminalStartsAtZero(t *testing.T) {
	term := bare()
	if r := replay(term); r.At != 0 || len(r.Data) != 0 || r.Cleared != -1 {
		t.Errorf("replay %+v", r)
	}
	term.emit([]byte("hello"))
	if r := replay(term); r.At != 0 || string(r.Data) != "hello" || r.Cleared != -1 {
		t.Errorf("replay %+v", r)
	}
}

// A terminal keeps the latest clear: one before it is ignored, one past
// the output is clamped to its end, and only an attach's first piece
// says where it is.
func TestTheLatestClearIsKept(t *testing.T) {
	term := bare()
	term.emit([]byte("0123456789"))
	for _, c := range []struct{ at, want int64 }{
		{4, 4},   // a clear
		{7, 7},   // a later one replaces it
		{5, 7},   // an older one (another device's) is ignored
		{99, 10}, // one past the output is clamped to it
	} {
		term.Clear(c.at)
		if got := replay(term).Cleared; got != c.want {
			t.Errorf("after Clear(%d): cleared at %d, want %d", c.at, got, c.want)
		}
	}
	var pieces []model.TerminalOutput
	stop := make(chan struct{})
	done := make(chan struct{})
	go func() {
		defer close(done)
		term.FollowAt(stop, func(o model.TerminalOutput) bool {
			pieces = append(pieces, o)
			return len(pieces) < 2
		})
	}()
	waitFollowed(t, term)
	term.emit([]byte("more"))
	<-done
	if len(pieces) != 2 || pieces[0].Cleared != 10 || pieces[1].Cleared != -1 || pieces[1].At != 10 {
		t.Errorf("pieces %+v", pieces)
	}
}

// A clear before the kept window's start is reported as it is: the app
// clears before the bytes it is given.
func TestAClearBeforeTheWindowIsReportedAsItIs(t *testing.T) {
	term := bare()
	term.emit([]byte("early\n"))
	term.Clear(3)
	line := append(bytes.Repeat([]byte("y"), 4095), '\n')
	for range 3 * scrollback / len(line) {
		term.emit(line)
	}
	if r := replay(term); r.At <= 3 || r.Cleared != 3 {
		t.Errorf("window at %d, cleared at %d", r.At, r.Cleared)
	}
}

// waitFollowed waits for a follower to be listed.
func waitFollowed(t *testing.T, term *Terminal) {
	t.Helper()
	testcheck.Wait(t, "a follower", func() bool {
		term.mu.Lock()
		defer term.mu.Unlock()
		return len(term.subs) > 0
	})
}

func itoa(n int64) string { return strconv.FormatInt(n, 10) }
