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

func (s *Store) SaveDevices(d []model.Device) error { return s.write("devices.json", d) }

// VAPIDKey returns the daemon's Web Push key, or false when it has none yet.
func (s *Store) VAPIDKey() (model.VAPIDKey, bool, error) {
	var k model.VAPIDKey
	ok, err := s.read("vapid.json", &k)
	return k, ok, err
}

func (s *Store) SaveVAPIDKey(k model.VAPIDKey) error { return s.write("vapid.json", k) }

// refusesUnparsed are the files a parse failure still refuses, left in
// place (readRefusing): the phones' keys and pairings and the Web Push
// key, until the owner decides what a bad one should do.
var refusesUnparsed = map[string]bool{"remote-key.json": true, "devices.json": true, "vapid.json": true}

func (s *Store) read(name string, v any) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if refusesUnparsed[name] {
		return readRefusing(filepath.Join(s.dir, name), v)
	}
	return readJSON(filepath.Join(s.dir, name), v)
}

func (s *Store) write(name string, v any) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return writeJSON(filepath.Join(s.dir, name), v)
}
