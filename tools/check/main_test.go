package main

import (
	"log"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// Lines as flutter test's JSON reporter writes them, cut to what matters: a
// passing test, a plain test's failure, a widget test's, whose error only
// points at the exception it printed, and a file that didn't compile.
const reporter = `{"protocolVersion":"0.1.1","type":"start"}
{"suite":{"id":0,"platform":"vm","path":"/repo/app/test/a_test.dart"},"type":"suite"}
{"test":{"id":1,"name":"loading /repo/app/test/a_test.dart","suiteID":0},"type":"testStart"}
{"testID":1,"result":"success","hidden":true,"skipped":false,"type":"testDone"}
{"test":{"id":2,"name":"passes","suiteID":0},"type":"testStart"}
{"testID":2,"result":"success","hidden":false,"skipped":false,"type":"testDone"}
{"test":{"id":3,"name":"plain","suiteID":0},"type":"testStart"}
{"testID":3,"error":"Expected: <2>\n  Actual: <1>\n","type":"error"}
{"testID":3,"result":"failure","hidden":false,"skipped":false,"type":"testDone"}
{"test":{"id":4,"name":"widget","suiteID":0},"type":"testStart"}
{"testID":4,"messageType":"print","message":"══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═══\nThe following TestFailure was thrown running a test:\nExpected: exactly one\n  Actual: none\n\nWhen the exception was thrown, this was the stack:\n#0 main\n","type":"print"}
{"testID":4,"error":"Test failed. See exception logs above.\nThe test description was: widget","type":"error"}
{"testID":4,"result":"error","hidden":false,"skipped":false,"type":"testDone"}
{"test":{"id":5,"name":"loading /repo/app/test/b_test.dart","suiteID":1},"type":"testStart"}
{"testID":5,"error":"Failed to load: Error: not an int","type":"error"}
{"testID":5,"result":"error","hidden":false,"skipped":false,"type":"testDone"}
{"success":false,"type":"done"}
`

func TestReadResults(t *testing.T) {
	path := filepath.Join(t.TempDir(), "r.json")
	testcheck.Write(t, path, reporter)
	got := readResults(path)
	if got.passed != 1 || len(got.failed) != 3 {
		t.Fatalf("%+v", got)
	}
	if f := got.failed[0]; f.name != "plain" || !strings.Contains(f.reason, "Expected: <2>") {
		t.Errorf("a plain test's failure: %+v", f)
	}
	widget := got.failed[1]
	if !strings.Contains(widget.reason, "Actual: none") {
		t.Errorf("a widget test's reason is what it printed: %q", widget.reason)
	}
	if strings.Contains(widget.reason, "#0 main") {
		t.Errorf("the stack came along: %q", widget.reason)
	}
	if f := got.failed[2]; !strings.Contains(f.reason, "not an int") {
		t.Errorf("a file that didn't compile: %+v", f)
	}
}

// sh is a step that prints a line and exits with code.
func sh(name, code string) step {
	return step{name: name, cmd: []string{"sh", "-c", "echo log of " + name + "; exit " + code}}
}

// Every step runs, a failure or not: the lanes side by side, then the
// steps after them. Each failure says why with its log's path, the first
// one's code comes back, and the verdict naming them all is the last line.
func TestRunReportsEveryFailure(t *testing.T) {
	dir := t.TempDir()
	var out strings.Builder
	lanes := [][]step{{sh("one", "0"), sh("two", "3")}, {sh("three", "0"), sh("five", "4")}}
	code := run(log.New(&out, "", 0), dir, lanes, []step{sh("six", "5")})
	if code != 3 {
		t.Errorf("exit %d, want the first failed step's 3", code)
	}
	text := out.String()
	for _, name := range []string{"one", "three"} {
		if !strings.Contains(text, name+": ok (") {
			t.Errorf("no ok line for %s:\n%s", name, text)
		}
	}
	for _, name := range []string{"two", "five", "six"} {
		file := filepath.Join(dir, name+".log")
		if !strings.Contains(text, name+": FAILED (exit ") || !strings.Contains(text, "full log: "+file) {
			t.Errorf("%s's failure isn't reported:\n%s", name, text)
		}
		data, err := os.ReadFile(file)
		testcheck.NoErr(t, err)
		if string(data) != "log of "+name+"\n" {
			t.Errorf("log %q", data)
		}
	}
	lines := strings.Split(strings.TrimSpace(text), "\n")
	if last := lines[len(lines)-1]; !strings.HasPrefix(last, "check: FAILED at two, five, six (exit 3, ") {
		t.Errorf("last line %q", last)
	}
}

// The steps after the lanes wait for both, and the lanes run side by side.
func TestLanesRunSideBySide(t *testing.T) {
	dir := t.TempDir()
	mark := filepath.Join(dir, "mark")
	// Each lane waits for the other's mark: in a row, the first would wait forever.
	wait := func(name, mine, theirs string) step {
		return step{name: name, cmd: []string{"sh", "-c", "touch " + mark + mine + "; i=0; while [ ! -e " + mark + theirs + " ] && [ $i -lt 100 ]; do sleep 0.05; i=$((i+1)); done; [ -e " + mark + theirs + " ]"}}
	}
	after := step{name: "after", cmd: []string{"sh", "-c", "[ -e " + mark + "a ] && [ -e " + mark + "b ]"}}
	var out strings.Builder
	if code := run(log.New(&out, "", 0), dir, [][]step{{wait("a", "a", "b")}, {wait("b", "b", "a")}}, []step{after}); code != 0 {
		t.Errorf("exit %d:\n%s", code, out.String())
	}
	if !strings.HasSuffix(strings.TrimSpace(out.String()), ")") || !strings.Contains(out.String(), "check: ok (") {
		t.Errorf("verdict:\n%s", out.String())
	}
}

// A failure with no line that says why still shows the end of its log.
func TestFailureIsNeverSilent(t *testing.T) {
	var out strings.Builder
	if code := run(log.New(&out, "", 0), t.TempDir(), nil, []step{sh("one", "1")}); code != 1 {
		t.Errorf("exit %d", code)
	}
	if !strings.Contains(out.String(), "log of one") {
		t.Errorf("no output from the log:\n%s", out.String())
	}
}

// A signal has no exit code; it must not read as success.
func TestKilledStepFails(t *testing.T) {
	s := step{name: "killed", cmd: []string{"sh", "-c", "kill -9 $$"}}
	if code := run(log.New(&strings.Builder{}, "", 0), t.TempDir(), nil, []step{s}); code != 1 {
		t.Errorf("exit %d", code)
	}
}

func TestCommandNotFoundFails(t *testing.T) {
	s := step{name: "gone", cmd: []string{"no-such-command-here"}}
	var out strings.Builder
	if code := run(log.New(&out, "", 0), t.TempDir(), [][]step{{s}}, nil); code != 1 {
		t.Errorf("exit %d", code)
	}
	if !strings.Contains(out.String(), "gone couldn't run") {
		t.Errorf("why isn't said:\n%s", out.String())
	}
}

// An analyzer's lines are picked from the rest, and clipped.
func TestKeyLines(t *testing.T) {
	file := filepath.Join(t.TempDir(), "l.log")
	testcheck.Write(t, file, "Analyzing app...\n   info • Bad thing • lib/a.dart:1:2 • rule\nChanged lib/b.dart\n3 issues found\n")
	var out strings.Builder
	printKeyLines(log.New(&out, "", 0), file)
	want := "   info • Bad thing • lib/a.dart:1:2 • rule\nChanged lib/b.dart\n"
	if out.String() != want {
		t.Errorf("got %q", out.String())
	}
	if got := clip("a\n\nb\nc", 2); len(got) != 3 || got[2] != "..." {
		t.Errorf("clip %q", got)
	}
}

// A step that ran nothing says so in its last line (make test-web without
// a Chrome), and its line says skipped, not ok.
func TestSkippedStepSaysSo(t *testing.T) {
	s := step{name: "web", cmd: []string{"sh", "-c", "echo setting up; echo 'web: skipped: no Chrome'"}}
	var out strings.Builder
	if code := run(log.New(&out, "", 0), t.TempDir(), [][]step{{s}}, nil); code != 0 {
		t.Errorf("exit %d", code)
	}
	if !strings.Contains(out.String(), "web: skipped (no Chrome)\n") || strings.Contains(out.String(), "web: ok") {
		t.Errorf("a skip reads as a pass:\n%s", out.String())
	}
	if !strings.Contains(out.String(), "check: ok (") {
		t.Errorf("a skip isn't a failure:\n%s", out.String())
	}
}
