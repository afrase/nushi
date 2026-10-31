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

// Steps stop at the first failure, whose code comes back; the verdict with
// the log's path is the last line, and the log has the whole output.
func TestRunStopsAtFirstFailure(t *testing.T) {
	dir := t.TempDir()
	var out strings.Builder
	code := run(log.New(&out, "", 0), dir, []step{sh("one", "0"), sh("two", "3"), sh("three", "0")})
	if code != 3 {
		t.Errorf("exit %d, want the step's 3", code)
	}
	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	file := filepath.Join(dir, "two.log")
	if want := "check-app: FAILED at two (exit 3), full log: " + file; lines[len(lines)-1] != want {
		t.Errorf("last line %q, want %q", lines[len(lines)-1], want)
	}
	if !strings.HasPrefix(lines[0], "one: ok (") {
		t.Errorf("first line %q", lines[0])
	}
	if strings.Contains(out.String(), "three") {
		t.Errorf("ran past the failure:\n%s", out.String())
	}
	data, err := os.ReadFile(file)
	testcheck.NoErr(t, err)
	if string(data) != "log of two\n" {
		t.Errorf("log %q", data)
	}
}

// A failure with no line that says why still shows the end of its log.
func TestFailureIsNeverSilent(t *testing.T) {
	var out strings.Builder
	if code := run(log.New(&out, "", 0), t.TempDir(), []step{sh("one", "1")}); code != 1 {
		t.Errorf("exit %d", code)
	}
	if !strings.Contains(out.String(), "log of one") {
		t.Errorf("no output from the log:\n%s", out.String())
	}
}

// A signal has no exit code; it must not read as success.
func TestKilledStepFails(t *testing.T) {
	s := step{name: "killed", cmd: []string{"sh", "-c", "kill -9 $$"}}
	if code := run(log.New(&strings.Builder{}, "", 0), t.TempDir(), []step{s}); code != 1 {
		t.Errorf("exit %d", code)
	}
}

func TestCommandNotFoundFails(t *testing.T) {
	s := step{name: "gone", cmd: []string{"no-such-command-here"}}
	if code := run(log.New(&strings.Builder{}, "", 0), t.TempDir(), []step{s}); code != 1 {
		t.Errorf("exit %d", code)
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
