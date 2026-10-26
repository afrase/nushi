package remote

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/url"
	"strings"
	"time"
	"unicode"

	"github.com/afrase/nushi/noiseconn"
)

// pairing is a QR code being shown: a one-time rendezvous id (and its
// listen key) and secret.
type pairing struct {
	id      string
	listen  ed25519.PrivateKey
	psk     []byte
	expires time.Time
	cancel  context.CancelFunc
	// Once a phone holding the secret has connected:
	name, code string
	kind       string // "web", or "" for an app
	answer     chan bool
}

// StartPairing makes a one-time id and secret and waits at the relay for a
// phone, until PairingWait has passed; it returns the QR code's text. A
// pairing already under way ends.
//
//nolint:contextcheck // a pairing waits for its phone after the request returns
func (s *Service) StartPairing() (string, time.Time, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.settings.On {
		return "", time.Time{}, errors.New("remote access is off")
	}
	s.endPairing()
	psk := make([]byte, 32)
	rand.Read(psk)
	ctx, cancel := context.WithCancel(context.Background())
	listen := newListenKey()
	p := &pairing{id: listenID(listen), listen: listen, psk: psk, expires: time.Now().Add(PairingWait), cancel: cancel, answer: make(chan bool, 1)}
	s.pairing = p
	s.changed()
	slog.Info("pairing started", "until", p.expires.Format(time.TimeOnly))
	go s.pair(ctx, p, s.settings.Relay)
	q := url.Values{"r": {s.settings.Relay}, "i": {p.id}, "k": {b64(s.key.Public)}, "s": {b64(psk)}}
	return "nushi://pair?" + q.Encode(), p.expires, nil
}

func b64(b []byte) string { return base64.RawURLEncoding.EncodeToString(b) }

// ConfirmPairing answers the phone that connected, whose code is code.
func (s *Service) ConfirmPairing(code string, allow bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	p := s.pairing
	if p == nil || p.code == "" || p.code != code {
		return errors.New("no phone is waiting with that code")
	}
	select {
	case p.answer <- allow:
	default:
	}
	return nil
}

// endPairing ends the pairing under way, if any. Called with s.mu.
func (s *Service) endPairing() {
	if s.pairing != nil {
		s.pairing.cancel()
		s.pairing = nil
		s.changed()
	}
}

// pair waits on p's id for a phone with p's secret, until p expires. The
// first that completes IKpsk1 uses the pairing up, whatever happens next:
// one that then sends no name ends it, so whoever holds the secret gets one
// code, not a code per try. Otherwise the user allows or denies the phone.
func (s *Service) pair(ctx context.Context, p *pairing, relayURL string) {
	defer func() {
		s.mu.Lock()
		if s.pairing == p {
			s.endPairing()
		}
		s.mu.Unlock()
	}()
	waiting, cancel := context.WithDeadline(ctx, p.expires)
	defer cancel()
	for waiting.Err() == nil {
		conn, hello, used := s.meet(waiting, p, relayURL)
		if used && conn == nil {
			slog.Info("pairing used up by a phone that sent no name")
			return
		}
		if conn == nil {
			continue
		}
		stop := context.AfterFunc(ctx, func() { _ = conn.Close() })
		defer stop() //nolint:gocritic,revive // every path from here returns: it runs once
		code, name := codeOf(conn.Hash()), cleanName(hello.Name)
		s.mu.Lock()
		p.name, p.code, p.kind = name, code, cleanKind(hello.Kind)
		s.changed()
		s.mu.Unlock()
		slog.Info("pairing: a phone waits for Allow", "name", name)
		allow := false
		select {
		case allow = <-p.answer:
		case <-time.After(ConfirmWait):
		case <-ctx.Done():
			return
		}
		s.mu.Lock()
		var id string
		var err error
		if allow {
			id, err = s.add(name, p.kind, conn.Peer())
		}
		daemon := s.id
		s.mu.Unlock()
		if !allow || err != nil {
			slog.Info("pairing refused", "allowed", allow, "err", err)
			reply, _ := json.Marshal(map[string]string{"error": "refused"})
			_, _ = conn.Write(reply) // refused either way
			_ = conn.Close()
			return
		}
		reply, _ := json.Marshal(map[string]string{"daemon": daemon})
		if _, err := conn.Write(reply); err != nil || !stop() {
			_ = conn.Close()
			return
		}
		slog.Info("device paired", "device", id, "name", name)
		go s.run(conn, id, daemon)
		return
	}
}

// hello is a phone's first message when pairing: its name, and "web" for
// the web app.
type hello struct{ Name, Kind string }

// meet waits for one phone on p's id and runs the handshake. It returns
// the channel and the phone's hello, or nil; used says the handshake
// completed (the phone held the secret) even if no name came.
func (s *Service) meet(ctx context.Context, p *pairing, relayURL string) (conn *noiseconn.Conn, h hello, used bool) {
	c, err := s.dialer.Listen(ctx, relayURL, p.listen)
	if err != nil {
		sleep(ctx, jitter(2*time.Second))
		return nil, h, false
	}
	stop := context.AfterFunc(ctx, func() { _ = c.Close() })
	defer stop()
	if c.Wait() != nil {
		_ = c.Close()
		return nil, h, false
	}
	timer := time.AfterFunc(HandshakeWait, func() { _ = c.Close() })
	defer timer.Stop()
	conn, err = noiseconn.Respond(c, noiseconn.Config{Static: s.key, Prologue: prologue(p.id), PSK: p.psk},
		func([]byte) error { return nil })
	if err != nil {
		return nil, h, false
	}
	// The phone's first transport message is its name.
	buf := make([]byte, noiseconn.MaxPlaintext)
	n, err := conn.Read(buf)
	if err != nil || json.Unmarshal(buf[:n], &h) != nil || !timer.Stop() || !stop() {
		_ = conn.Close()
		return nil, h, true
	}
	return conn, h, true
}

// cleanKind keeps a device's kind to those Nushi knows.
func cleanKind(kind string) string {
	if kind == "web" {
		return kind
	}
	return ""
}

// codeOf is the six digits both screens show, from the handshake hash.
func codeOf(hash []byte) string {
	n := binary.BigEndian.Uint64(hash[:8]) % 1_000_000
	return fmt.Sprintf("%03d %03d", n/1000, n%1000)
}

// cleanName keeps a phone's name to 40 printable characters.
func cleanName(name string) string {
	name = strings.TrimSpace(strings.Map(func(r rune) rune {
		if unicode.IsControl(r) || unicode.In(r, unicode.Cf, unicode.Zl, unicode.Zp) {
			return -1
		}
		return r
	}, name))
	if r := []rune(name); len(r) > 40 {
		name = string(r[:40])
	}
	if name == "" {
		return "A phone"
	}
	return name
}
