package main

import "testing"

// The lock names a release, its file's sha256 and a size; a bad line stops.
func TestLock(t *testing.T) {
	p, err := parseLock(mermaidLock)
	if err != nil || !versionRef.MatchString(p.version) || len(p.sum) != 64 || p.size < 1<<20 {
		t.Fatalf("%+v, %v", p, err)
	}
	if _, err := parseLock(mermaidLock + "url https://example.com/mermaid.js\n"); err == nil {
		t.Error("a line it doesn't know was taken")
	}
	if _, err := parseLock("version 12.2.0\n"); err == nil {
		t.Error("a lock without a sum was taken")
	}
}
