package claude

import (
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestBackgroundCommands(t *testing.T) {
	tmp := t.TempDir()
	t.Setenv("CLAUDE_CODE_TMPDIR", tmp)
	user := "claude-" + strconv.Itoa(os.Getuid())
	dir := filepath.Join(tmp, user, "-Users-me-app", "s1", "tasks")
	testcheck.NoErr(t, os.MkdirAll(dir, 0o700))
	file := filepath.Join(dir, "b1.output")
	started := "```console\nCommand running in background with ID: b1. Output is being written to: " + file + ". You will be notified when it completes.\n```"
	id, got, ok := harness.BackgroundCommand(model.Item{Tool: "Bash", TaskID: "b1", Text: started})
	if !ok || id != "b1" || got != file {
		t.Fatalf("BackgroundCommand = %q %q %v", id, got, ok)
	}
	// Replayed: no task id, but its input asked for the background.
	if id, _, ok := harness.BackgroundCommand(model.Item{Tool: "Bash", InBackground: true, Text: started}); !ok || id != "b1" {
		t.Error("a replayed background command")
	}
	// Moved to the background after its timeout.
	moved := "Command did not complete within its 120s timeout and was moved to the background (ID: b1). Output is being written to: " + file + "."
	if _, _, ok := harness.BackgroundCommand(model.Item{Tool: "Bash", TaskID: "b1", Text: moved}); !ok {
		t.Error("a command moved to the background")
	}
	for _, it := range []model.Item{
		{Tool: "Read", TaskID: "b1", Text: started}, // a README that says it
		{Tool: "Bash", Text: started},               // a foreground command that prints it
		{Tool: "Bash", TaskID: "b9", Text: started}, // another task's file
		{Tool: "Bash", TaskID: "b1", Text: "Command running in background with ID: b1. Output is being written to: /etc/b1.output."},
		// A file of the right name elsewhere: a project's, or out of Claude's folder (integrations review 2026-11-04).
		{Tool: "Bash", TaskID: "b1", Text: "Command running in background with ID: b1. Output is being written to: /Users/me/app/tasks/b1.output."},
		{Tool: "Bash", TaskID: "b1", Text: "Command running in background with ID: b1. Output is being written to: " + filepath.Dir(dir) + "/../../../../x/tasks/b1.output."},
		// A claude-<uid> folder out of Claude's temp root, or not three
		// folders up (fix review 2026-11-04).
		{Tool: "Bash", TaskID: "b1", Text: "Command running in background with ID: b1. Output is being written to: /Users/me/app/vendor/" + user + "/p/s/tasks/b1.output."},
		{Tool: "Bash", TaskID: "b1", Text: "Command running in background with ID: b1. Output is being written to: " + filepath.Join(tmp, user, "p", "tasks") + "/b1.output."},
		{Tool: "Bash", TaskID: "b1", Text: "Command running in background with ID: b1. Output is being written to: " + filepath.Join(tmp, "x", user, "p", "s", "tasks") + "/b1.output."},
	} {
		if _, _, ok := harness.BackgroundCommand(it); ok {
			t.Errorf("followed %+v", it)
		}
	}
	// The owner's server (2026-11-17), stopped by TaskStop, logged its
	// shutdown after Claude's "[killed]".
	const served = "SIGTERM exit code: 0\ntime=12:51:34 level=INFO msg=\"serving http\" addr=:9030\n"
	const shutdown = "time=12:54:20 level=INFO msg=\"shutting down server\"\ntime=12:54:20 level=INFO msg=\"server stopped\"\n"
	for text, want := range map[string][3]string{
		"":                               {"", "", ""},
		"half\n":                         {"half\n", "", ""},
		"done\n\n[exited with code 0]\n": {"done", "exited with code 0", "done"},
		"oops\n\n[exited with code 2]\n": {"oops", "exited with code 2", "failed"},
		"\n[killed]\n":                   {"", "killed", "stopped"},
		"[killed]\n":                     {"[killed]\n", "", ""},
		"x [exited with code 0]\n":       {"x [exited with code 0]\n", "", ""},
		// Output after the end line: the whole file shows.
		"\n[killed]\nmore\n":                   {"\n[killed]\nmore\n", "killed", "stopped"},
		served + "\n[killed]\n" + shutdown:     {served + "\n[killed]\n" + shutdown, "killed", "stopped"},
		"a\n\n[exited with code 144]\nstray\n": {"a\n\n[exited with code 144]\nstray\n", "exited with code 144", "failed"},
		// The last such line is taken: one the command printed comes before Claude's.
		"[killed]\nb\n\n[killed] not alone\n\n[exited with code 0]\n": {"[killed]\nb\n\n[killed] not alone", "exited with code 0", "done"},
		"\n[exited with code 0]\nmid\n\n[killed]\n":                   {"\n[exited with code 0]\nmid", "killed", "stopped"},
	} {
		testcheck.NoErr(t, os.WriteFile(file, []byte(text), 0o600))
		if out, end, state, err := harness.ReadBackgroundCommand("b1", file); err != nil || out != want[0] || end != want[1] || state != want[2] {
			t.Errorf("harness.ReadBackgroundCommand(%q) = %q %q %q %v", text, out, end, state, err)
		}
	}
	testcheck.NoErr(t, os.WriteFile(file, []byte("half\n"), 0o600))
	if size, modified, err := harness.StatBackgroundCommand("b1", file); err != nil || size != 5 || modified.IsZero() {
		t.Errorf("harness.StatBackgroundCommand = %d %v %v", size, modified, err)
	}
	link := filepath.Join(dir, "b2.output")
	testcheck.NoErr(t, os.Symlink(file, link))
	if _, _, _, err := harness.ReadBackgroundCommand("b2", link); err == nil {
		t.Error("read through a link")
	}
	if _, _, err := harness.StatBackgroundCommand("b2", link); err == nil {
		t.Error("stat through a link")
	}
	other := filepath.Join(t.TempDir(), "tasks")
	testcheck.NoErr(t, os.Mkdir(other, 0o700))
	testcheck.Write(t, filepath.Join(other, "b3.output"), "a project's file")
	if _, _, _, err := harness.ReadBackgroundCommand("b3", filepath.Join(other, "b3.output")); err == nil {
		t.Error("read a task's file out of Claude's folder")
	}
	if _, _, err := harness.StatBackgroundCommand("b3", filepath.Join(other, "b3.output")); err == nil {
		t.Error("stat a task's file out of Claude's folder")
	}
	vendored := filepath.Join(t.TempDir(), "vendor", user, "p", "s", "tasks")
	testcheck.NoErr(t, os.MkdirAll(vendored, 0o700))
	testcheck.Write(t, filepath.Join(vendored, "b4.output"), "a project's file")
	if _, _, _, err := harness.ReadBackgroundCommand("b4", filepath.Join(vendored, "b4.output")); err == nil {
		t.Error("read a claude-<uid> folder out of Claude's temp root")
	}
	t.Setenv("CLAUDE_CODE_TMPDIR", "")
	if !taskFile("b1", "/tmp/"+user+"/-Users-me-app/s1/tasks/b1.output") {
		t.Error("refused a task's file in /tmp")
	}
	if runtime.GOOS == "darwin" && !taskFile("b1", "/private/tmp/"+user+"/-Users-me-app/s1/tasks/b1.output") {
		t.Error("refused a task's file in /tmp's real path")
	}
}

// Claude's task, as claude-acp-go v0.5.0 sends it on the Bash call
// (docs/facts/claude.md), in Nushi's words: the state, and how it ended
// in the file's words, the exit code only from the summary.
func TestCommandTask(t *testing.T) {
	task := func(status, summary string) map[string]any {
		return map[string]any{"claudeCode": map[string]any{"toolName": "Bash", "task": map[string]any{
			"id": "b1", "type": "local_bash", "status": status, "summary": summary}}}
	}
	for _, tc := range []struct {
		meta       map[string]any
		state, end string
		ok         bool
	}{
		{task("running", ""), "running", "", true},
		{task("completed", ""), "done", "", true},
		{task("completed", `Background command "Run it" completed (exit code 0)`), "done", "exited with code 0", true},
		{task("failed", `Background command "Wait (exit code 3)" failed with exit code 144`), "failed", "exited with code 144", true},
		{task("failed", "Background command \"x\" failed with exit code 144\nmore"), "failed", "", true},
		{task("killed", ""), "stopped", "killed", true},
		{task("stopped", "Wait long"), "stopped", "killed", true},
		{task("pending", ""), "", "", false},
		{map[string]any{"claudeCode": map[string]any{"task": map[string]any{"id": "b1", "type": "local_agent", "status": "completed"}}}, "", "", false},
		{map[string]any{"claudeCode": map[string]any{"toolName": "Bash"}}, "", "", false},
		{nil, "", "", false},
	} {
		id, state, end, ok := Harness{}.CommandTask(tc.meta)
		if ok != tc.ok || state != tc.state || end != tc.end || ok && id != "b1" {
			t.Errorf("%v: %q %q %q %v", tc.meta, id, state, end, ok)
		}
	}
}

// Any task of Claude's is its word on a task, a command's or not.
func TestTaskWord(t *testing.T) {
	for _, tc := range []struct {
		meta map[string]any
		want bool
	}{
		{map[string]any{"claudeCode": map[string]any{"task": map[string]any{"id": "b1", "type": "local_bash", "status": "running"}}}, true},
		{map[string]any{"claudeCode": map[string]any{"toolName": "Workflow", "task": map[string]any{"id": "w1", "type": "local_workflow", "status": "killed"}}}, true},
		{map[string]any{"claudeCode": map[string]any{"task": map[string]any{"type": "local_workflow"}}}, false},
		{map[string]any{"claudeCode": map[string]any{"toolName": "Workflow"}}, false},
		{nil, false},
	} {
		if got := (Harness{}).TaskWord(tc.meta); got != tc.want {
			t.Errorf("%v: %v", tc.meta, got)
		}
	}
}
