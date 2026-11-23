package store

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

func TestCache(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	var got []int
	if when, err := s.Cached("jira", "a.atlassian.net", "list mine", &got); err != nil || got != nil || !when.IsZero() {
		t.Fatalf("an empty cache: %v %v %v", when, got, err)
	}
	before := time.Now()
	if err := s.Cache("jira", "a.atlassian.net", "list mine", []int{1}); err != nil {
		t.Fatal(err)
	}
	when, err := New(dir).Cached("jira", "a.atlassian.net", "list mine", &got)
	if err != nil || fmt.Sprint(got) != "[1]" || when.Before(before) || when.After(time.Now()) {
		t.Fatalf("%v %v %v", when, got, err)
	}
	var other []int
	if _, _ = s.Cached("jira", "b.atlassian.net", "list mine", &other); other != nil {
		t.Error("another site's file had it")
	}
	var wrong string
	if when, err := s.Cached("jira", "a.atlassian.net", "list mine", &wrong); err != nil || !when.IsZero() {
		t.Errorf("an answer that doesn't fit: %v %v", when, err)
	}
	for _, p := range []string{filepath.Join(dir, "cache", "jira"), filepath.Join(dir, "cache", "jira", "a.atlassian.net.json")} {
		fi, err := os.Stat(p)
		if err != nil || fi.Mode().Perm()&0o077 != 0 {
			t.Errorf("%s: %v, %v", p, fi.Mode(), err)
		}
	}
	for _, name := range []string{"", "..", "../x", "a/b"} {
		if err := s.Cache("jira", name, "k", 1); err == nil {
			t.Errorf("a cache named %q", name)
		}
	}
	if err := s.ForgetCache("jira", "a.atlassian.net"); err != nil {
		t.Fatal(err)
	}
	if when, _ := s.Cached("jira", "a.atlassian.net", "list mine", &got); !when.IsZero() {
		t.Error("kept after ForgetCache")
	}
}

// A full file loses its oldest answer to a new one. The file is written
// whole first, its answers an hour apart, so which is oldest is known.
func TestCacheDropsOldest(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	at := time.Now().Add(-time.Duration(cacheKeys+1) * time.Hour)
	full := map[string]cached{}
	for i := range cacheKeys {
		full[fmt.Sprint("issue ", i)] = cached{At: at.Add(time.Duration(i) * time.Hour), Data: json.RawMessage(`2`)}
	}
	testcheck.Write(t, filepath.Join(dir, "cache", "jira", "a.atlassian.net.json"), testcheck.JSON(t, full))
	if err := s.Cache("jira", "a.atlassian.net", "list mine", 1); err != nil {
		t.Fatal(err)
	}
	var n int
	if when, _ := s.Cached("jira", "a.atlassian.net", "issue 0", &n); !when.IsZero() {
		t.Error("the oldest stayed")
	}
	for _, key := range []string{"issue 1", fmt.Sprint("issue ", cacheKeys-1), "list mine"} {
		if when, _ := s.Cached("jira", "a.atlassian.net", key, &n); when.IsZero() {
			t.Errorf("%s went", key)
		}
	}
}

// A cache file is replaced through a file beside it, never written
// through a link at its path, and leaves no other file behind.
func TestCacheReplacesALink(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	elsewhere := filepath.Join(t.TempDir(), "elsewhere")
	testcheck.Write(t, elsewhere, "mine")
	folder := filepath.Join(dir, "cache", "github")
	testcheck.NoErr(t, os.MkdirAll(folder, 0o700))
	testcheck.NoErr(t, os.Symlink(elsewhere, filepath.Join(folder, "github.com.json")))
	testcheck.NoErr(t, s.Cache("github", "github.com", "inbox", 1))
	if b, _ := os.ReadFile(elsewhere); string(b) != "mine" {
		t.Errorf("the link's file was written: %q", b)
	}
	if fi, err := os.Lstat(filepath.Join(folder, "github.com.json")); err != nil || !fi.Mode().IsRegular() || fi.Mode().Perm() != 0o600 {
		t.Errorf("the cache file: %v, %v", fi, err)
	}
	if entries, _ := os.ReadDir(folder); len(entries) != 1 {
		t.Errorf("left beside it: %v", entries)
	}
}
