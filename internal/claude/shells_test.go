package claude

import (
	"os"
	"path/filepath"
	"testing"
)

func TestBackgroundShells(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "tasks")
	os.Mkdir(dir, 0o700)
	file := filepath.Join(dir, "b1.output")
	id, got, ok := Shell("```console\nCommand running in background with ID: b1. Output is being written to: " + file + ". You will be notified when it completes.\n```")
	if !ok || id != "b1" || got != file {
		t.Fatalf("Shell = %q %q %v", id, got, ok)
	}
	if _, _, ok := Shell("Command running in background with ID: b1. Output is being written to: /etc/passwd.output."); ok {
		t.Error("a file outside a tasks folder")
	}
	for text, want := range map[string][2]string{
		"":                               {"", ""},
		"half\n":                         {"half\n", ""},
		"done\n\n[exited with code 0]\n": {"done", "exited with code 0"},
		"oops\n\n[exited with code 2]\n": {"oops", "exited with code 2"},
		"\n[killed]\n":                   {"", "killed"},
	} {
		os.WriteFile(file, []byte(text), 0o600)
		if out, end, err := ReadShell("b1", file); err != nil || out != want[0] || end != want[1] {
			t.Errorf("ReadShell(%q) = %q %q %v", text, out, end, err)
		}
	}
	link := filepath.Join(dir, "b2.output")
	os.Symlink(file, link)
	if _, _, err := ReadShell("b2", link); err == nil {
		t.Error("read through a link")
	}
}
