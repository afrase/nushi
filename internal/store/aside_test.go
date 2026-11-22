package store

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// broken is a file a hand edit's typo left: not JSON at all.
const broken = `{"keepTranscripts": fals, "claude": {}}`

// asideOf returns the files set aside for name in dir.
func asideOf(t *testing.T, dir, name string) []string {
	t.Helper()
	aside, err := filepath.Glob(filepath.Join(dir, name+".unreadable-*"))
	testcheck.NoErr(t, err)
	return aside
}

// A file that doesn't parse is set aside as it's read, beside it as
// <name>.unreadable-<time>, byte for byte, and reads as the empty state;
// the next change writes what Nushi knows and replaces nothing unread.
func TestAFileThatDoesntParseIsSetAsideOnRead(t *testing.T) {
	for _, tc := range []struct {
		name   string
		read   func(*Store) (empty bool, err error)
		change func(*Store) error
	}{
		{"settings.json", func(s *Store) (bool, error) { return s.KeepTranscripts() && !s.DebugLog(), nil }, func(s *Store) error { return s.SetDebugLog(true) }},
		{"agents.json", func(s *Store) (bool, error) { return s.Mode("claude") == "", nil }, func(s *Store) error { return s.SetMode("claude", "plan") }},
		{"trusted.json", func(s *Store) (bool, error) { f, err := s.TrustedFolders(); return f == nil, err }, func(s *Store) error { return s.TrustFolder("/x") }},
		{"github.json", func(s *Store) (bool, error) { h, err := s.GitHubTokenHosts(); return h == nil, err }, func(s *Store) error { return s.SaveGitHubTokenHosts([]string{"github.com"}) }},
		{"jira.json", func(s *Store) (bool, error) { j, err := s.JiraSites(); return j == nil, err }, func(s *Store) error { return s.SaveJiraSites([]model.JiraSite{{URL: "https://a"}}) }},
		{"jira-writes.json", func(s *Store) (bool, error) { w, err := s.JiraWrites(); return w == nil, err }, func(s *Store) error { return s.SaveJiraWrites([]model.JiraWrite{{Key: "A-1"}}) }},
		{"remote.json", func(s *Store) (bool, error) { r, err := s.Remote(); return r == model.RemoteSettings{}, err }, func(s *Store) error { return s.SaveRemote(model.RemoteSettings{On: true}) }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			testcheck.Write(t, filepath.Join(dir, tc.name), broken)
			s := New(dir)
			if empty, err := tc.read(s); err != nil || !empty {
				t.Fatalf("read: empty %v, %v", empty, err)
			}
			aside := asideOf(t, dir, tc.name)
			if len(aside) != 1 {
				t.Fatalf("set aside as it was read: %v", aside)
			}
			if b, err := os.ReadFile(aside[0]); err != nil || string(b) != broken {
				t.Errorf("set aside %q, %v", b, err)
			}
			if _, err := os.Lstat(filepath.Join(dir, tc.name)); !os.IsNotExist(err) {
				t.Errorf("the file stayed: %v", err)
			}
			testcheck.NoErr(t, tc.change(s))
			if empty, err := tc.read(New(dir)); err != nil || empty {
				t.Errorf("the change wasn't written: %v", err)
			}
			if again := asideOf(t, dir, tc.name); len(again) != 1 {
				t.Errorf("set aside again: %v", again)
			}
		})
	}
}

// The phones' keys and pairings, and the Web Push key, still refuse a
// file that doesn't parse, as before the set-aside rule: the owner hasn't
// decided whether a fresh key (every phone pairing again) is worth it.
// The file is left as it was.
func TestPhoneKeyFilesRefuseAFileThatDoesntParse(t *testing.T) {
	for name, read := range map[string]func(*Store) error{
		"remote-key.json": func(s *Store) error { _, _, err := s.RemoteKey(); return err },
		"devices.json":    func(s *Store) error { _, err := s.Devices(); return err },
		"vapid.json":      func(s *Store) error { _, _, err := s.VAPIDKey(); return err },
	} {
		t.Run(name, func(t *testing.T) {
			dir := t.TempDir()
			for _, body := range []string{broken, `{"private": 7}`, `[{"id": 7}]`} {
				testcheck.Write(t, filepath.Join(dir, name), body)
				if err := read(New(dir)); err == nil {
					t.Errorf("%s read", body)
				}
				if b, err := os.ReadFile(filepath.Join(dir, name)); err != nil || string(b) != body {
					t.Errorf("the file changed: %q, %v", b, err)
				}
			}
			if aside := asideOf(t, dir, name); len(aside) != 0 {
				t.Errorf("set aside: %v", aside)
			}
		})
	}
}

// A file whose only fault is a field of another shape (a newer build's,
// read by an older one going back: ADR 0108) keeps its other fields, and
// isn't set aside.
func TestAFieldOfAnotherShapeKeepsTheRest(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "settings.json"), `{"transcriptDays": "soon", "debugLog": true}`)
	testcheck.Write(t, filepath.Join(dir, "agents.json"), `{"claude": {"mode": "plan", "picks": ["a"]}}`)
	s := New(dir)
	if !s.DebugLog() || s.TranscriptDays() != 0 {
		t.Errorf("settings: debug %v, days %v", s.DebugLog(), s.TranscriptDays())
	}
	if s.Mode("claude") != "plan" {
		t.Errorf("agents: mode %q", s.Mode("claude"))
	}
	if aside, _ := filepath.Glob(filepath.Join(dir, "*.unreadable-*")); len(aside) != 0 {
		t.Errorf("set aside: %v", aside)
	}
}
