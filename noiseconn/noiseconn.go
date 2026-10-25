// Package noiseconn runs a standard Noise handshake over a transport that
// carries whole messages, and makes the result a net.Conn.
//
// The patterns are Noise_IK_25519_ChaChaPoly_BLAKE2s, and
// Noise_IKpsk1_25519_ChaChaPoly_BLAKE2s when a pre-shared key is given:
// the initiator knows the responder's static key beforehand and sends its
// own, encrypted, in the first message. Both handshake payloads are empty.
// After the handshake each transport message carries at most MaxPlaintext
// bytes; each direction rekeys (Noise's REKEY) after every RekeyEvery
// messages. A message that fails to decrypt (changed, replayed, reordered
// or dropped before it) ends the connection.
package noiseconn

import (
	"crypto/rand"
	"errors"
	"io"
	"net"
	"sync"
	"time"

	"github.com/flynn/noise"
)

// Transport carries whole messages, in order, such as a WebSocket.
type Transport interface {
	ReadMessage() ([]byte, error)
	WriteMessage([]byte) error
	Close() error
}

// Config is one side's part of a handshake.
type Config struct {
	Static   noise.DHKey
	Prologue []byte // both sides must give the same
	PSK      []byte // 32 bytes for IKpsk1; nil for IK
}

const (
	// MaxPlaintext is the most a transport message carries: Noise's 65,535
	// bytes less the tag.
	MaxPlaintext = noise.MaxMsgLen - 16
	// RekeyEvery is how many messages a direction sends between rekeys.
	RekeyEvery = 4096
)

var suite = noise.NewCipherSuite(noise.DH25519, noise.CipherChaChaPoly, noise.HashBLAKE2s)

// NewKey makes a static key pair.
func NewKey() (noise.DHKey, error) { return suite.GenerateKeypair(rand.Reader) }

// state starts one side's handshake; rng gives the ephemeral key (tests
// give a fixed one).
func state(c Config, initiator bool, peer []byte, rng io.Reader) (*noise.HandshakeState, error) {
	cfg := noise.Config{CipherSuite: suite, Random: rng, Pattern: noise.HandshakeIK, Initiator: initiator,
		Prologue: c.Prologue, StaticKeypair: c.Static, PeerStatic: peer}
	if c.PSK != nil {
		if len(c.PSK) != 32 {
			return nil, errors.New("noiseconn: a pre-shared key is 32 bytes")
		}
		cfg.PresharedKey, cfg.PresharedKeyPlacement = c.PSK, 1
	}
	return noise.NewHandshakeState(cfg)
}

// Initiate runs the initiator's side, knowing the responder's static key.
// On failure the transport is closed.
func Initiate(t Transport, c Config, peer []byte) (*Conn, error) {
	conn, err := initiate(t, c, peer)
	if err != nil {
		_ = t.Close() // the handshake failed; that error is the one to return
	}
	return conn, err
}

func initiate(t Transport, c Config, peer []byte) (*Conn, error) {
	hs, err := state(c, true, peer, rand.Reader)
	if err != nil {
		return nil, err
	}
	m1, _, _, err := hs.WriteMessage(nil, nil)
	if err != nil {
		return nil, err
	}
	if err := t.WriteMessage(m1); err != nil {
		return nil, err
	}
	m2, err := t.ReadMessage()
	if err != nil {
		return nil, err
	}
	_, send, recv, err := hs.ReadMessage(nil, m2)
	if err != nil {
		return nil, err
	}
	return &Conn{t: t, send: send, recv: recv, hash: hs.ChannelBinding(), peer: hs.PeerStatic()}, nil
}

// Respond runs the responder's side. allow sees the initiator's static key
// once the first message has decrypted; an error from it ends the handshake
// without an answer. On failure the transport is closed.
func Respond(t Transport, c Config, allow func(peer []byte) error) (*Conn, error) {
	conn, err := respond(t, c, allow)
	if err != nil {
		_ = t.Close() // as above
	}
	return conn, err
}

func respond(t Transport, c Config, allow func(peer []byte) error) (*Conn, error) {
	hs, err := state(c, false, nil, rand.Reader)
	if err != nil {
		return nil, err
	}
	m1, err := t.ReadMessage()
	if err != nil {
		return nil, err
	}
	if _, _, _, err := hs.ReadMessage(nil, m1); err != nil {
		return nil, err
	}
	if err := allow(hs.PeerStatic()); err != nil {
		return nil, err
	}
	m2, recv, send, err := hs.WriteMessage(nil, nil)
	if err != nil {
		return nil, err
	}
	if err := t.WriteMessage(m2); err != nil {
		return nil, err
	}
	return &Conn{t: t, send: send, recv: recv, hash: hs.ChannelBinding(), peer: hs.PeerStatic()}, nil
}

// Conn is the channel after the handshake. Reads and writes may run at
// once; a Write of up to MaxPlaintext bytes is one Noise message.
type Conn struct {
	t          Transport
	hash, peer []byte

	rmu  sync.Mutex
	recv *noise.CipherState
	got  uint64
	buf  []byte
	rerr error

	wmu  sync.Mutex
	send *noise.CipherState
	sent uint64
	werr error
}

// Hash is the handshake hash, the same on both sides.
func (c *Conn) Hash() []byte { return c.hash }

// Peer is the other side's static public key.
func (c *Conn) Peer() []byte { return c.peer }

// Peek waits for the next message and decrypts it, keeping its bytes for
// Read: once it returns nil, the peer has proved it holds the session.
func (c *Conn) Peek() error {
	c.rmu.Lock()
	defer c.rmu.Unlock()
	if len(c.buf) > 0 {
		return nil
	}
	return c.next()
}

func (c *Conn) Read(p []byte) (int, error) {
	c.rmu.Lock()
	defer c.rmu.Unlock()
	for len(c.buf) == 0 {
		if err := c.next(); err != nil {
			return 0, err
		}
	}
	n := copy(p, c.buf)
	c.buf = c.buf[n:]
	return n, nil
}

// next reads and decrypts one message into buf.
func (c *Conn) next() error {
	if c.rerr != nil {
		return c.rerr
	}
	m, err := c.t.ReadMessage()
	if err == nil {
		c.buf, err = c.recv.Decrypt(c.buf[:0], nil, m)
	}
	if err != nil {
		c.rerr = err
		_ = c.t.Close() // the read's error is the one to return
		return err
	}
	if c.got++; c.got%RekeyEvery == 0 {
		c.recv.Rekey()
	}
	return nil
}

func (c *Conn) Write(p []byte) (int, error) {
	c.wmu.Lock()
	defer c.wmu.Unlock()
	n := 0
	for n < len(p) && c.werr == nil {
		chunk := p[n:min(len(p), n+MaxPlaintext)]
		var m []byte
		if m, c.werr = c.send.Encrypt(nil, nil, chunk); c.werr == nil {
			c.werr = c.t.WriteMessage(m)
		}
		if c.werr != nil {
			_ = c.t.Close() // the write's error is the one to return
			break
		}
		if c.sent++; c.sent%RekeyEvery == 0 {
			c.send.Rekey()
		}
		n += len(chunk)
	}
	return n, c.werr
}

// Close closes the transport under the channel.
func (c *Conn) Close() error { return c.t.Close() }

// SetDeadline does nothing: the transport keeps itself alive and times
// out on its own, so deadlines aren't used.
func (c *Conn) SetDeadline(time.Time) error { return nil }

// SetReadDeadline does nothing, as SetDeadline.
func (c *Conn) SetReadDeadline(time.Time) error { return nil }

// SetWriteDeadline does nothing, as SetDeadline.
func (c *Conn) SetWriteDeadline(time.Time) error { return nil }

// LocalAddr is a placeholder: the channel has no address of its own.
func (c *Conn) LocalAddr() net.Addr { return addr{} }

// RemoteAddr is a placeholder, as LocalAddr.
func (c *Conn) RemoteAddr() net.Addr { return addr{} }

type addr struct{}

func (addr) Network() string { return "noise" }
func (addr) String() string  { return "noise" }
