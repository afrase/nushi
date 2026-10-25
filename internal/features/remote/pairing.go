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
	answer     chan bool
}

// StartPairing makes a one-time id and secret and waits at the relay for a
// phone, until PairingWait has passed; it returns the QR code's text. A
// pairing already under way ends.
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
		conn, name, used := s.meet(waiting, p, relayURL)
		if used && conn == nil {
			slog.Info("pairing used up by a phone that sent no name")
			return
		}
		if conn == nil {
			continue
		}
		stop := context.AfterFunc(ctx, func() { conn.Close() })
		defer stop() //nolint:gocritic,revive // every path from here returns: it runs once
		code := codeOf(conn.Hash())
		s.mu.Lock()
		p.name, p.code = name, code
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
			id, err = s.add(name, conn.Peer())
		}
		daemon := s.id
		s.mu.Unlock()
		if !allow || err != nil {
			slog.Info("pairing refused", "allowed", allow, "err", err)
			reply, _ := json.Marshal(map[string]string{"error": "refused"})
			conn.Write(reply)
			conn.Close()
			return
		}
		reply, _ := json.Marshal(map[string]string{"daemon": daemon})
		if _, err := conn.Write(reply); err != nil || !stop() {
			conn.Close()
			return
		}
		slog.Info("device paired", "device", id, "name", name)
		go s.run(conn, id, daemon)
		return
	}
}

// meet waits for one phone on p's id and runs the handshake. It returns
// the channel and the phone's name, or nil; used says the handshake
// completed (the phone held the secret) even if no name came.
func (s *Service) meet(ctx context.Context, p *pairing, relayURL string) (conn *noiseconn.Conn, name string, used bool) {
	c, err := s.dialer.Listen(ctx, relayURL, p.listen)
	if err != nil {
		sleep(ctx, jitter(2*time.Second))
		return nil, "", false
	}
	stop := context.AfterFunc(ctx, func() { c.Close() })
	defer stop()
	if c.Wait() != nil {
		c.Close()
		return nil, "", false
	}
	timer := time.AfterFunc(HandshakeWait, func() { c.Close() })
	defer timer.Stop()
	conn, err = noiseconn.Respond(c, noiseconn.Config{Static: s.key, Prologue: prologue(p.id), PSK: p.psk},
		func([]byte) error { return nil })
	if err != nil {
		return nil, "", false
	}
	// The phone's first transport message is its name.
	buf := make([]byte, noiseconn.MaxPlaintext)
	n, err := conn.Read(buf)
	var hello struct{ Name string }
	if err != nil || json.Unmarshal(buf[:n], &hello) != nil || !timer.Stop() || !stop() {
		conn.Close()
		return nil, "", true
	}
	return conn, cleanName(hello.Name), true
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
