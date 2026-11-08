package ante

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// Another process's open file is found by the path asked, though that
// path goes through a link (the kernel names the file by its resolved
// path).
func TestOpenFilesElsewhere(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "target")
	testcheck.NoErr(t, os.MkdirAll(target, 0o700))
	testcheck.NoErr(t, os.Symlink(target, filepath.Join(dir, "linked")))
	file := filepath.Join(target, "events.jsonl")
	testcheck.NoErr(t, os.WriteFile(file, nil, 0o600))
	cmd := exec.CommandContext(t.Context(), "/bin/sh", "-c", `exec 3>>"$1"; exec sleep 30`, "sh", file)
	testcheck.NoErr(t, cmd.Start())
	t.Cleanup(func() { _ = cmd.Process.Kill(); _ = cmd.Wait() })
	asked := filepath.Join(dir, "linked", "events.jsonl")
	if !testcheck.Eventually(func() bool {
		return openFiles([]string{asked}, filepath.Base)["events.jsonl"] == "another app"
	}) {
		t.Error("another process's open file wasn't found")
	}
}
