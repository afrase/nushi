package webpush

import (
	"bytes"
	"context"
	"crypto/ecdh"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"math/big"
	"net/http"
	"strings"
	"testing"
	"time"
)

func unb64(t *testing.T, s string) []byte {
	t.Helper()
	b, err := base64.RawURLEncoding.DecodeString(strings.ReplaceAll(s, " ", ""))
	if err != nil {
		t.Fatal(err)
	}
	return b
}

// RFC 8291's example (section 5, intermediate values in Appendix A).
func TestRFC8291Vector(t *testing.T) {
	as, err := ecdh.P256().NewPrivateKey(unb64(t, "yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw"))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(as.PublicKey().Bytes(), unb64(t, "BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8")) {
		t.Fatal("as_public")
	}
	sub := Subscription{
		Endpoint: "https://web.push.apple.com/x",
		P256DH:   unb64(t, "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4"),
		Auth:     unb64(t, "BTBZMqHH6r4Tts7J_aSIgg"),
	}
	got, err := encrypt(sub, unb64(t, "V2hlbiBJIGdyb3cgdXAsIEkgd2FudCB0byBiZSBhIHdhdGVybWVsb24"), 0, as, unb64(t, "DGv6ra1nlYgDCS1FRnbzlw"))
	if err != nil {
		t.Fatal(err)
	}
	want := append(unb64(t, "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z 9KsN6nGRTbVYI_c7VJSPQTBtkgcy27ml mlMoZIIgDll6e3vCYLocInmYWAmS6Tlz AC8wEqKK6PBru3jl7A8"),
		unb64(t, "8pfeW0KbunFT06SuDKoJH9Ql87S1QUrd irN6GcG7sFz1y1sqLgVi1VhjVkHsUoEs bI_0LpXMuGvnzQ")...)
	if !bytes.Equal(got, want) {
		t.Fatalf("got  %x\nwant %x", got, want)
	}
	// The browser's side decrypts it (ua_private).
	ua, _ := ecdh.P256().NewPrivateKey(unb64(t, "q1dXpw3UpT5VOmu_cf_v6ih07Aems3njxI-JWgLcM94"))
	fresh, err := Encrypt(sub, []byte("Claude finished"))
	if err != nil {
		t.Fatal(err)
	}
	if long, _ := Encrypt(sub, []byte("Codex has a question, with a longer title")); len(long) != len(fresh) {
		t.Errorf("payloads of %d and %d bytes: their length tells", len(fresh), len(long))
	}
	if plain := decrypt(t, ua, sub.Auth, fresh); string(plain) != "Claude finished" {
		t.Fatalf("decrypted %q", plain)
	}
}

func TestAllowlist(t *testing.T) {
	for _, ok := range []string{
		"https://web.push.apple.com/QGuQyavXutnMH",
		"https://api.push.apple.com/3/device/x",
		"https://fcm.googleapis.com/fcm/send/abc",
		"https://updates.push.services.mozilla.com/wpush/v2/x",
		"https://wns2-par02p.notify.windows.com/w/?token=x",
		"https://WEB.PUSH.APPLE.COM/x",
	} {
		if err := Check(ok); err != nil {
			t.Errorf("%s: %v", ok, err)
		}
	}
	for _, bad := range []string{
		"http://web.push.apple.com/x",          // not https
		"https://web.push.apple.com:8443/x",    // another port
		"https://push.apple.com/x",             // the suffix alone
		"https://evilpush.apple.com.evil.com/", // a lookalike
		"https://web.push.apple.com.evil.com/x",
		"https://fcm.googleapis.com@evil.com/x",
		"https://user@fcm.googleapis.com/x",
		"https://127.0.0.1/x",
		"https://localhost/x",
		"https://169.254.169.254/latest",
		"https://evil.notify.windows.com.evil/x",
		"file:///etc/passwd",
		"https://[::ffff:127.0.0.1%25x.push.apple.com]/x", // a zone that ends like a push service
		"https://web.push.apple.com:/x",                   // an empty port
		"https://web.push.apple.com:443/x",
		"https://web.push.apple.com/" + strings.Repeat("x", MaxEndpoint),
		"ftp://fcm.googleapis.com/x",
		"",
	} {
		if err := Check(bad); err == nil {
			t.Errorf("%s passed", bad)
		}
	}
	keys, _ := NewKeys()
	good := Subscription{Endpoint: "https://web.push.apple.com/x", P256DH: keys.Public, Auth: make([]byte, 16)}
	if err := CheckSubscription(good); err != nil {
		t.Error(err)
	}
	for _, bad := range []Subscription{
		{Endpoint: good.Endpoint, P256DH: keys.Public, Auth: make([]byte, 15)},
		{Endpoint: good.Endpoint, P256DH: append([]byte{4}, make([]byte, 64)...), Auth: good.Auth},
		{Endpoint: "https://example.com/x", P256DH: keys.Public, Auth: good.Auth},
	} {
		if CheckSubscription(bad) == nil {
			t.Errorf("%+v passed", bad)
		}
	}
}

// roundTrip is an http.RoundTripper that answers as a push service would.
type roundTrip func(*http.Request) (*http.Response, error)

func (f roundTrip) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestSend(t *testing.T) {
	keys, err := NewKeys()
	if err != nil {
		t.Fatal(err)
	}
	ua, _ := ecdh.P256().GenerateKey(nil)
	sub := Subscription{Endpoint: "https://web.push.apple.com/abc", P256DH: ua.PublicKey().Bytes(), Auth: []byte("0123456789abcdef")}
	status := http.StatusCreated
	var got *http.Request
	var body []byte
	snd := &Sender{Keys: keys, Subject: "https://relay.example.com", Client: &http.Client{Transport: roundTrip(func(r *http.Request) (*http.Response, error) {
		got = r
		body, _ = io.ReadAll(r.Body)
		return &http.Response{StatusCode: status, Status: http.StatusText(status), Body: io.NopCloser(strings.NewReader("")), Header: http.Header{}}, nil
	})}}
	m := Message{Payload: []byte(`{"title":"Claude finished"}`), Topic: "abc", Urgent: true, TTL: time.Hour}
	if err := snd.Send(context.Background(), sub, m); err != nil {
		t.Fatal(err)
	}
	for k, v := range map[string]string{"Content-Encoding": "aes128gcm", "TTL": "3600", "Urgency": "high", "Topic": "abc"} {
		if got.Header.Get(k) != v {
			t.Errorf("%s: %q", k, got.Header.Get(k))
		}
	}
	if plain := decrypt(t, ua, sub.Auth, body); !bytes.Equal(plain, m.Payload) {
		t.Errorf("payload %q", plain)
	}
	checkVAPID(t, got.Header.Get("Authorization"), keys, "https://web.push.apple.com")

	for _, gone := range []int{http.StatusNotFound, http.StatusGone} {
		status = gone
		if err := snd.Send(context.Background(), sub, m); !errors.Is(err, ErrGone) {
			t.Errorf("%d: %v", gone, err)
		}
	}
	status = http.StatusTooManyRequests
	if err := snd.Send(context.Background(), sub, m); err == nil || errors.Is(err, ErrGone) {
		t.Errorf("429: %v", err)
	}
	// A failure doesn't name the endpoint: it's the subscription's secret.
	down := &Sender{Keys: keys, Subject: snd.Subject, Client: &http.Client{Transport: roundTrip(func(*http.Request) (*http.Response, error) {
		return nil, errors.New("connection refused")
	})}}
	if err := down.Send(context.Background(), sub, m); err == nil || strings.Contains(err.Error(), "abc") {
		t.Errorf("a failure: %v", err)
	}
	got = nil
	sub.Endpoint = "https://evil.example.com/x"
	if err := snd.Send(context.Background(), sub, m); err == nil || got != nil {
		t.Error("sent to a host off the allowlist")
	}
}

// checkVAPID verifies the header's JWT with the public key (RFC 8292).
func checkVAPID(t *testing.T, header string, keys Keys, aud string) {
	t.Helper()
	tok, k, ok := strings.Cut(strings.TrimPrefix(header, "vapid t="), ", k=")
	if !ok || k != keys.PublicKey() {
		t.Fatalf("Authorization: %q", header)
	}
	parts := strings.Split(tok, ".")
	if len(parts) != 3 {
		t.Fatalf("JWT %q", tok)
	}
	var claims struct {
		Aud, Sub string
		Exp      int64
	}
	if err := json.Unmarshal(unb64(t, parts[1]), &claims); err != nil {
		t.Fatal(err)
	}
	if claims.Aud != aud || claims.Sub != "https://relay.example.com" || claims.Exp <= time.Now().Unix() || claims.Exp > time.Now().Add(24*time.Hour).Unix() {
		t.Errorf("claims %+v", claims)
	}
	x, y := elliptic.Unmarshal(elliptic.P256(), keys.Public) //nolint:staticcheck // a test's verification
	pub := &ecdsa.PublicKey{Curve: elliptic.P256(), X: x, Y: y}
	sig := unb64(t, parts[2])
	h := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if !ecdsa.Verify(pub, h[:], new(big.Int).SetBytes(sig[:32]), new(big.Int).SetBytes(sig[32:])) {
		t.Error("the JWT's signature doesn't verify")
	}
}
