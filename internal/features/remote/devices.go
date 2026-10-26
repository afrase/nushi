package remote

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"log/slog"
	"net"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/noiseconn"
	"github.com/afrase/nushi/relay"
)

var errUnknown = errors.New("not a paired device")

// accept runs IK with a phone that came to id: only a paired device's key
// gets an answer (on an id given up, only a device still to move), and it
// counts as connected once its first transport message decrypts.
func (s *Service) accept(ctx context.Context, c *relay.Conn, id string) {
	timer := time.AfterFunc(HandshakeWait, func() { _ = c.Close() })
	defer timer.Stop()
	stop := context.AfterFunc(ctx, func() { _ = c.Close() })
	defer stop()
	conn, err := noiseconn.Respond(c, noiseconn.Config{Static: s.key, Prologue: prologue(id)}, func(peer []byte) error {
		if s.device(peer, id) == "" {
			return errUnknown
		}
		return nil
	})
	if err != nil || conn.Peek() != nil || !timer.Stop() || !stop() {
		if err != nil {
			slog.Info("device rejected", "err", err)
		}
		_ = c.Close()
		return
	}
	s.run(conn, s.device(conn.Peer(), id), id)
}

// device names the paired device with key that may come to id, or "".
func (s *Service) device(key []byte, id string) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, d := range s.devices {
		if bytes.Equal(d.Key, key) && (id == s.id || s.mayMove(d.ID, id)) {
			return d.ID
		}
	}
	return ""
}

// run serves the API to device on conn, which came to id, until it
// closes, if the device is still paired and the cap allows.
func (s *Service) run(conn *noiseconn.Conn, device, id string) {
	s.mu.Lock()
	i := slices.IndexFunc(s.devices, func(d model.Device) bool { return d.ID == device })
	if i < 0 || !s.settings.On || len(s.conns) >= MaxConns {
		s.mu.Unlock()
		slog.Info("device turned away", "device", device, "connections", len(s.conns))
		_ = conn.Close()
		return
	}
	slog.Info("device connected", "device", device, "moved", id != s.id)
	s.conns[conn] = device
	if id == s.id {
		s.moved(device)
	}
	s.seen(i)
	s.mu.Unlock()
	s.serve(&served{Conn: conn, s: s, device: device})
}

// seen moves device i's last-seen time and tells the clients. Called with
// s.mu.
func (s *Service) seen(i int) {
	s.devices[i].LastSeen = time.Now()
	_ = s.st.SaveDevices(s.devices) // the time is a convenience
	s.changed()
}

// served is a device's channel given to the API; closing it forgets it.
type served struct {
	*noiseconn.Conn
	s      *Service
	device string
}

// Device is the paired device at the channel's other end.
func (c *served) Device() string { return c.device }

func (c *served) Close() error {
	s := c.s
	s.mu.Lock()
	if device, ok := s.conns[c.Conn]; ok {
		delete(s.conns, c.Conn)
		if !s.connectedLocked(device) {
			delete(s.views, device)
		}
		slog.Info("device disconnected", "device", device)
		if i := slices.IndexFunc(s.devices, func(d model.Device) bool { return d.ID == device }); i >= 0 {
			s.seen(i)
		}
	}
	s.mu.Unlock()
	return c.Conn.Close()
}

var _ net.Conn = (*served)(nil)

// add pairs a device of kind with key. Called with s.mu.
func (s *Service) add(name, kind string, key []byte) (string, error) {
	sum := sha256.Sum256(key)
	d := model.Device{ID: hex.EncodeToString(sum[:8]), Name: name, Kind: kind, Key: key, Paired: time.Now()}
	devices := append(slices.DeleteFunc(slices.Clone(s.devices), func(o model.Device) bool { return o.ID == d.ID }), d)
	if err := s.st.SaveDevices(devices); err != nil {
		return "", err
	}
	s.devices = devices
	return d.ID, nil
}

// Revoke unpairs a device and drops its connections at once.
func (s *Service) Revoke(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	devices := slices.DeleteFunc(slices.Clone(s.devices), func(d model.Device) bool { return d.ID == id })
	if len(devices) == len(s.devices) {
		return errors.New("no such device")
	}
	if err := s.st.SaveDevices(devices); err != nil {
		return err
	}
	s.devices = devices
	delete(s.views, id)
	for c, d := range s.conns {
		if d == id {
			delete(s.conns, c)
			_ = c.Close()
		}
	}
	err := s.rotate(id) // the device knows the id
	s.changed()
	slog.Info("device revoked", "device", id, "err", err)
	return err
}
