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

// Cached reads the answer kept under key in area's file for name into v,
// and says when it came: zero when there is none or it doesn't fit v.
func (s *Store) Cached(area, name, key string, v any) (time.Time, error) {
	path, err := s.cachePath(area, name)
	if err != nil {
		return time.Time{}, err
	}
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()
	m, err := s.cacheFile(path)
	if err != nil {
		return time.Time{}, err
	}
	c, ok := m[key]
	if !ok || json.Unmarshal(c.Data, v) != nil {
		return time.Time{}, nil
	}
	return c.At, nil
}

// Cache keeps v, as JSON, under key in area's file for name, as it is
// now, the file replaced at once (replaceCache).
func (s *Store) Cache(area, name, key string, v any) error {
	path, err := s.cachePath(area, name)
	if err != nil {
		return err
	}
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}
	at := time.Now()
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
	return replaceCache(path, b)
}

// replaceCache puts b in place of the cache file at path through a new
// file beside it, renamed over it (a link at path is replaced, not
// followed), but with no fsync: a cache can be rebuilt from the next
// answer, and a file a crash left empty or torn reads as an empty cache
// (cacheFile). The fsyncs (F_FULLFSYNC on macOS) were most of the cost of
// a poll's write, which GitHub makes under its service's lock.
func replaceCache(path string, b []byte) error {
	f, err := os.CreateTemp(filepath.Dir(path), ".nushi-*") // 0600
	if err != nil {
		return err
	}
	_, err = f.Write(b)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Rename(f.Name(), path)
	}
	if err != nil {
		_ = os.Remove(f.Name()) // the write's error is the one to return
	}
	return err
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
