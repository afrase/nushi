package claudetest

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
)

// Cassette is a recorded run of claude: how it was started, and every
// line on its stdin and stdout, in order. On disk it is JSON Lines: the
// Header, then a Frame a line.
type Cassette struct {
	Header Header
	Frames []Frame
}

// Header is how the recorded claude was started. It has the environment's
// names only, never their values, which may be secrets.
type Header struct {
	Argv    []string `json:"argv"`    // the arguments after claude's path
	EnvKeys []string `json:"envKeys"` // the environment's names
	CLI     string   `json:"cli"`     // claude's version
}

// Frame is one line of the run: "in" written to claude's stdin, "out"
// written by claude on stdout. MS is when, in milliseconds from the start;
// Replay plays in order and ignores it.
type Frame struct {
	Dir   string          `json:"dir"`
	MS    int64           `json:"ms"`
	Frame json.RawMessage `json:"frame"`
}

// ReadCassette reads a cassette from r.
func ReadCassette(r io.Reader) (*Cassette, error) {
	br := bufio.NewReader(r)
	var c Cassette
	for n := 1; ; n++ {
		line, err := br.ReadBytes('\n')
		if len(bytes.TrimSpace(line)) > 0 {
			if perr := c.parse(n, line); perr != nil {
				return nil, perr
			}
		}
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, err
		}
	}
	if c.Header.Argv == nil {
		return nil, errors.New("claudetest: the cassette has no header")
	}
	return &c, nil
}

// parse takes line n: the header first, then frames.
func (c *Cassette) parse(n int, line []byte) error {
	if c.Header.Argv == nil {
		if err := json.Unmarshal(line, &c.Header); err != nil || c.Header.Argv == nil {
			return fmt.Errorf("claudetest: cassette line %d isn't a header", n)
		}
		return nil
	}
	var f Frame
	if err := json.Unmarshal(line, &f); err != nil || f.Dir != "in" && f.Dir != "out" || len(f.Frame) == 0 {
		return fmt.Errorf("claudetest: cassette line %d isn't a frame", n)
	}
	c.Frames = append(c.Frames, f)
	return nil
}

// Replay is a fake claude that plays c: it expects each line written to
// the recorded claude, matched loosely (its type, subtype and request's
// subtype), and writes each line the recorded claude wrote, in the
// recorded order. The client's ids stand in for the recorded ones in what
// it writes: the session's (from --session-id and --resume), requests'
// and user messages', so responses and echoes carry the live ones.
func Replay(c *Cassette) *Fake {
	ids := map[string]string{}
	steps := []Step{{name: "the session's id", run: func(r *run) error {
		live := flags(r.f.Spec().Args)
		for k, rec := range flags(c.Header.Argv) {
			if l := live[k]; l != "" {
				ids[rec] = l
			}
		}
		return nil
	}}}
	for _, f := range c.Frames {
		var head struct {
			Type string `json:"type"`
		}
		_ = json.Unmarshal(f.Frame, &head)
		switch {
		case f.Dir == "in" && head.Type == "keep_alive": // the fake never sees these
		case f.Dir == "in":
			steps = append(steps, expectRecorded(f.Frame, ids))
		default:
			steps = append(steps, sendRecorded(f.Frame, ids))
		}
	}
	return New(steps...)
}

// flags are the values of the flags that name the session.
func flags(argv []string) map[string]string {
	out := map[string]string{}
	for i, a := range argv {
		for _, k := range []string{"--session-id", "--resume"} {
			switch {
			case strings.HasPrefix(a, k+"="):
				out[k] = strings.TrimPrefix(a, k+"=")
			case a == k && i+1 < len(argv):
				out[k] = argv[i+1]
			}
		}
	}
	return out
}

// expectRecorded expects a line like rec, and maps rec's request id and
// uuid to the line's.
func expectRecorded(rec json.RawMessage, ids map[string]string) Step {
	var r struct {
		Type      string `json:"type"`
		Subtype   string `json:"subtype"`
		RequestID string `json:"request_id"`
		UUID      string `json:"uuid"`
		Request   struct {
			Subtype string `json:"subtype"`
		} `json:"request"`
	}
	_ = json.Unmarshal(rec, &r)
	want := map[string]any{"type": r.Type}
	if r.Subtype != "" {
		want["subtype"] = r.Subtype
	}
	if r.Request.Subtype != "" {
		want["request"] = map[string]any{"subtype": r.Request.Subtype}
	}
	var recorded any
	_ = json.Unmarshal(rec, &recorded)
	return Step{name: strings.TrimSpace("expect recorded " + r.Type + " " + r.Subtype + r.Request.Subtype), wants: recorded, run: func(run *run) error {
		line, err := run.line()
		if err != nil {
			return fmt.Errorf("stdin: %w", err)
		}
		var got any
		if err := json.Unmarshal(line, &got); err != nil || !matches(want, got) {
			return fmt.Errorf("got %s", line)
		}
		req, uuid := captured(got)
		for rec, live := range map[string]string{r.RequestID: req, r.UUID: uuid} {
			if rec != "" && live != "" {
				ids[rec] = live
			}
		}
		return nil
	}}
}

// sendRecorded writes rec with the live ids for the recorded ones.
func sendRecorded(rec json.RawMessage, ids map[string]string) Step {
	return Step{name: "send recorded", run: func(r *run) error {
		pairs := make([]string, 0, 2*len(ids))
		for rec, live := range ids {
			pairs = append(pairs, `"`+rec+`"`, `"`+live+`"`) // whole JSON strings, never part of one
		}
		_, err := io.WriteString(r.f.stdout, strings.NewReplacer(pairs...).Replace(string(rec))+"\n")
		return err
	}}
}
