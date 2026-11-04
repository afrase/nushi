package main

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// Claude's old adapter folder goes, and Codex's beside it stays.
func TestClaudesOldAdapterIsRemoved(t *testing.T) {
	agents := t.TempDir()
	testcheck.Write(t, filepath.Join(agents, "claude", "node_modules", "x.js"), "x")
	testcheck.Write(t, filepath.Join(agents, "codex", "package.json"), "{}")
	removeClaudeAdapter(filepath.Join(agents, "claude"))
	if _, err := os.Stat(filepath.Join(agents, "claude")); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("claude's adapter: %v", err)
	}
	if _, err := os.Stat(filepath.Join(agents, "codex", "package.json")); err != nil {
		t.Errorf("codex's adapter: %v", err)
	}
	removeClaudeAdapter(filepath.Join(agents, "claude")) // none: nothing to do
}
