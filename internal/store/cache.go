package store

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/atomicfile"
)

// cacheKeys is how many answers a cache file keeps; the oldest go first.
const cacheKeys = 40

type cached struct {
	At   time.Time       `json:"at"`
	Data json.RawMessage `json:"data"`
}

// cachePath is cache/<area>/<name>.json, a file of one area's answers
// from one place (a Jira site, a GitHub host). The folders are 0700 and
// the file 0600: the answers are the user's own data.
func (s *Store) cachePath(area, name string) (string, error) {
	for _, part := range []string{area, name} {
		if part == "" || part == "." || part == ".." || filepath.Base(part) != part {
			return "", fmt.Errorf("a cache named %q", part)
		}
	}
	return filepath.Join(s.dir, "cache", area, name+".json"), nil
}

func (s *Store) cacheFile(path string) (map[string]cached, error) {
	m := map[string]cached{}
	b, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return m, nil
	}
	if err != nil {
		return nil, err
	}
	if json.Unmarshal(b, &m) != nil {
		clear(m) // a broken cache is an empty one
	}
	return m, nil
}

// Cached is the answer kept under key in area's file for name, and when
// it came; nil when there is none.
func (s *Store) Cached(area, name, key string) (time.Time, json.RawMessage, error) {
	path, err := s.cachePath(area, name)
	if err != nil {
		return time.Time{}, nil, err
	}
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()
	m, err := s.cacheFile(path)
	c := m[key]
	return c.At, c.Data, err
}

// Cache keeps data under key in area's file for name, as it came at at,
// the file replaced at once (atomicfile).
func (s *Store) Cache(area, name, key string, at time.Time, data json.RawMessage) error {
	path, err := s.cachePath(area, name)
	if err != nil {
		return err
	}
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()
	m, err := s.cacheFile(path)
	if err != nil {
		return err
	}
	m[key] = cached{At: at, Data: data}
	for len(m) > cacheKeys {
		oldest := slices.MinFunc(slices.Collect(maps.Keys(m)), func(a, b string) int { return m[a].At.Compare(m[b].At) })
		delete(m, oldest)
	}
	b, err := json.Marshal(m)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	return atomicfile.Replace(path, b, 0o600)
}

// ForgetCache removes area's file for name.
func (s *Store) ForgetCache(area, name string) error {
	path, err := s.cachePath(area, name)
	if err != nil {
		return err
	}
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()
	if err := os.Remove(path); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	return nil
}
