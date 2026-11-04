package claudetest

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"reflect"
	"strings"

	"github.com/afrase/nushi/claudeagent"
)

// Step is one thing a Fake does.
type Step struct {
	name  string
	run   func(*run) error
	wants any // the stdin line it waits for, as JSON decodes it, if it does
}

// Expect waits for the next stdin line and checks it matches: match is
// JSON whose every field the line has, with the same value (objects
// match field by field, recursively). The line's request_id (or its
// response's) and uuid are kept for Send's $req and $uuid.
func Expect(match string) Step {
	var want any
	jsonErr := json.Unmarshal([]byte(match), &want)
	return Step{name: "expect " + match, wants: want, run: func(r *run) error {
		if jsonErr != nil {
			return fmt.Errorf("the match isn't JSON: %w", jsonErr)
		}
		req, uuid, err := r.expect(want)
		if err != nil {
			return err
		}
		if req != "" {
			r.req = req
		}
		if uuid != "" {
			r.uuid = uuid
		}
		return nil
	}}
}

// expect reads the next stdin line, which must match want, and returns
// its request_id and uuid (captured).
func (r *run) expect(want any) (req, uuid string, err error) {
	line, err := r.line()
	if err != nil {
		return "", "", fmt.Errorf("stdin: %w", err)
	}
	var got any
	if err := json.Unmarshal(line, &got); err != nil || !matches(want, got) {
		return "", "", fmt.Errorf("got %s", line)
	}
	req, uuid = captured(got)
	return req, uuid, nil
}

// matches says whether got has every field of want, with the same value.
func matches(want, got any) bool {
	w, ok := want.(map[string]any)
	if !ok {
		return reflect.DeepEqual(want, got)
	}
	g, ok := got.(map[string]any)
	if !ok {
		return false
	}
	for k, wv := range w {
		if gv, ok := g[k]; !ok || !matches(wv, gv) {
			return false
		}
	}
	return true
}

// Send writes line on stdout, $req and $uuid replaced by what Expect kept
// last. The line isn't checked: a test may send what claude wouldn't.
func Send(line string) Step {
	return Step{name: "send " + line, run: func(r *run) error {
		line := strings.NewReplacer("$req", r.req, "$uuid", r.uuid).Replace(line)
		_, err := io.WriteString(r.f.stdout, line+"\n")
		return err
	}}
}

// Stderr writes text on stderr.
func Stderr(text string) Step {
	return Step{name: "stderr", run: func(r *run) error {
		_, err := io.WriteString(r.f.stderr, text)
		return err
	}}
}

// ExpectEOF waits for stdin to close, with nothing more on it.
func ExpectEOF() Step {
	return Step{name: "expect EOF", run: func(r *run) error {
		line, err := r.line()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return err
		}
		return fmt.Errorf("got %s", line)
	}}
}

// Until waits for release to be closed, as a claude busy with a turn
// keeps running a while after its stdin closes. A signal that ends the
// fake ends the wait.
func Until(release <-chan struct{}) Step {
	return Step{name: "until released", run: func(r *run) error {
		select {
		case <-release:
		case <-r.f.exited:
		}
		return nil
	}}
}

// Do calls fn, for a test to see how far the script has played or to
// hold it; fn must return for the script to go on.
func Do(fn func()) Step {
	return Step{name: "do", run: func(*run) error {
		fn()
		return nil
	}}
}

// Exit ends the fake with code, after writing stderr on its stderr.
func Exit(code int, stderr string) Step {
	return Step{name: fmt.Sprintf("exit %d", code), run: func(r *run) error {
		if stderr != "" {
			_, _ = io.WriteString(r.f.stderr, stderr)
		}
		var err error
		if code != 0 {
			err = &claudeagent.ExitError{Code: code}
		}
		r.f.exit(err)
		return errExit
	}}
}
