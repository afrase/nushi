package claude

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

func TestBackgroundShells(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "tasks")
	noErr(t, os.Mkdir(dir, 0o700))
	file := filepath.Join(dir, "b1.output")
	started := "```console\nCommand running in background with ID: b1. Output is being written to: " + file + ". You will be notified when it completes.\n```"
	id, got, ok := Shell(model.Item{Tool: "Bash", TaskID: "b1", Text: started})
	if !ok || id != "b1" || got != file {
		t.Fatalf("Shell = %q %q %v", id, got, ok)
	}
	// Replayed: no task id, but its input asked for the background.
	if id, _, ok := Shell(model.Item{Tool: "Bash", InBackground: true, Text: started}); !ok || id != "b1" {
		t.Error("a replayed background command")
	}
	// Moved to the background after its timeout.
	moved := "Command did not complete within its 120s timeout and was moved to the background (ID: b1). Output is being written to: " + file + "."
	if _, _, ok := Shell(model.Item{Tool: "Bash", TaskID: "b1", Text: moved}); !ok {
		t.Error("a command moved to the background")
	}
	for _, it := range []model.Item{
		{Tool: "Read", TaskID: "b1", Text: started}, // a README that says it
		{Tool: "Bash", Text: started},               // a foreground command that prints it
		{Tool: "Bash", TaskID: "b9", Text: started}, // another task's file
		{Tool: "Bash", TaskID: "b1", Text: "Command running in background with ID: b1. Output is being written to: /etc/b1.output."},
	} {
		if _, _, ok := Shell(it); ok {
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
		noErr(t, os.WriteFile(file, []byte(text), 0o600))
		if out, end, err := ReadShell("b1", file); err != nil || out != want[0] || end != want[1] {
			t.Errorf("ReadShell(%q) = %q %q %v", text, out, end, err)
		}
	}
	link := filepath.Join(dir, "b2.output")
	noErr(t, os.Symlink(file, link))
	if _, _, err := ReadShell("b2", link); err == nil {
		t.Error("read through a link")
	}
}
