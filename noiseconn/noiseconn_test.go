package noiseconn

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"strings"
	"sync"
	"testing"

	"github.com/flynn/noise"
)

// The standard vectors (cacophony's and snow's, cut to
// 25519_ChaChaPoly_BLAKE2s) for the two patterns, run through state: the
// suite, the pattern and where the pre-shared key goes are this package's.
func TestVectors(t *testing.T) {
	ran := 0
	for _, file := range []string{"testdata/cacophony.json", "testdata/snow.json"} {
		b, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		var vs struct {
			Vectors []struct {
				Name          string   `json:"protocol_name"`
				Prologue      string   `json:"init_prologue"`
				InitPSKs      []string `json:"init_psks"`
				InitStatic    string   `json:"init_static"`
				InitEphemeral string   `json:"init_ephemeral"`
				RemoteStatic  string   `json:"init_remote_static"`
				RespStatic    string   `json:"resp_static"`
				RespEphemeral string   `json:"resp_ephemeral"`
				Hash          string   `json:"handshake_hash"`
				Messages      []struct{ Payload, Ciphertext string }
			}
		}
		if err := json.Unmarshal(b, &vs); err != nil {
			t.Fatal(err)
		}
		for _, v := range vs.Vectors {
			if v.Name != "Noise_IK_25519_ChaChaPoly_BLAKE2s" && v.Name != "Noise_IKpsk1_25519_ChaChaPoly_BLAKE2s" {
				continue
			}
			ran++
			var psk []byte
			if len(v.InitPSKs) > 0 {
				psk = unhex(t, v.InitPSKs[0])
			}
			init, err := state(Config{Static: key(t, v.InitStatic), Prologue: unhex(t, v.Prologue), PSK: psk}, true,
				unhex(t, v.RemoteStatic), bytes.NewReader(unhex(t, v.InitEphemeral)))
			if err != nil {
				t.Fatal(err)
			}
			resp, err := state(Config{Static: key(t, v.RespStatic), Prologue: unhex(t, v.Prologue), PSK: psk}, false,
				nil, bytes.NewReader(unhex(t, v.RespEphemeral)))
			if err != nil {
				t.Fatal(err)
			}
			var csI, csR [2]*noise.CipherState // [0] sends, [1] receives
			m := v.Messages
			check := func(i int, ct []byte, pt []byte) {
				if !bytes.Equal(ct, unhex(t, m[i].Ciphertext)) || !bytes.Equal(pt, unhex(t, m[i].Payload)) {
					t.Fatalf("%s (%s) message %d differs", v.Name, file, i)
				}
			}
			ct, _, _, err := init.WriteMessage(nil, unhex(t, m[0].Payload))
			if err != nil {
				t.Fatal(err)
			}
			pt, _, _, err := resp.ReadMessage(nil, ct)
			if err != nil {
				t.Fatal(err)
			}
			check(0, ct, pt)
			ct, csR[1], csR[0], err = resp.WriteMessage(nil, unhex(t, m[1].Payload))
			if err != nil {
				t.Fatal(err)
			}
			pt, csI[0], csI[1], err = init.ReadMessage(nil, ct)
			if err != nil {
				t.Fatal(err)
			}
			check(1, ct, pt)
			if v.Hash != "" && hex.EncodeToString(init.ChannelBinding()) != v.Hash {
				t.Fatalf("%s (%s): handshake hash differs", v.Name, file)
			}
			for i := 2; i < len(m); i++ {
				from, to := csI, csR
				if i%2 == 1 {
					from, to = csR, csI
				}
				ct, err := from[0].Encrypt(nil, nil, unhex(t, m[i].Payload))
				if err != nil {
					t.Fatal(err)
				}
				pt, err := to[1].Decrypt(nil, nil, ct)
				if err != nil {
					t.Fatal(err)
				}
				check(i, ct, pt)
			}
		}
	}
	if ran != 3 { // cacophony's IK and IKpsk1, snow's IK
		t.Fatalf("ran %d vectors", ran)
	}
}

func unhex(t *testing.T, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(s)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func key(t *testing.T, private string) noise.DHKey {
	t.Helper()
	k, err := noise.DH25519.GenerateKeypair(bytes.NewReader(unhex(t, private)))
	if err != nil {
		t.Fatal(err)
	}
	return k
}

// pipe is one end of an in-memory message transport. Its messages can be
// changed on the way (tamper sees each one the other end sends).
type pipe struct {
	in     chan []byte
	out    chan []byte
	once   *sync.Once
	closed chan struct{}
	tamper func(n int, m []byte) [][]byte
	n      int
}

func pipes() (*pipe, *pipe) {
	a, b := make(chan []byte, 64), make(chan []byte, 64)
	once, closed := &sync.Once{}, make(chan struct{})
	return &pipe{in: a, out: b, once: once, closed: closed}, &pipe{in: b, out: a, once: once, closed: closed}
}

func (p *pipe) ReadMessage() ([]byte, error) {
	select {
	case m := <-p.in:
		return m, nil
	case <-p.closed:
		return nil, io.EOF
	}
}

func (p *pipe) WriteMessage(m []byte) error {
	ms := [][]byte{append([]byte(nil), m...)}
	if p.tamper != nil {
		ms = p.tamper(p.n, ms[0])
	}
	p.n++
	for _, m := range ms {
		select {
		case p.out <- m:
		case <-p.closed:
			return io.EOF
		}
	}
	return nil
}

func (p *pipe) Close() error { p.once.Do(func() { close(p.closed) }); return nil }

type side struct {
	conn *Conn
	err  error
}

// connect runs both sides of a handshake at once.
func connect(t *testing.T, a, b *pipe, initiator, responder Config, pinned []byte, allow func([]byte) error) (*Conn, *Conn, error, error) {
	t.Helper()
	done := make(chan side)
	go func() {
		c, err := Respond(b, responder, allow)
		done <- side{c, err}
	}()
	ci, erri := Initiate(a, initiator, pinned)
	r := <-done
	return ci, r.conn, erri, r.err
}

func keys(t *testing.T) (noise.DHKey, noise.DHKey) {
	t.Helper()
	a, err := NewKey()
	if err != nil {
		t.Fatal(err)
	}
	b, err := NewKey()
	if err != nil {
		t.Fatal(err)
	}
	return a, b
}

func allowAll([]byte) error { return nil }

func TestTalk(t *testing.T) {
	phone, mac := keys(t)
	for _, psk := range [][]byte{nil, bytes.Repeat([]byte{7}, 32)} {
		a, b := pipes()
		ci, cr, erri, errr := connect(t, a, b, Config{Static: phone, Prologue: []byte("p"), PSK: psk},
			Config{Static: mac, Prologue: []byte("p"), PSK: psk}, mac.Public, allowAll)
		if erri != nil || errr != nil {
			t.Fatal(erri, errr)
		}
		if !bytes.Equal(ci.Hash(), cr.Hash()) || !bytes.Equal(cr.Peer(), phone.Public) || !bytes.Equal(ci.Peer(), mac.Public) {
			t.Fatal("the sides disagree")
		}
		// More than a message's worth at once, then enough messages each way
		// for both directions to rekey twice.
		big := make([]byte, 3*MaxPlaintext+5)
		rand.Read(big)
		go func() { _, _ = ci.Write(big) }() // the read below checks what came
		got := make([]byte, len(big))
		if _, err := io.ReadFull(cr, got); err != nil || !bytes.Equal(got, big) {
			t.Fatal("a big write came out wrong", err)
		}
		for _, pair := range [][2]*Conn{{ci, cr}, {cr, ci}} {
			go func() {
				for i := range 2*RekeyEvery + 10 {
					_, _ = pair[0].Write([]byte{byte(i)}) // the reads below check each
				}
			}()
			for i := range 2*RekeyEvery + 10 {
				var one [1]byte
				if _, err := io.ReadFull(pair[1], one[:]); err != nil || one[0] != byte(i) {
					t.Fatalf("message %d: %v", i, err)
				}
			}
		}
	}
}

func TestWrongPSK(t *testing.T) {
	phone, mac := keys(t)
	a, b := pipes()
	_, _, erri, errr := connect(t, a, b, Config{Static: phone, PSK: bytes.Repeat([]byte{1}, 32)},
		Config{Static: mac, PSK: bytes.Repeat([]byte{2}, 32)}, mac.Public, allowAll)
	if erri == nil || errr == nil {
		t.Fatal("a wrong pre-shared key got through:", erri, errr)
	}
}

func TestWrongPrologue(t *testing.T) {
	phone, mac := keys(t)
	a, b := pipes()
	_, _, erri, errr := connect(t, a, b, Config{Static: phone, Prologue: []byte("id1")},
		Config{Static: mac, Prologue: []byte("id2")}, mac.Public, allowAll)
	if erri == nil || errr == nil {
		t.Fatal("a wrong prologue got through")
	}
}

// A responder that isn't the pinned key (a man in the middle with a key of
// its own) can't read the first message.
func TestWrongResponder(t *testing.T) {
	phone, mac := keys(t)
	_, other := keys(t)
	a, b := pipes()
	_, _, erri, errr := connect(t, a, b, Config{Static: phone}, Config{Static: other}, mac.Public, allowAll)
	if erri == nil || errr == nil {
		t.Fatal("another responder got through")
	}
}

func TestRefusedInitiator(t *testing.T) {
	phone, mac := keys(t)
	a, b := pipes()
	refuse := func(peer []byte) error {
		if !bytes.Equal(peer, phone.Public) {
			t.Fatal("allow saw another key")
		}
		return errors.New("unknown")
	}
	_, _, erri, errr := connect(t, a, b, Config{Static: phone}, Config{Static: mac}, mac.Public, refuse)
	if erri == nil || errr == nil {
		t.Fatal("a refused initiator got through")
	}
}

// After the handshake, a changed, replayed, dropped or reordered message
// ends the connection.
func TestTamperedMessages(t *testing.T) {
	cases := map[string]func(n int, m []byte) [][]byte{
		"changed": func(n int, m []byte) [][]byte {
			if n == 2 {
				m[len(m)-1] ^= 1
			}
			return [][]byte{m}
		},
		"replayed": func(n int, m []byte) [][]byte {
			if n == 2 {
				return [][]byte{m, m}
			}
			return [][]byte{m}
		},
		"dropped": func(n int, m []byte) [][]byte {
			if n == 2 {
				return nil
			}
			return [][]byte{m}
		},
	}
	var held []byte
	cases["reordered"] = func(n int, m []byte) [][]byte {
		switch n {
		case 2:
			held = m
			return nil
		case 3:
			return [][]byte{m, held}
		}
		return [][]byte{m}
	}
	for name, tamper := range cases {
		t.Run(name, func(t *testing.T) {
			phone, mac := keys(t)
			a, b := pipes()
			a.tamper = tamper // a's messages: 0 the handshake, then 1, 2, 3, 4
			ci, cr, erri, errr := connect(t, a, b, Config{Static: phone}, Config{Static: mac}, mac.Public, allowAll)
			if erri != nil || errr != nil {
				t.Fatal(erri, errr)
			}
			for _, m := range []string{"one", "two", "three", "four"} {
				_, _ = ci.Write([]byte(m)) // the reads below say what the tampering did
			}
			got := ""
			buf := make([]byte, 64)
			var err error
			for err == nil && got != "onetwothreefour" {
				var n int
				n, err = cr.Read(buf)
				got += string(buf[:n])
			}
			if err == nil || !strings.HasPrefix(got, "one") || strings.Contains(got, "four") {
				t.Fatalf("read %q, %v", got, err)
			}
			if _, err := cr.Read(buf); err == nil {
				t.Fatal("the connection went on")
			}
		})
	}
}
