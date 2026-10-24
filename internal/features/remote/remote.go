// Package remote is remote access (ADRs 0033, 0034): when it's on, the
// daemon waits at a relay for paired phones, which reach the API through
// a Noise channel; it pairs phones and revokes them.
package remote

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
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
	serve   func(net.Conn)       // runs the API on a device's channel
	awake   func() (stop func()) // keeps the Mac from idle sleep
	publish func(model.Event)
	key     noise.DHKey

	mu        sync.Mutex
	listen    ed25519.PrivateKey // proves to the relay the daemon may listen at id
	id        string
	moving    []model.Moving // ids given up, still waited on for some devices
	settings  model.RemoteSettings
	state     string
	err       string
	stopLink  context.CancelFunc // every wait at the relay
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
		k = model.RemoteKey{Private: key.Private, Public: key.Public}
	}
	if len(k.Listen) != ed25519.PrivateKeySize { // new, or from before step 116: its phones pair again
		k.Listen = newListenKey()
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
		key: noise.DHKey{Private: k.Private, Public: k.Public}, listen: k.Listen, id: listenID(k.Listen), moving: k.Moving,
		settings: settings, state: "off", devices: devices, conns: map[*noiseconn.Conn]string{}}
	s.mu.Lock()
	s.apply()
	s.mu.Unlock()
	return s, nil
}

func newListenKey() ed25519.PrivateKey {
	_, k, _ := ed25519.GenerateKey(rand.Reader)
	return k
}

// listenID is the rendezvous id at the relay that only listen's holder can
// listen on.
func listenID(listen ed25519.PrivateKey) string {
	return relay.ListenID(listen.Public().(ed25519.PublicKey))
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
	r := model.Remote{RemoteSettings: s.settings, State: s.state, Error: s.err, Rendezvous: s.id}
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
	s.state, s.err = "connecting", ""
	s.changed()
	s.relink()
}

// Close stops remote access for the daemon's end, leaving it on.
func (s *Service) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.settings.On = false
	s.apply()
}

// setState tells how the wait on id stands, which counts only for the
// daemon's own id.
func (s *Service) setState(ctx context.Context, id, state, err string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if ctx.Err() != nil || id != s.id || s.state == state && s.err == err {
		return
	}
	s.state, s.err = state, err
	s.changed()
}

// link waits at the relay for phones on listen's id, one waiting
// connection at a time, until ctx ends or the id is given up; a failed
// connection is tried again after a backoff.
func (s *Service) link(ctx context.Context, relayURL string, listen ed25519.PrivateKey) {
	id := listenID(listen)
	backoff := time.Second
	for ctx.Err() == nil && s.waits(id) {
		c, err := s.dialer.Listen(ctx, relayURL, listen)
		if err != nil {
			s.setState(ctx, id, "error", err.Error())
			sleep(ctx, jitter(backoff))
			backoff = min(2*backoff, time.Minute)
			continue
		}
		backoff = time.Second
		s.setState(ctx, id, "connected", "")
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
		go s.accept(ctx, c, id)
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
