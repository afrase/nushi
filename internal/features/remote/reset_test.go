package remote

import (
	"bytes"
	"path/filepath"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A key file that doesn't parse (the daemon's key, its paired devices or
// the Web Push key) no longer stops the daemon: it's set aside beside the
// others, remote access starts over with a fresh key and no devices, and
// says so until a phone is next paired, across restarts. The phone paired
// before can't reach the daemon at its old id.
func TestAKeyFileThatDoesntParseStartsOver(t *testing.T) {
	for _, name := range keyFiles {
		t.Run(name, func(t *testing.T) {
			url := startRelay(t)
			dir := t.TempDir()
			s := startRemote(t, dir, url)
			phone := newKey(t)
			o, oldID := pairOne(t, s, phone)
			testcheck.Wait(t, "the pairing to end", func() bool { return s.Get().Pairing == nil })
			s.Close()
			testcheck.Write(t, filepath.Join(dir, name), `{"private": fals`)

			s = startRemote(t, dir, url)
			r := s.Get()
			aside, err := filepath.Glob(filepath.Join(dir, name+".unreadable-*"))
			testcheck.NoErr(t, err)
			if len(aside) != 1 || r.Reset == nil || !slices.Equal(r.Reset.Files, []string{filepath.Base(aside[0])}) {
				t.Fatalf("set aside %v, reset %+v", aside, r.Reset)
			}
			if len(r.Devices) != 0 || r.Rendezvous == oldID || bytes.Equal(r.Key, o.key) {
				t.Fatalf("not started over: %d devices, same id %v, same key %v", len(r.Devices), r.Rendezvous == oldID, bytes.Equal(r.Key, o.key))
			}
			if !unanswered(url, oldID, o.key, phone, nil) {
				t.Error("the phone paired before still reaches the daemon")
			}

			s.Close()
			s = startRemote(t, dir, url)
			if r := s.Get().Reset; r == nil || !slices.Equal(r.Files, []string{filepath.Base(aside[0])}) {
				t.Fatalf("after a restart: %+v", r)
			}

			pairOne(t, s, newKey(t))
			testcheck.Wait(t, "the reset to clear once a phone pairs", func() bool { return s.Get().Reset == nil })
			s.Close()
			if r := startRemote(t, dir, url).Get().Reset; r != nil {
				t.Errorf("paired, then restarted: %+v", r)
			}
		})
	}
}
