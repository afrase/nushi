// Package remote is remote access (ADRs 0033, 0034): when it's on, the
// daemon waits at a relay for paired phones, which reach the API through
// a Noise channel; it pairs phones and revokes them.
package remote

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"math/big"
	"net"
	"net/url"
	"sync"
	"time"

	"github.com/flynn/noise"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/noiseconn"
	"github.com/afrase/nushi/relay"
)

// Store keeps remote access on disk.
type Store interface {
	Remote() (model.RemoteSettings, error)
	SaveRemote(model.RemoteSettings) error
	RemoteKey() (model.RemoteKey, bool, error)
	SaveRemoteKey(model.RemoteKey) error
	Devices() ([]model.Device, error)
	SaveDevices([]model.Device) error
}

// Timeouts, and the cap on live connections.
var (
	HandshakeWait = 30 * time.Second // from a dialer's first message to its first transport message
	PairingWait   = 5 * time.Minute  // a QR code's life
	ConfirmWait   = 2 * time.Minute  // for Allow or Deny once a phone has connected
	MaxConns      = 16
)

// Service is remote access.
type Service struct {
	st      Store
	dialer  *relay.Dialer
	serve   func(net.Conn)          // runs the API on a device's channel
	awake   func() (stop func())    // keeps the Mac from idle sleep
	publish func(model.Event)
	key     noise.DHKey
	id      string

	mu        sync.Mutex
	settings  model.RemoteSettings
	state     string
	err       string
	stopLink  context.CancelFunc
	stopAwake func()
	devices   []model.Device
	conns     map[*noiseconn.Conn]string // live connections and their devices
	pairing   *pairing
}

// New loads remote access and, if it was on, starts it.
func New(st Store, dialer *relay.Dialer, serve func(net.Conn), awake func() func(), publish func(model.Event)) (*Service, error) {
	k, ok, err := st.RemoteKey()
	if err != nil {
		return nil, err
	}
	if !ok {
		key, err := noiseconn.NewKey()
		if err != nil {
			return nil, err
		}
		k = model.RemoteKey{Private: key.Private, Public: key.Public, ID: randomID()}
		if err := st.SaveRemoteKey(k); err != nil {
			return nil, err
		}
	}
	settings, err := st.Remote()
	if err != nil {
		return nil, err
	}
	devices, err := st.Devices()
	if err != nil {
		return nil, err
	}
	s := &Service{st: st, dialer: dialer, serve: serve, awake: awake, publish: publish,
		key: noise.DHKey{Private: k.Private, Public: k.Public}, id: k.ID,
		settings: settings, state: "off", devices: devices, conns: map[*noiseconn.Conn]string{}}
	s.mu.Lock()
	s.apply()
	s.mu.Unlock()
	return s, nil
}

func randomID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

// prologue binds a handshake to the rendezvous id it runs on.
func prologue(id string) []byte { return []byte("nushi-remote/1\x00" + id) }

// Get says how remote access stands.
func (s *Service) Get() model.Remote {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.snapshot()
}

func (s *Service) snapshot() model.Remote {
	r := model.Remote{RemoteSettings: s.settings, State: s.state, Error: s.err}
	for _, d := range s.devices {
		for _, id := range s.conns {
			d.Connected = d.Connected || id == d.ID
		}
		r.Devices = append(r.Devices, d)
	}
	if p := s.pairing; p != nil {
		r.Pairing = &model.Pairing{Expires: p.expires, Name: p.name, Code: p.code}
	}
	return r
}

// changed tells the clients. Called with s.mu.
func (s *Service) changed() {
	r := s.snapshot()
	s.publish(model.Event{Remote: &r})
}

// Set turns remote access on or off, through relay.
func (s *Service) Set(on bool, relayURL string) error {
	if on {
		if u, err := url.Parse(relayURL); err != nil || (u.Scheme != "ws" && u.Scheme != "wss") || u.Host == "" {
			return errors.New("the relay must be a ws:// or wss:// URL")
		}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	next := model.RemoteSettings{On: on, Relay: relayURL}
	if next == s.settings {
		return nil
	}
	if err := s.st.SaveRemote(next); err != nil {
		return err
	}
	s.settings = next
	s.apply()
	return nil
}

// apply starts or stops the link to match the settings: a new relay starts
// it again. Called with s.mu.
func (s *Service) apply() {
	if s.stopLink != nil {
		s.stopLink()
		s.stopLink = nil
	}
	s.endPairing()
	for c := range s.conns {
		c.Close()
	}
	if !s.settings.On {
		if s.stopAwake != nil {
			s.stopAwake()
			s.stopAwake = nil
		}
		s.state, s.err = "off", ""
		s.changed()
		return
	}
	if s.stopAwake == nil {
		s.stopAwake = s.awake()
	}
	ctx, cancel := context.WithCancel(context.Background())
	s.stopLink = cancel
	s.state, s.err = "connecting", ""
	s.changed()
	go s.link(ctx, s.settings.Relay)
}

// Close stops remote access for the daemon's end, leaving it on.
func (s *Service) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.settings.On = false
	s.apply()
}

func (s *Service) setState(ctx context.Context, state, err string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if ctx.Err() != nil || s.state == state && s.err == err {
		return
	}
	s.state, s.err = state, err
	s.changed()
}

// link waits at the relay for phones, one waiting connection at a time,
// until ctx ends; a failed connection is tried again after a backoff.
func (s *Service) link(ctx context.Context, relayURL string) {
	backoff := time.Second
	for ctx.Err() == nil {
		c, err := s.dialer.Listen(ctx, relayURL, s.id)
		if err != nil {
			s.setState(ctx, "error", err.Error())
			sleep(ctx, jitter(backoff))
			backoff = min(2*backoff, time.Minute)
			continue
		}
		backoff = time.Second
		s.setState(ctx, "connected", "")
		stop := context.AfterFunc(ctx, func() { c.Close() })
		err = c.Wait()
		stop()
		if err != nil {
			// The relay ended the wait (its limit, a restart) or the network
			// went: wait again, at a random moment so many daemons don't
			// come back at once.
			c.Close()
			sleep(ctx, jitter(time.Second))
			continue
		}
		go s.accept(ctx, c)
	}
}

// jitter is d, give or take half.
func jitter(d time.Duration) time.Duration {
	n, _ := rand.Int(rand.Reader, big.NewInt(int64(d)))
	return d/2 + time.Duration(n.Int64())
}

func sleep(ctx context.Context, d time.Duration) {
	select {
	case <-ctx.Done():
	case <-time.After(d):
	}
}
