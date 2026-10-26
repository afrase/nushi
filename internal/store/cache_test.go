package store

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestCache(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	at := time.Date(2026, 10, 26, 9, 0, 0, 0, time.UTC)
	if when, data, err := s.Cached("jira", "a.atlassian.net", "list mine"); err != nil || data != nil || !when.IsZero() {
		t.Fatalf("an empty cache: %v %s %v", when, data, err)
	}
	if err := s.Cache("jira", "a.atlassian.net", "list mine", at, json.RawMessage(`[1]`)); err != nil {
		t.Fatal(err)
	}
	when, data, err := New(dir).Cached("jira", "a.atlassian.net", "list mine")
	if err != nil || string(data) != "[1]" || !when.Equal(at) {
		t.Fatalf("%v %s %v", when, data, err)
	}
	if _, data, _ := s.Cached("jira", "b.atlassian.net", "list mine"); data != nil {
		t.Error("another site's file had it")
	}
	for _, p := range []string{filepath.Join(dir, "cache", "jira"), filepath.Join(dir, "cache", "jira", "a.atlassian.net.json")} {
		fi, err := os.Stat(p)
		if err != nil || fi.Mode().Perm()&0o077 != 0 {
			t.Errorf("%s: %v, %v", p, fi.Mode(), err)
		}
	}
	for _, name := range []string{"", "..", "../x", "a/b"} {
		if err := s.Cache("jira", name, "k", at, json.RawMessage(`1`)); err == nil {
			t.Errorf("a cache named %q", name)
		}
	}
	// The oldest go past cacheKeys.
	for i := range cacheKeys + 2 {
		if err := s.Cache("jira", "a.atlassian.net", fmt.Sprint("issue ", i), at.Add(time.Duration(i+1)*time.Minute), json.RawMessage(`2`)); err != nil {
			t.Fatal(err)
		}
	}
	if _, data, _ := s.Cached("jira", "a.atlassian.net", "list mine"); data != nil {
		t.Error("the oldest stayed")
	}
	if _, data, _ := s.Cached("jira", "a.atlassian.net", "issue 41"); data == nil {
		t.Error("the newest went")
	}
	if err := s.ForgetCache("jira", "a.atlassian.net"); err != nil {
		t.Fatal(err)
	}
	if _, data, _ := s.Cached("jira", "a.atlassian.net", "issue 41"); data != nil {
		t.Error("kept after ForgetCache")
	}
}
