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
	for text, want := range map[string][2]string{
		"":                               {"", ""},
		"half\n":                         {"half\n", ""},
		"done\n\n[exited with code 0]\n": {"done", "exited with code 0"},
		"oops\n\n[exited with code 2]\n": {"oops", "exited with code 2"},
		"\n[killed]\n":                   {"", "killed"},
		"[killed]\n":                     {"[killed]\n", ""},
		"x [exited with code 0]\n":       {"x [exited with code 0]\n", ""},
		"\n[killed]\nmore\n":             {"\n[killed]\nmore\n", ""},
	} {
		testcheck.NoErr(t, os.WriteFile(file, []byte(text), 0o600))
		if out, end, err := harness.ReadBackgroundCommand("b1", file); err != nil || out != want[0] || end != want[1] {
			t.Errorf("harness.ReadBackgroundCommand(%q) = %q %q %v", text, out, end, err)
		}
	}
	link := filepath.Join(dir, "b2.output")
	testcheck.NoErr(t, os.Symlink(file, link))
	if _, _, err := harness.ReadBackgroundCommand("b2", link); err == nil {
		t.Error("read through a link")
	}
	other := filepath.Join(t.TempDir(), "tasks")
	testcheck.NoErr(t, os.Mkdir(other, 0o700))
	testcheck.Write(t, filepath.Join(other, "b3.output"), "a project's file")
	if _, _, err := harness.ReadBackgroundCommand("b3", filepath.Join(other, "b3.output")); err == nil {
		t.Error("read a task's file out of Claude's folder")
	}
	vendored := filepath.Join(t.TempDir(), "vendor", user, "p", "s", "tasks")
	testcheck.NoErr(t, os.MkdirAll(vendored, 0o700))
	testcheck.Write(t, filepath.Join(vendored, "b4.output"), "a project's file")
	if _, _, err := harness.ReadBackgroundCommand("b4", filepath.Join(vendored, "b4.output")); err == nil {
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
