package remote

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// Allow on the Mac at the same moment as a revoke (another phone's
// Forget), which ends the pairing: the phone is told it's paired exactly
// when the Mac keeps it, and a device the Mac doesn't keep is waited for
// nowhere.
func TestAllowRacingARevokeLeavesNoGhost(t *testing.T) {
	url := startRelay(t)
	s := startRemote(t, t.TempDir(), url)
	for range 5 {
		s.mu.Lock()
		other, err := s.add("other", "web", newKey(t).Public)
		s.mu.Unlock()
		testcheck.NoErr(t, err)
		qr, _, err := s.StartPairing()
		testcheck.NoErr(t, err)
		o := parseQR(t, qr)
		b := newKey(t)
		conn, code, err := phonePair(t, o, b, o.psk)
		testcheck.NoErr(t, err)
		waitFor(t, func() bool { p := s.Get().Pairing; return p != nil && p.Code == code })
		testcheck.NoErr(t, s.ConfirmPairing(code, true))
		testcheck.NoErr(t, s.Revoke(other))
		buf := make([]byte, 4096)
		n, _ := conn.Read(buf)
		var m map[string]string
		_ = json.Unmarshal(buf[:n], &m)
		_ = conn.Close()
		sum := sha256.Sum256(b.Public)
		id := hex.EncodeToString(sum[:8])
		kept := slices.ContainsFunc(s.Get().Devices, func(d model.Device) bool { return d.ID == id })
		if told := m["daemon"] != ""; told != kept {
			t.Fatalf("the phone read %v; the Mac keeps it: %v", m, kept)
		}
		if kept {
			testcheck.NoErr(t, s.Revoke(id))
			continue
		}
		s.mu.Lock()
		waited := slices.ContainsFunc(s.moving, func(m model.Moving) bool { return slices.Contains(m.Devices, id) })
		s.mu.Unlock()
		if waited {
			t.Fatal("an id given up still waits for the device the Mac dropped")
		}
	}
}
