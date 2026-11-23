package agentproc

import (
	"regexp"
	"strings"
	"sync"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/logs"
)

// Bounds on the line that says why a program stopped: it is cut at
// maxWhy bytes, and an error-like line wins over the last line while it
// is among the last whyWindow lines.
const (
	maxWhy    = 300
	whyWindow = 50
)

// errorLike is a line that reads as an error. A crash's last line is
// often a runtime's footer ("Node.js v22.1.0", Bun's version), not the
// error above it.
var errorLike = regexp.MustCompile(`(?i)error|fatal|panic`)

// tail picks, from what a program wrote to stderr, the line that says why
// it stopped: the last error-like line among its last whyWindow lines,
// else its last line. A private key's lines and a bridge's DEBUG lines
// (its calls, which can carry a prompt) are never kept; the line kept is
// masked as the log masks it (logs.Redact: internal/secrets' shapes,
// values named like a secret, the client token) and cut at maxWhy, as it
// shows in the chat, its kept copy and on the phone. stderrLines feeds it
// line by line (add); Pipe writes to it.
type tail struct {
	mu   sync.Mutex
	keys keyBlock
	buf  []byte // a line Write has no newline for yet
	pick picked
}

// picked is tail's choice so far.
type picked struct {
	last, failed string
	since        int // lines since failed
}

// add takes a line that is in no key's block.
func (p *picked) add(line string) {
	line = strings.TrimSpace(line)
	if line == "" || strings.HasPrefix(line, DebugPrefix) {
		return
	}
	line = cut(logs.Redact(line), maxWhy)
	p.last = line
	p.since++
	if errorLike.MatchString(line) {
		p.failed, p.since = line, 0
	}
}

func (p *picked) String() string {
	if p.failed != "" && p.since < whyWindow {
		return p.failed
	}
	return p.last
}

// add takes a line of the program's stderr.
func (t *tail) add(line string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if !t.keys.skip(line) {
		t.pick.add(line)
	}
}

func (t *tail) Write(b []byte) (int, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	for _, c := range b {
		switch {
		case c == '\n':
			if line := string(t.buf); !t.keys.skip(line) {
				t.pick.add(line)
			}
			t.buf = t.buf[:0]
		case len(t.buf) < maxLine:
			t.buf = append(t.buf, c)
		}
	}
	return len(b), nil
}

// String is the line picked, with a last line Write had no newline for.
func (t *tail) String() string {
	t.mu.Lock()
	defer t.mu.Unlock()
	p := t.pick
	if len(t.buf) > 0 && t.keys.left == 0 {
		p.add(string(t.buf))
	}
	return p.String()
}

// cut is s cut to at most n bytes, at a rune's start.
func cut(s string, n int) string {
	if len(s) <= n {
		return s
	}
	for n > 0 && !utf8.RuneStart(s[n]) {
		n--
	}
	return s[:n] + "…"
}

// keyBlock follows a private key's block in a program's lines: its BEGIN
// line goes (the masking hides what is on it), the lines after it, to
// its END line or maxKeyLines, are skipped.
type keyBlock struct{ left int }

// skip says whether line is inside a key's block.
func (k *keyBlock) skip(line string) bool {
	if k.left > 0 {
		k.left--
		if strings.Contains(line, "-----END ") {
			k.left = 0
		}
		return true
	}
	if keyBegin.MatchString(line) && !strings.Contains(line, "-----END ") {
		k.left = maxKeyLines
	}
	return false
}
