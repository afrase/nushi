package trust

import (
	"errors"
	"path/filepath"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

type agent struct {
	key     string
	trusted bool   // trusted by the agent itself (Claude's, of the repository)
	file    string // the file, under the folder, that runs something; "" for x's
}

func (a *agent) Runs(folder string) ([]model.FolderRun, string, error) {
	if a.file != "" {
		return []model.FolderRun{{File: filepath.Join(folder, a.file), What: "MCP server x", Command: folder + "/bin/x"}}, a.key, nil
	}
	return []model.FolderRun{{What: "MCP server x"}}, a.key, nil
}
func (a *agent) Key(string) string                      { return a.key }
func (a *agent) Trusted(string, []string) (bool, error) { return a.trusted, nil }

type store struct{ keys []string }

func (s *store) TrustedFolders() ([]string, error) { return s.keys, nil }
func (s *store) TrustFolder(k string) error        { s.keys = append(s.keys, k); return nil }

// A folder the user started anyway, its key unchanged, shows no card, for
// an agent whose own Trusted knows nothing of Nushi's keys.
func TestCheckFindsStartAnywaysKey(t *testing.T) {
	a, st := &agent{key: "k1"}, &store{}
	s := New(map[string]Agent{"x": a}, st)
	if runs, key, err := s.Check("x", "/f"); err != nil || len(runs) != 1 || key != "k1" {
		t.Fatalf("runs %v, key %q, %v", runs, key, err)
	}
	st.keys = []string{"k1"}
	if runs, key, err := s.Check("x", "/f"); err != nil || len(runs) != 0 || key != "" {
		t.Errorf("a folder started anyway: runs %v, key %q, %v", runs, key, err)
	}
	a.key = ""
	if runs, _, _ := s.Check("x", "/f"); len(runs) != 1 {
		t.Error("a folder without a key was trusted")
	}
}

// Start anyway keeps the key the card came with, only while the folder
// still has it; a folder without one is never kept.
func TestTrustKeepsWhatTheCardShowed(t *testing.T) {
	a, st := &agent{key: "k1"}, &store{}
	s := New(map[string]Agent{"x": a}, st)
	_, key, err := s.Check("x", "/f")
	if err != nil || key != "k1" {
		t.Fatalf("key %q, %v", key, err)
	}
	a.key = "k2" // the folder changed after the card showed
	if err := s.Trust("x", "/f", key); !errors.Is(err, ErrChanged) || len(st.keys) > 0 {
		t.Errorf("trusted a folder that changed since its card: %v %v", err, st.keys)
	}
	a.key = ""
	if err := s.Trust("x", "/f", ""); !errors.Is(err, ErrChanged) || len(st.keys) > 0 {
		t.Errorf("kept a folder without a key: %v", st.keys)
	}
	a.key = "k1"
	if err := s.Trust("x", "/f", "k1"); err != nil || len(st.keys) != 1 {
		t.Errorf("%v %v", err, st.keys)
	}
}

// A pull request's head is checked where it starts: what it runs comes
// back for the card, and a start again with its key (in another worktree
// of the same head) goes ahead; a head of the repository's own is then
// remembered, as a folder's card is.
// Two commits a head can be at.
const c1, c2 = "1111111111111111111111111111111111111111", "2222222222222222222222222222222222222222"

func TestAPullRequestsHead(t *testing.T) {
	a, st := &agent{key: "repo", file: ".mcp.json"}, &store{}
	s := New(map[string]Agent{"x": a}, st)
	err := s.Head("x", "/repo/.worktrees/a", c1, false, "")
	var head *UntrustedHeadError
	if !errors.As(err, &head) || head.Folder != "/repo/.worktrees/a" || len(head.Runs) != 1 || head.Shown == "" {
		t.Fatalf("Head = %v", err)
	}
	if err := s.Head("x", "/repo/.worktrees/b", c1, false, "other"); !errors.As(err, &head) {
		t.Fatalf("a key of something else let it start: %v", err)
	}
	if err := s.Head("x", "/repo/.worktrees/c", c1, false, head.Shown); err != nil || !slices.Equal(st.keys, []string{"repo"}) {
		t.Fatalf("Start anyway: %v, kept %v", err, st.keys)
	}
	if err := s.Head("x", "/repo/.worktrees/d", c1, false, ""); err != nil {
		t.Errorf("a trusted repository's own head asked again: %v", err)
	}
	a.file = ".claude/settings.json" // the head changed after the card showed
	if err := s.Head("x", "/repo/.worktrees/e", c1, false, head.Shown); err != nil {
		t.Errorf("trusted, yet asked: %v", err)
	}
}

// A fork's head is an outsider's: what the agent or the user trusted of
// the repository doesn't cover it, and Start anyway is never remembered.
func TestAForksHead(t *testing.T) {
	a, st := &agent{key: "repo", trusted: true, file: ".mcp.json"}, &store{keys: []string{"repo"}}
	s := New(map[string]Agent{"x": a}, st)
	if runs, _, err := s.Check("x", "/repo/.worktrees/a"); err != nil || len(runs) != 0 {
		t.Fatalf("the repository isn't trusted: %v %v", runs, err)
	}
	var head *UntrustedHeadError
	if err := s.Head("x", "/repo/.worktrees/a", c1, true, ""); !errors.As(err, &head) {
		t.Fatalf("a fork's head rode on the repository's trust: %v", err)
	}
	if err := s.Head("x", "/repo/.worktrees/b", c1, true, head.Shown); err != nil || len(st.keys) != 1 {
		t.Fatalf("Start anyway: %v, kept %v", err, st.keys)
	}
	if err := s.Head("x", "/repo/.worktrees/c", c1, true, ""); !errors.As(err, &head) {
		t.Errorf("a fork's head was remembered: %v", err)
	}
	// Pushed again between the card and the start: the same listed runs,
	// but not the commit the card showed.
	if err := s.Head("x", "/repo/.worktrees/d", c2, true, head.Shown); !errors.As(err, &head) {
		t.Errorf("Start anyway let another commit start: %v", err)
	}
	if err := s.Head("x", "/repo/.worktrees/e", "", true, ""); err == nil || errors.As(err, &head) {
		t.Errorf("a head with no commit: %v", err)
	}
}
