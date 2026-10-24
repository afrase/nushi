package trust

import (
	"errors"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

type agent struct{ key string }

func (a *agent) Runs(string) ([]model.FolderRun, string, error) {
	return []model.FolderRun{{What: "MCP server x"}}, a.key, nil
}
func (a *agent) Key(string) string                      { return a.key }
func (a *agent) Trusted(string, []string) (bool, error) { return false, nil }

type store struct{ keys []string }

func (s *store) TrustedFolders() ([]string, error) { return s.keys, nil }
func (s *store) TrustFolder(k string) error        { s.keys = append(s.keys, k); return nil }

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
