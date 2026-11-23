package main

import (
	"bytes"
	"errors"
	"os"
	"strings"
	"testing"
)

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

// A host that fails or gives other bytes is passed over for the next; the
// file it gives is cached, and the next build reads it from there.
func TestLockedFallsBackAndCaches(t *testing.T) {
	good := []byte("mermaid's script")
	p := pin{version: "1.2.3", sum: sumOf(good), size: len(good)}
	cache := t.TempDir()
	var asked []string
	got, err := locked(p, cache, func(url string) ([]byte, error) {
		asked = append(asked, url)
		if strings.Contains(url, "jsdelivr") {
			return nil, errors.New("jsDelivr is down")
		}
		return good, nil
	})
	if err != nil || !bytes.Equal(got, good) || len(asked) != 2 {
		t.Fatalf("got %q, %v after %v", got, err, asked)
	}
	got, err = locked(p, cache, func(url string) ([]byte, error) {
		t.Errorf("fetched %s with the file cached", url)
		return nil, errors.New("no network")
	})
	if err != nil || !bytes.Equal(got, good) {
		t.Fatalf("from the cache: %q, %v", got, err)
	}
}

// Bytes that aren't the locked file are refused from every host, and
// nothing is cached.
func TestLockedRefusesOtherBytes(t *testing.T) {
	p := pin{version: "1.2.3", sum: sumOf([]byte("the real one")), size: 12}
	cache := t.TempDir()
	_, err := locked(p, cache, func(string) ([]byte, error) { return []byte("something else"), nil })
	if err == nil || !strings.Contains(err.Error(), "unpkg") || !strings.Contains(err.Error(), "jsdelivr") {
		t.Fatalf("got %v, want both hosts refused", err)
	}
	if entries, _ := os.ReadDir(cache); len(entries) != 0 {
		t.Errorf("cached %v", entries)
	}
}
