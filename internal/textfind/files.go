package textfind

import (
	"bufio"
	"context"
	"errors"
	"io"
	"runtime"
	"sync"
)

// MaxLine is the longest line Lines hands on: a longer one (an image, a
// long command's output) is read past, never kept whole. No one types a
// prompt that long.
const MaxLine = 8 << 20

// Lines calls fn with each line of r, without its newline, until fn
// returns false, r ends or ctx does (its error then). A line is only valid
// during the call. Lines longer than MaxLine are skipped.
func Lines(ctx context.Context, r io.Reader, fn func(line []byte) bool) error {
	br := bufio.NewReaderSize(r, 256<<10)
	var long []byte // a line longer than the reader's buffer, gathered
	tooLong := false
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		chunk, err := br.ReadSlice('\n')
		if errors.Is(err, bufio.ErrBufferFull) {
			if !tooLong && len(long)+len(chunk) <= MaxLine {
				long = append(long, chunk...)
			} else {
				tooLong, long = true, long[:0]
			}
			continue
		}
		line := chunk
		if len(long) > 0 {
			long = append(long, chunk...)
			line = long
		}
		if n := len(line); n > 0 && line[n-1] == '\n' {
			line = line[:n-1]
		}
		if !tooLong && len(line) <= MaxLine && len(line) > 0 && !fn(line) {
			return nil
		}
		long, tooLong = long[:0], false
		if err != nil {
			if errors.Is(err, io.EOF) {
				return nil
			}
			return err
		}
	}
}

// Each runs find on items 0 to n-1, several at once, and gathers what it
// finds in the items' order, stopping once it has max (more is then true
// when items were left unread) or when ctx ends (what was found before,
// with ctx's error). Every find has returned when Each does.
func Each[T any](ctx context.Context, n, maxFound int, find func(ctx context.Context, i int) (T, bool)) (found []T, more bool, err error) {
	ctx, cancel := context.WithCancel(ctx)
	type result struct {
		v  T
		ok bool
	}
	results := make([]chan result, n)
	for i := range results {
		results[i] = make(chan result, 1)
	}
	jobs := make(chan int)
	var wg sync.WaitGroup
	for range min(n, runtime.GOMAXPROCS(0), 8) {
		wg.Go(func() {
			for i := range jobs {
				v, ok := find(ctx, i)
				results[i] <- result{v, ok}
			}
		})
	}
	go func() {
		defer close(jobs)
		for i := range n {
			select {
			case jobs <- i:
			case <-ctx.Done():
				return
			}
		}
	}()
	defer wg.Wait()
	defer cancel()
	for i := range n {
		select {
		case r := <-results[i]:
			if !r.ok {
				continue
			}
			found = append(found, r.v)
			if len(found) >= maxFound {
				return found, i < n-1, nil
			}
		case <-ctx.Done():
			return found, true, ctx.Err()
		}
	}
	return found, false, nil
}
