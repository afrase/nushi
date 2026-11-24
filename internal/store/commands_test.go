package store

import (
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// TestCommandsAreACache: an agent's slash commands are kept in the cache
// (cache/commands/<agent>.json, 0600), not agents.json, which a list
// changing leaves alone; a list kept in agents.json by an older build is
// not read (lost once, until the agent lists again), and its mode stays.
func TestCommandsAreACache(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "agents.json"),
		`{"claude": {"mode": "plan", "commands": [{"name": "old"}]}}`)
	s := New(dir)
	if got := s.Commands("claude"); got != nil {
		t.Fatalf("agents.json's list read: %v", got)
	}
	before, err := os.ReadFile(filepath.Join(dir, "agents.json"))
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, s.SetCommands("claude", []model.Command{{Name: "init"}, {Name: "compact", Hint: "what to keep"}}))
	got := s.Commands("claude")
	if !slices.Equal(got, []model.Command{{Name: "init"}, {Name: "compact", Hint: "what to keep"}}) {
		t.Fatalf("commands %v", got)
	}
	if s.Commands("codex") != nil {
		t.Fatal("another agent's list")
	}
	after, err := os.ReadFile(filepath.Join(dir, "agents.json"))
	testcheck.NoErr(t, err)
	if string(after) != string(before) || s.Mode("claude") != "plan" {
		t.Fatalf("agents.json changed: %s", after)
	}
	fi, err := os.Stat(filepath.Join(dir, "cache", "commands", "claude.json"))
	testcheck.NoErr(t, err)
	if fi.Mode().Perm() != 0o600 {
		t.Fatalf("the cache file is %v", fi.Mode().Perm())
	}
}
