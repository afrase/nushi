// Command check is make check: the lint, every test (the app's suite once)
// and the desktop app's build (flutter build macos, or linux on Linux,
// which it never runs), before a push. Two lanes run side by side: the
// app's suite, then the web app's tests (both flutter test in app/); and
// the lints, then the other tests. The build comes after both. A failed
// step doesn't stop the others, so one run shows every failure. Each
// step's whole output goes to a log file, so what's printed is short
// enough to need no pipe: a line per step as it ends, then each failed
// step's failing tests and reasons, or its log's key lines, and its log's
// path, and a last line with the verdict, so even a tail shows it. Run it
// from the repository root: make check.
//
// It exits with the first failed step's code (in the lanes' order). make
// check reports any failing recipe as 2, whatever the code was; the last
// line has the real one.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"sync"
	"time"
)

// logs is where each step's output goes, under bin/ so git ignores it,
// with the app's suite's JSON results, read for the tests that failed.
const logs = "bin/check-logs"

const (
	maxTests  = 20 // failing tests named, the rest counted
	maxReason = 6  // lines of a test's reason
	maxLines  = 20 // lines of a failed step without test results
	maxWidth  = 200
)

func main() {
	folder, err := filepath.Abs(logs)
	if err != nil {
		log.Fatal(err)
	}
	if err := os.MkdirAll(folder, 0o700); err != nil {
		log.Fatal(err)
	}
	lanes, after := steps(folder)
	os.Exit(run(log.New(os.Stdout, "", 0), folder, lanes, after))
}

// step is a command to run, from the repository root unless dir says.
type step struct {
	name    string
	dir     string
	cmd     []string
	results string // the JSON reporter's file, for a step that runs tests
}

// steps are the lanes, each run in order beside the other, and the steps
// after them. FLUTTER_TEST_FLAGS works as for make test-app (three files
// at once unless it says: more was no faster on a 12-core Mac); the
// report's path is from app/, where flutter test runs, because make
// splits it at any space in an absolute one. The web app's tests run
// after the suite, not beside it: both are flutter test in app/.
func steps(folder string) (lanes [][]step, after []step) {
	flags := os.Getenv("FLUTTER_TEST_FLAGS")
	if flags == "" {
		flags = "--concurrency 3"
	}
	flags += " --file-reporter json:../" + logs + "/test-app.json"
	// test-web skips itself where there's no Chrome, and says so.
	app := []step{{
		name:    "test-app",
		cmd:     []string{"make", "test-app", "FLUTTER_TEST_FLAGS=" + flags},
		results: filepath.Join(folder, "test-app.json"),
	}, makeStep("test-web")}
	rest := []step{
		makeStep("lint-dart"), makeStep("lint-go"), makeStep("lint-linux"), makeStep("lint-windows"),
		{name: "ci-changes self-test", cmd: []string{"tools/ci-changes.sh", "--self-test"}},
		makeStep("test-go"), makeStep("test-packages"),
	}
	if runtime.GOOS == "darwin" {
		rest = append(rest, makeStep("test-window"))
	}
	build := buildTarget()
	return [][]step{app, rest}, []step{{name: "flutter build " + build, dir: "app", cmd: []string{"flutter", "build", build}}}
}

func makeStep(target string) step {
	return step{name: target, cmd: []string{"make", target}}
}

// buildTarget is the desktop app flutter builds here: Linux's on Linux
// (ADR 0104), else the Mac's.
func buildTarget() string {
	if runtime.GOOS == "linux" {
		return "linux"
	}
	return "macos"
}

// outcome is how a step ended.
type outcome struct {
	step
	log  string
	code int
	err  error  // the step couldn't run
	ok   string // what a passing step's line says
}

// run runs the lanes side by side, then the steps after them, and gives
// the exit code: the first failed step's, in the lanes' order.
func run(out *log.Logger, folder string, lanes [][]step, after []step) int {
	start := time.Now()
	var mu sync.Mutex // out's lines, one at a time
	runLane := func(lane []step) []outcome {
		var ended []outcome
		for _, s := range lane {
			o := s.run(folder)
			mu.Lock()
			o.report(out)
			mu.Unlock()
			ended = append(ended, o)
		}
		return ended
	}
	ended := make([][]outcome, len(lanes)+1)
	var wg sync.WaitGroup
	for i, lane := range lanes {
		wg.Go(func() { ended[i] = runLane(lane) })
	}
	wg.Wait()
	ended[len(lanes)] = runLane(after)
	var failed []outcome
	for _, lane := range ended {
		for _, o := range lane {
			if o.code != 0 {
				failed = append(failed, o)
			}
		}
	}
	took := time.Since(start).Round(time.Second)
	if len(failed) == 0 {
		out.Printf("check: ok (%s)", took)
		return 0
	}
	var names []string
	for _, o := range failed {
		out.Print("")
		o.explain(out)
		names = append(names, o.name)
	}
	out.Printf("check: FAILED at %s (exit %d, %s), logs in %s", strings.Join(names, ", "), failed[0].code, took, folder)
	return failed[0].code
}

// run runs the step with its output in its log.
func (s step) run(folder string) outcome {
	o := outcome{step: s, log: filepath.Join(folder, strings.ReplaceAll(s.name, " ", "-")+".log")}
	if s.results != "" {
		// Results left by an earlier run would pass for this one's.
		if err := os.Remove(s.results); err != nil && !errors.Is(err, os.ErrNotExist) {
			o.code, o.err = 1, err
			return o
		}
	}
	start := time.Now()
	o.code, o.err = s.exec(o.log)
	if o.code == 0 {
		if why, ok := skipped(s.name, o.log); ok {
			o.ok = "skipped (" + why + ")"
			return o
		}
		note := ""
		if r := readResults(s.results); r.passed > 0 {
			note = fmt.Sprintf(", %d tests", r.passed)
		}
		o.ok = fmt.Sprintf("ok%s (%s)", note, time.Since(start).Round(time.Second))
	}
	return o
}

// skipped is why a step that passed ran nothing, when its log's last line
// says so as "<name>: skipped: <why>" (make test-web without a Chrome), so
// the report doesn't call it ok.
func skipped(name, file string) (string, bool) {
	data, err := os.ReadFile(file)
	if err != nil {
		return "", false
	}
	text := string(bytes.TrimSpace(data))
	last := text[strings.LastIndex(text, "\n")+1:]
	return strings.CutPrefix(last, name+": skipped: ")
}

// report is the step's line as it ends.
func (o outcome) report(out *log.Logger) {
	if o.code == 0 {
		out.Printf("%s: %s", o.name, o.ok)
		return
	}
	out.Printf("%s: FAILED (exit %d)", o.name, o.code)
}

// explain says why a failed step failed: its failing tests, or its log's
// key lines, and where its log is.
func (o outcome) explain(out *log.Logger) {
	results := readResults(o.results)
	switch {
	case o.err != nil:
		out.Printf("%s couldn't run: %v", o.name, o.err)
	case !results.print(out):
		printKeyLines(out, o.log)
	}
	out.Printf("%s: FAILED (exit %d), full log: %s", o.name, o.code, o.log)
}

// exec runs the step with its output in the file. Its error is for a step
// that couldn't run; a step that ran and failed only has a code.
func (s step) exec(file string) (int, error) {
	f, err := os.Create(file)
	if err != nil {
		return 1, err
	}
	defer func() { _ = f.Close() }()
	cmd := exec.CommandContext(context.Background(), s.cmd[0], s.cmd[1:]...)
	cmd.Dir = s.dir
	cmd.Stdout, cmd.Stderr = f, f
	err = cmd.Run()
	var exit *exec.ExitError
	switch {
	case errors.As(err, &exit) && exit.ExitCode() > 0:
		return exit.ExitCode(), nil
	case errors.As(err, &exit):
		return 1, nil // killed by a signal: no code of its own
	case err != nil:
		return 1, err
	}
	return 0, nil
}

// failure is a failing test: where it is, what it's called and why it failed.
type failure struct {
	suite, name, reason string
}

// results is what a run of the JSON reporter says.
type results struct {
	passed int
	failed []failure
}

// event is the part of a line of the JSON reporter this reads.
type event struct {
	Type  string `json:"type"`
	Suite struct {
		ID   int    `json:"id"`
		Path string `json:"path"`
	} `json:"suite"`
	Test struct {
		ID      int    `json:"id"`
		Name    string `json:"name"`
		SuiteID int    `json:"suiteID"`
	} `json:"test"`
	TestID  int    `json:"testID"`
	Error   string `json:"error"`
	Message string `json:"message"`
	Result  string `json:"result"`
	Hidden  bool   `json:"hidden"`
	Skipped bool   `json:"skipped"`
}

// readResults reads the reporter's file, or nothing when there's none (a
// step without tests, or a run that died before writing it).
func readResults(path string) results {
	if path == "" {
		return results{}
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return results{}
	}
	var got results
	type test struct {
		suite, name string

		errText string
		prints  []string
	}
	suites := map[int]string{}
	tests := map[int]*test{}
	for line := range bytes.SplitSeq(data, []byte("\n")) {
		var e event
		if json.Unmarshal(line, &e) != nil {
			continue
		}
		switch e.Type {
		case "suite":
			suites[e.Suite.ID] = e.Suite.Path
		case "testStart":
			tests[e.Test.ID] = &test{suite: suites[e.Test.SuiteID], name: e.Test.Name}
		case "print":
			if t := tests[e.TestID]; t != nil {
				t.prints = append(t.prints, e.Message)
			}
		case "error":
			if t := tests[e.TestID]; t != nil && t.errText == "" {
				t.errText = e.Error
			}
		case "testDone":
			t := tests[e.TestID]
			switch {
			case t == nil:
			case e.Result != "success":
				got.failed = append(got.failed, failure{t.suite, t.name, reason(t.errText, t.prints)})
			case !e.Hidden && !e.Skipped:
				got.passed++
			}
		}
	}
	return got
}

// reason is why a test failed. A plain test says so in its error. A widget
// test's error only points at the exception flutter_test printed.
func reason(errText string, prints []string) string {
	if !strings.HasPrefix(errText, "Test failed. See exception logs above") {
		return errText
	}
	for _, p := range prints {
		if !strings.HasPrefix(p, "══╡ EXCEPTION") {
			continue
		}
		_, body, _ := strings.Cut(p, "\n")
		for _, stop := range []string{"When the exception was thrown", "The relevant error-causing widget was"} {
			body, _, _ = strings.Cut(body, stop)
		}
		return body
	}
	return errText
}

// print says which tests failed, and whether there were any to say.
func (r results) print(out *log.Logger) bool {
	if len(r.failed) == 0 {
		return false
	}
	out.Printf("%d failed, %d passed", len(r.failed), r.passed)
	root, _ := os.Getwd()
	short := strings.NewReplacer(root+"/app/", "", root+"/", "")
	for i, f := range r.failed {
		if i == maxTests {
			out.Printf("and %d more", len(r.failed)-maxTests)
			break
		}
		if f.suite != "" {
			out.Printf("%s: %s", short.Replace(f.suite), short.Replace(f.name))
		} else {
			out.Print(short.Replace(f.name))
		}
		for _, line := range clip(short.Replace(f.reason), maxReason) {
			out.Print("    " + line)
		}
	}
	return true
}

// keyLine picks what says why from analyzer, formatter and compiler output.
var keyLine = regexp.MustCompile(`\s(error|warning|info) • |^Changed |[Ee]rror:|Error \(Xcode\)`)

// printKeyLines prints the log's lines that say what went wrong, or its end
// when none does, so a failure is never silent.
func printKeyLines(out *log.Logger, file string) {
	data, err := os.ReadFile(file)
	if err != nil {
		out.Print(err)
		return
	}
	lines := strings.Split(string(bytes.TrimSpace(data)), "\n")
	var key []string
	for _, line := range lines {
		if keyLine.MatchString(line) {
			key = append(key, line)
		}
	}
	if len(key) == 0 {
		key = lines[max(0, len(lines)-maxLines):]
	}
	for _, line := range clip(strings.Join(key, "\n"), maxLines) {
		out.Print(line)
	}
}

// clip keeps the first n lines that aren't blank, each cut to maxWidth.
func clip(text string, n int) []string {
	var lines []string
	for line := range strings.SplitSeq(text, "\n") {
		if strings.TrimSpace(line) == "" {
			continue
		}
		if len(lines) == n {
			return append(lines, "...")
		}
		if r := []rune(line); len(r) > maxWidth {
			line = string(r[:maxWidth]) + "..."
		}
		lines = append(lines, line)
	}
	return lines
}
