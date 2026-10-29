package claudeagent

import (
	"bufio"
	"errors"
	"io"
)

// lineReader reads newline-ended lines of at most max bytes. A longer
// line is read through and dropped, so one huge line costs neither the
// memory nor the stream.
type lineReader struct {
	r   *bufio.Reader
	max int
}

func newLineReader(r io.Reader, maxLine int) *lineReader {
	return &lineReader{r: bufio.NewReaderSize(r, 64<<10), max: maxLine}
}

// next returns the next line without its newline, in a slice of its own.
// For a line over the cap it returns a nil line and the line's size. A
// last line with no newline counts as a line; io.EOF comes after it.
func (l *lineReader) next() (line []byte, over int, err error) {
	n := 0
	for {
		chunk, rerr := l.r.ReadSlice('\n')
		n += len(chunk)
		if n <= l.max+1 {
			line = append(line, chunk...)
		} else {
			line = nil // over the cap: read on, keep nothing
		}
		if errors.Is(rerr, bufio.ErrBufferFull) {
			continue
		}
		if rerr == nil {
			n-- // the newline
			line = line[:max(len(line)-1, 0)]
		} else if !errors.Is(rerr, io.EOF) || n == 0 {
			return nil, 0, rerr
		}
		if n > l.max {
			return nil, n, nil
		}
		return line, 0, nil
	}
}
