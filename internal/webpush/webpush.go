// Package webpush sends Web Push messages straight to a browser's push
// service (ADR 0054): the payload encrypted for the subscription (RFC 8291,
// aes128gcm from RFC 8188), the request signed with the sender's VAPID key
// (RFC 8292). Only the push services on an allowlist are sent to.
package webpush

import (
	"bytes"
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/hkdf"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"slices"
	"strconv"
	"strings"
	"time"
)

// Subscription is what a browser's pushManager.subscribe gave: where to
// send, and the keys to encrypt for.
type Subscription struct {
	Endpoint string
	P256DH   []byte // the browser's public key, uncompressed (65 bytes)
	Auth     []byte // the authentication secret (16 bytes)
}

// Keys are a VAPID key pair (P-256): the private key's scalar and the
// public key, uncompressed.
type Keys struct {
	Private []byte `json:"private"`
	Public  []byte `json:"public"`
}

// NewKeys makes a VAPID key pair.
func NewKeys() (Keys, error) {
	k, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		return Keys{}, err
	}
	return Keys{Private: k.Bytes(), Public: k.PublicKey().Bytes()}, nil
}

// PublicKey is the public key as the browser takes it
// (applicationServerKey): base64url, unpadded.
func (k Keys) PublicKey() string { return b64(k.Public) }

var b64 = base64.RawURLEncoding.EncodeToString

// pushHosts are the push services subscriptions may name: Apple's, Google's
// (Chrome, Edge on Android), Mozilla's and Microsoft's (Edge on Windows).
// Anything else is refused, so a client can't make the daemon send
// requests where it likes.
var (
	pushHosts    = []string{"web.push.apple.com", "fcm.googleapis.com", "updates.push.services.mozilla.com"}
	pushSuffixes = []string{".push.apple.com", ".notify.windows.com"}
)

// Check says whether endpoint is an https URL at a known push service,
// on the default port.
func Check(endpoint string) error {
	u, err := url.Parse(endpoint)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Port() != "" || u.Opaque != "" {
		return errors.New("the push endpoint must be an https URL")
	}
	host := strings.ToLower(u.Hostname())
	if slices.Contains(pushHosts, host) {
		return nil
	}
	for _, s := range pushSuffixes {
		if strings.HasSuffix(host, s) && len(host) > len(s) {
			return nil
		}
	}
	return fmt.Errorf("%s isn't a push service Nushi knows", host)
}

// CheckSubscription checks the endpoint and the keys' sizes, and that the
// browser's key is a point on P-256.
func CheckSubscription(s Subscription) error {
	if err := Check(s.Endpoint); err != nil {
		return err
	}
	if len(s.Auth) != 16 {
		return errors.New("the push subscription's auth secret isn't 16 bytes")
	}
	if _, err := ecdh.P256().NewPublicKey(s.P256DH); err != nil {
		return errors.New("the push subscription's key isn't a P-256 key")
	}
	return nil
}

// Encrypt encrypts plaintext for s as one aes128gcm record (RFC 8291),
// with a fresh key pair and salt.
func Encrypt(s Subscription, plaintext []byte) ([]byte, error) {
	as, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		return nil, err
	}
	salt := make([]byte, 16)
	rand.Read(salt)
	return encrypt(s, plaintext, as, salt)
}

// recordSize is the header's rs: the payload is one record, at most this.
const recordSize = 4096

func encrypt(s Subscription, plaintext []byte, as *ecdh.PrivateKey, salt []byte) ([]byte, error) {
	ua, err := ecdh.P256().NewPublicKey(s.P256DH)
	if err != nil {
		return nil, err
	}
	if len(s.Auth) != 16 {
		return nil, errors.New("webpush: the auth secret is 16 bytes")
	}
	if len(plaintext)+1+16 > recordSize {
		return nil, errors.New("webpush: the message is too long")
	}
	secret, err := as.ECDH(ua)
	if err != nil {
		return nil, err
	}
	asPub := as.PublicKey().Bytes()
	// The input keying material: HKDF with the auth secret as salt over the
	// ECDH secret, its info "WebPush: info", a zero, ua_public, as_public.
	info := append(append([]byte("WebPush: info\x00"), s.P256DH...), asPub...)
	ikm, err := hkdf.Key(sha256.New, secret, s.Auth, string(info), 32)
	if err != nil {
		return nil, err
	}
	prk, err := hkdf.Extract(sha256.New, ikm, salt)
	if err != nil {
		return nil, err
	}
	cek, err := hkdf.Expand(sha256.New, prk, "Content-Encoding: aes128gcm\x00", 16)
	if err != nil {
		return nil, err
	}
	nonce, err := hkdf.Expand(sha256.New, prk, "Content-Encoding: nonce\x00", 12)
	if err != nil {
		return nil, err
	}
	block, err := aes.NewCipher(cek)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	// The header: salt, rs, the key id's length and the key id (as_public).
	out := append([]byte(nil), salt...)
	out = binary.BigEndian.AppendUint32(out, recordSize)
	out = append(out, 65) // the key id's length: an uncompressed P-256 key
	out = append(out, asPub...)
	// The last (and only) record ends with the delimiter 2, no padding.
	return gcm.Seal(out, nonce, append(append([]byte(nil), plaintext...), 2), nil), nil
}

// ErrGone says the push service no longer knows the subscription (404 or
// 410): it is to be forgotten.
var ErrGone = errors.New("the push subscription has expired or was removed")

// Sender sends messages, signed with its VAPID keys.
type Sender struct {
	Keys    Keys
	Subject string       // a contact for the push service: https:// or mailto:
	Client  *http.Client // nil: a client of its own, without redirects
}

// Message is one push: its payload, and how the push service treats it.
type Message struct {
	Payload []byte
	Topic   string        // a newer message of the same topic replaces one not yet delivered (32 base64url characters at most)
	Urgent  bool          // Urgency: high, else normal
	TTL     time.Duration // how long the service keeps it for an offline device
}

var defaultClient = &http.Client{Timeout: 30 * time.Second,
	CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}

// Send encrypts m for s and posts it to s's endpoint, which must be a known
// push service. A 404 or 410 is ErrGone.
func (snd *Sender) Send(ctx context.Context, s Subscription, m Message) error {
	if err := Check(s.Endpoint); err != nil {
		return err
	}
	body, err := Encrypt(s, m.Payload)
	if err != nil {
		return err
	}
	auth, err := snd.vapid(s.Endpoint, time.Now())
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.Endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", auth)
	req.Header.Set("Content-Encoding", "aes128gcm")
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("TTL", strconv.Itoa(int(m.TTL.Seconds())))
	req.Header.Set("Urgency", map[bool]string{true: "high", false: "normal"}[m.Urgent])
	if m.Topic != "" {
		req.Header.Set("Topic", m.Topic)
	}
	c := snd.Client
	if c == nil {
		c = defaultClient
	}
	resp, err := c.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close() //nolint:errcheck // read-only
	_, _ = io.CopyN(io.Discard, resp.Body, 4<<10)
	switch {
	case resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusGone:
		return ErrGone
	case resp.StatusCode/100 != 2:
		// The status only: a service's answer could echo what was sent.
		return fmt.Errorf("the push service answered %s", resp.Status)
	}
	return nil
}

// vapid is the Authorization header for endpoint (RFC 8292): a JWT signed
// with ES256 for the endpoint's origin, good for an hour, and the public key.
func (snd *Sender) vapid(endpoint string, now time.Time) (string, error) {
	u, err := url.Parse(endpoint)
	if err != nil {
		return "", err
	}
	key, err := ecdsa.ParseRawPrivateKey(elliptic.P256(), snd.Keys.Private)
	if err != nil {
		return "", err
	}
	claims, _ := json.Marshal(struct {
		Aud string `json:"aud"`
		Exp int64  `json:"exp"`
		Sub string `json:"sub"`
	}{u.Scheme + "://" + u.Host, now.Add(time.Hour).Unix(), snd.Subject})
	signed := b64([]byte(`{"typ":"JWT","alg":"ES256"}`)) + "." + b64(claims)
	h := sha256.Sum256([]byte(signed))
	r, s, err := ecdsa.Sign(rand.Reader, key, h[:])
	if err != nil {
		return "", err
	}
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	s.FillBytes(sig[32:])
	return "vapid t=" + signed + "." + b64(sig) + ", k=" + b64(snd.Keys.Public), nil
}
