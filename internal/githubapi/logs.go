package githubapi

import (
	"bytes"
	"cmp"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Logs are cut to their end: what's kept of a log as it downloads, at
// most what's read, and what Tail gives.
const (
	logKept  = 256 << 10
	logLimit = 64 << 20
	// TailSize is how much of a failed job's log Nushi shows and gives an
	// agent (Orca's 16 KB).
	TailSize = 16 << 10
)

// JobLog is the end of an Actions job's log (the job's id is its check
// run's): GitHub answers with a link, good for a minute, to the plain
// text, which is fetched without the token.
func (c *Client) JobLog(ctx context.Context, repo string, job int64) (string, error) {
	if _, _, err := SplitRepo(repo); err != nil {
		return "", err
	}
	path := "/repos/{}/{}/actions/jobs/{}/logs"
	owner, name, _ := strings.Cut(repo, "/")
	a, err := c.send(ctx, http.MethodGet, path, c.rest+fill(path, []string{owner, name, strconv.FormatInt(job, 10)}), "core", nil, false)
	if err != nil {
		return "", err
	}
	loc, err := url.Parse(a.header.Get("Location"))
	if a.status != http.StatusFound || err != nil || loc.Scheme != "https" {
		return string(a.body), nil // an answer with the text itself
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, loc.String(), http.NoBody)
	if err != nil {
		return "", err
	}
	start := time.Now()
	resp, err := c.plain.Do(req)
	if err != nil {
		return "", fmt.Errorf("can't fetch the log: %w", cmp.Or(errors.Unwrap(err), err))
	}
	defer func() { _ = resp.Body.Close() }()
	c.log.Debug("github", "method", http.MethodGet, "what", "job log", "status", resp.StatusCode, "took", time.Since(start).Round(time.Millisecond))
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("the log's link answered %s", resp.Status)
	}
	return string(lastBytes(io.LimitReader(resp.Body, logLimit), logKept)), nil
}

// lastBytes reads r through and keeps its last n bytes.
func lastBytes(r io.Reader, n int) []byte {
	buf := make([]byte, 0, 2*n)
	chunk := make([]byte, 32<<10)
	for {
		k, err := r.Read(chunk)
		buf = append(buf, chunk[:k]...)
		if len(buf) > n {
			buf = append(buf[:0], buf[len(buf)-n:]...)
		}
		if err != nil {
			return buf
		}
	}
}

var (
	ansiRE  = regexp.MustCompile(`\x1b\[[0-9;?]*[\x20-\x2f]*[\x40-\x7e]`)
	stampRE = regexp.MustCompile(`^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z ?`)
)

// errorMark marks an error's line in a job's log. The last one is where
// the failed step ended ("Process completed with exit code 1."); what
// follows is the job's clean-up, where stopping a service container
// prints that container's own log, which filled the whole tail with
// Elasticsearch's lines.
const errorMark = "##[error]"

// Tail is a log's end as Nushi shows it: no colours, no timestamps, the
// last size bytes in whole lines up to its last error's line; a first
// line cut short is dropped.
func Tail(log string, size int) string {
	if i := strings.LastIndex(log, errorMark); i >= 0 {
		if j := strings.IndexByte(log[i:], '\n'); j >= 0 {
			log = log[:i+j]
		}
	}
	cut := len(log) > size
	if cut {
		log = log[len(log)-size:]
	}
	log = strings.TrimPrefix(log, "\ufeff") // GitHub's logs start with a byte order mark
	lines := strings.Split(strings.TrimRight(strings.ReplaceAll(log, "\r\n", "\n"), "\n"), "\n")
	if cut && len(lines) > 1 {
		lines = lines[1:]
	}
	var b bytes.Buffer
	for _, l := range lines {
		b.WriteString(stampRE.ReplaceAllString(ansiRE.ReplaceAllString(l, ""), ""))
		b.WriteByte('\n')
	}
	return strings.TrimRight(b.String(), "\n")
}

// libraryFrame is a backtrace's line in someone else's code: vendored
// gems, node_modules, Python's packages, Go's module cache.
var libraryFrame = regexp.MustCompile(`/vendor/bundle/|/gems/|node_modules/|site-packages/|/go/pkg/mod/|<internal:`)

// Brief caps an annotation's message: a run of library frames becomes one
// "… N library frames" line, and at most 30 lines and 3000 bytes are
// kept. RSpec's annotation carries the failure's whole backtrace, about 30
// lines of gems, and went whole to the agent.
func Brief(msg string) string {
	const maxLines, maxBytes = 30, 3000
	lines := strings.Split(msg, "\n")
	out := make([]string, 0, len(lines))
	for i := 0; i < len(lines); {
		j := i
		for j < len(lines) && libraryFrame.MatchString(lines[j]) {
			j++
		}
		switch {
		case j == i:
			out = append(out, lines[i])
			i++
			continue
		case j-i == 1:
			out = append(out, lines[i])
		default:
			indent := lines[i][:len(lines[i])-len(strings.TrimLeft(lines[i], " \t"))]
			out = append(out, fmt.Sprintf("%s… %d library frames", indent, j-i))
		}
		i = j
	}
	if len(out) > maxLines {
		out = append(out[:maxLines], fmt.Sprintf("… %d more lines", len(out)-maxLines))
	}
	s := strings.Join(out, "\n")
	if len(s) > maxBytes {
		s = strings.ToValidUTF8(s[:maxBytes], "") + "…"
	}
	return s
}
