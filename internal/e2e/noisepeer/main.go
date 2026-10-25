// Command noisepeer is the daemon's side of a Noise channel for the Dart
// interop tests (packages/remote_transport): it runs a relay on localhost,
// waits on it as the responder, and echoes what comes. It prints the relay,
// the id, its key and the secret as one JSON line.
//
//	-psk          pair (IKpsk1) rather than connect (IK)
//	-tamper N     flip a bit in its Nth answer
//	-replay N     send its Nth answer twice
//	-mute         answer nothing after the handshake
package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http/httptest"
	"os"
	"strings"

	"github.com/afrase/nushi/noiseconn"
	"github.com/afrase/nushi/relay"
)

type transport struct {
	*relay.Conn
	n, tamper, replay int
}

func (t *transport) WriteMessage(m []byte) error {
	t.n++ // the handshake's answer is 1, then the echoes
	if t.n == t.tamper+1 {
		m = append([]byte(nil), m...)
		m[len(m)-1] ^= 1
	}
	if t.n == t.replay+1 {
		if err := t.Conn.WriteMessage(m); err != nil {
			return err
		}
	}
	return t.Conn.WriteMessage(m)
}

func main() {
	pair := flag.Bool("psk", false, "pair (IKpsk1)")
	tamper := flag.Int("tamper", -1, "flip a bit in this answer")
	replay := flag.Int("replay", -1, "send this answer twice")
	mute := flag.Bool("mute", false, "answer nothing after the handshake")
	flag.Parse()
	srv := httptest.NewServer(relay.New(relay.Defaults))
	defer srv.Close()
	key, err := noiseconn.NewKey()
	if err != nil {
		log.Fatal(err) //nolint:gocritic // the process ends, the server with it
	}
	_, listen, _ := ed25519.GenerateKey(rand.Reader)
	id, psk := relay.ListenID(listen.Public().(ed25519.PublicKey)), []byte(strings.Repeat("s", 32))
	b64 := base64.RawURLEncoding.EncodeToString
	line, _ := json.Marshal(map[string]string{"relay": "ws" + strings.TrimPrefix(srv.URL, "http"), "id": id, "key": b64(key.Public), "psk": b64(psk)})
	fmt.Println(string(line)) //nolint:forbidigo // the test reads this line

	var dl relay.Dialer
	c, err := dl.Listen(context.Background(), "ws"+strings.TrimPrefix(srv.URL, "http"), listen)
	if err != nil {
		log.Fatal(err)
	}
	cfg := noiseconn.Config{Static: key, Prologue: []byte("nushi-remote/1\x00" + id)}
	if *pair {
		cfg.PSK = psk
	}
	conn, err := noiseconn.Respond(&transport{Conn: c, tamper: *tamper, replay: *replay}, cfg, func([]byte) error { return nil })
	if err != nil {
		fmt.Fprintln(os.Stderr, "handshake:", err)
		os.Exit(2)
	}
	buf := make([]byte, noiseconn.MaxPlaintext)
	for {
		n, err := conn.Read(buf)
		if err != nil {
			return
		}
		if *mute {
			continue
		}
		if _, err := conn.Write(buf[:n]); err != nil {
			return
		}
	}
}
