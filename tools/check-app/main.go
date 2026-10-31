// Command check-app checks the app the way a change to it needs: make
// lint-dart, then make test-app, then flutter build macos, which it never
// runs. It stops at the first failure. Each step's whole output goes to a log
// file, so what's printed is short enough to need no pipe: a line per step
// and, on a failure, the failing tests' names and reasons, then a last line
// with the failed step, its exit code and its log. The last line is the
// verdict, so even a tail shows it. Run it from the repository root: make
// check-app.
//
// It exits with the failing step's code. make check-app reports any failing
// recipe as 2, whatever the code was; the last line has the real one.
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
	"strings"
	"time"
)

// logs is where each step's output goes, under bin/ so git ignores it.
const logs = "bin/check-app-logs"

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
	os.Exit(run(log.New(os.Stdout, "", 0), folder, steps(folder)))
}

// step is a command to run, from the repository root unless dir says.
type step struct {
	name    string
	dir     string
	cmd     []string
	results string // the JSON reporter's file, for a step that runs tests
}

// steps are the checks in order. FLUTTER_TEST_FLAGS and SHARD work as for
// make test-app; the flag's path is from app/, where flutter test runs,
// because make splits it at any space in an absolute one.
func steps(folder string) []step {
	flags := os.Getenv("FLUTTER_TEST_FLAGS") + " --file-reporter json:../" + logs + "/test-app.json"
	return []step{
		{name: "lint-dart", cmd: []string{"make", "lint-dart"}},
		{
			name:    "test-app",
			cmd:     []string{"make", "test-app", "FLUTTER_TEST_FLAGS=" + strings.TrimSpace(flags)},
			results: filepath.Join(folder, "test-app.json"),
		},
		{name: "flutter build macos", dir: "app", cmd: []string{"flutter", "build", "macos"}},
	}
}

// run runs the steps until one fails and gives the exit code for that.
func run(out *log.Logger, folder string, steps []step) int {
	for _, s := range steps {
		file := filepath.Join(folder, strings.ReplaceAll(s.name, " ", "-")+".log")
		if s.results != "" {
			// Results left by an earlier run would pass for this one's.
			if err := os.Remove(s.results); err != nil && !errors.Is(err, os.ErrNotExist) {
				out.Printf("check-app: FAILED at %s: %v", s.name, err)
				return 1
			}
		}
		start := time.Now()
		code, err := s.exec(file)
		if err != nil {
			out.Printf("check-app: FAILED at %s (exit %d): %v", s.name, code, err)
			return code
		}
		results := readResults(s.results)
		if code == 0 {
			note := ""
			if results.passed > 0 {
				note = fmt.Sprintf(", %d tests", results.passed)
			}
			out.Printf("%s: ok%s (%s)", s.name, note, time.Since(start).Round(time.Second))
			continue
		}
		if !results.print(out) {
			printKeyLines(out, file)
		}
		out.Printf("check-app: FAILED at %s (exit %d), full log: %s", s.name, code, file)
		return code
	}
	out.Print("check-app: ok")
	return 0
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
