package main

import (
	"os"
	"path/filepath"
	"regexp"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
)

func TestMoveData(t *testing.T) {
	base, err := filepath.EvalSymlinks(t.TempDir()) // Claude names history by real paths
	if err != nil {
		t.Fatal(err)
	}
	projects := t.TempDir()
	old, dir := filepath.Join(base, "Nushi Next"), filepath.Join(base, "Nushi")
	scratch, repo := filepath.Join(old, "scratch", "c1"), t.TempDir()
	if err := os.MkdirAll(scratch, 0o700); err != nil {
		t.Fatal(err)
	}
	// Claude's history folder for a path (claudehistory's dirName, short paths).
	hist := func(folder string) string {
		return filepath.Join(projects, regexp.MustCompile(`[^A-Za-z0-9]`).ReplaceAllString(folder, "-"))
	}
	if err := os.MkdirAll(hist(scratch), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(hist(scratch), "s1.jsonl"), []byte("{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	st := store.New(old)
	for _, s := range []model.Session{
		{ID: "c1", SessionID: "s2", Folder: repo, Earlier: []model.AgentSession{{ID: "s1", Folder: scratch}}},
		{ID: "c2", SessionID: "s3", Folder: filepath.Join(old, "scratch", "c2")}, // never sent a message
	} {
		if err := st.SaveSession(s); err != nil {
			t.Fatal(err)
		}
	}

	if err := moveData(old, dir, projects); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(old); !os.IsNotExist(err) {
		t.Errorf("the old folder is still there: %v", err)
	}
	got, err := store.New(dir).Sessions()
	if err != nil {
		t.Fatal(err)
	}
	newScratch := filepath.Join(dir, "scratch", "c1")
	for _, s := range got {
		switch s.ID {
		case "c1":
			if s.Folder != repo || s.Earlier[0].Folder != newScratch {
				t.Errorf("c1: %+v", s)
			}
		case "c2":
			if s.Folder != filepath.Join(dir, "scratch", "c2") {
				t.Errorf("c2: %+v", s)
			}
		}
	}
	if _, err := os.Stat(filepath.Join(hist(newScratch), "s1.jsonl")); err != nil {
		t.Errorf("Claude's history wasn't copied: %v", err)
	}
	if _, err := os.Stat(filepath.Join(hist(scratch), "s1.jsonl")); err != nil {
		t.Errorf("the old history went: %v", err)
	}

	// Once moved, it's never moved again.
	if err := os.MkdirAll(old, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := moveData(old, dir, projects); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(old); err != nil {
		t.Error("a second move happened")
	}
}
