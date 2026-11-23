package store

import (
	"path/filepath"

	"github.com/afrase/nushi/internal/model"
)

// Remote access keeps four files, each 0600: remote.json (the switch and
// the relay), remote-key.json (the daemon's Noise key and listen keys),
// devices.json (the paired phones, their push subscriptions included) and
// vapid.json (the key Web Push messages are signed with).

func (s *Store) Remote() (model.RemoteSettings, error) {
	var r model.RemoteSettings
	_, err := s.read("remote.json", &r)
	return r, err
}

func (s *Store) SaveRemote(r model.RemoteSettings) error { return s.write("remote.json", r) }

// RemoteKey returns the daemon's key, or false when it has none yet.
func (s *Store) RemoteKey() (model.RemoteKey, bool, error) {
	var k model.RemoteKey
	ok, err := s.read("remote-key.json", &k)
	return k, ok, err
}

func (s *Store) SaveRemoteKey(k model.RemoteKey) error { return s.write("remote-key.json", k) }

func (s *Store) Devices() ([]model.Device, error) {
	var d []model.Device
	_, err := s.read("devices.json", &d)
	return d, err
}

// SaveDevices writes the devices, each with "kind": "web", which nothing
// here reads: a daemon before v0.53, run after a downgrade, sends the kind
// it reads, and its app labels a device without one "iPhone app" (ADR
// 0054's 2026-11-23 note).
func (s *Store) SaveDevices(d []model.Device) error {
	type withKind struct {
		model.Device
		Kind string `json:"kind"`
	}
	out := make([]withKind, len(d))
	for i, dev := range d {
		out[i] = withKind{dev, "web"}
	}
	return s.write("devices.json", out)
}

// VAPIDKey returns the daemon's Web Push key, or false when it has none yet.
func (s *Store) VAPIDKey() (model.VAPIDKey, bool, error) {
	var k model.VAPIDKey
	ok, err := s.read("vapid.json", &k)
	return k, ok, err
}

func (s *Store) SaveVAPIDKey(k model.VAPIDKey) error { return s.write("vapid.json", k) }

// readWholly are the phones' key, their pairings and the Web Push key:
// read whole (readWhole), and remembered when set aside, so remote access
// can start over without them and say so (ADR 0034's 2026-11-22
// amendment) rather than the daemon not starting.
var readWholly = map[string]bool{"remote-key.json": true, "devices.json": true, "vapid.json": true}

func (s *Store) read(name string, v any) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	path := filepath.Join(s.dir, name)
	if !readWholly[name] {
		return readJSON(path, v)
	}
	ok, aside, err := readWhole(path, v)
	if aside != "" {
		if s.asides == nil {
			s.asides = map[string]string{}
		}
		s.asides[name] = aside
	}
	return ok, err
}

// SetAside is the name remote-key.json, devices.json or vapid.json was
// set aside as since the store was made, as it didn't parse, or "".
func (s *Store) SetAside(name string) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.asides[name]
}

func (s *Store) write(name string, v any) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return writeJSON(filepath.Join(s.dir, name), v)
}
