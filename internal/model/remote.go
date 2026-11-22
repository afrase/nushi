package model

import "time"

// RemoteSettings are remote access's switch and the relay it uses.
type RemoteSettings struct {
	On    bool   `json:"on"`
	Relay string `json:"relay,omitempty"`
}

// RemoteKey is the daemon's static Noise key and its listen key at the
// relay (an Ed25519 private key, whose hash is the daemon's rendezvous id),
// made once.
type RemoteKey struct {
	Private []byte   `json:"private"`
	Public  []byte   `json:"public"`
	Listen  []byte   `json:"listen"`
	Moving  []Moving `json:"moving,omitempty"`
	// Reset says remote access started over, kept with the key it started
	// over with until a phone is next paired.
	Reset *RemoteReset `json:"reset,omitempty"`
}

// RemoteReset says remote access started over because a file of it didn't
// parse (ADR 0034's 2026-11-22 amendment): a fresh key and no paired
// devices, so every phone pairs again.
type RemoteReset struct {
	At time.Time `json:"at"`
	// Files are the files that didn't parse, each as it was set aside
	// beside the others: "remote-key.json.unreadable-<time>".
	Files []string `json:"files"`
}

// Moving is a rendezvous id the daemon gave up when it revoked a device,
// with the Noise key it had there: it still waits there for the devices
// still paired then, until each has connected at the new id.
type Moving struct {
	Listen  []byte    `json:"listen"`
	Private []byte    `json:"private,omitempty"` // empty in files from before the key moved too: the daemon's key then
	Public  []byte    `json:"public,omitempty"`
	Devices []string  `json:"devices"`
	Since   time.Time `json:"since"`
}

// Device is a paired phone.
type Device struct {
	ID       string    `json:"id"`
	Name     string    `json:"name"`
	Key      []byte    `json:"key"` // its static public key
	Paired   time.Time `json:"paired"`
	LastSeen time.Time `json:"last_seen,omitzero"`
	// Kind is "web" for the web app, "" for an app.
	Kind string `json:"kind,omitempty"`
	// Push is its Web Push subscription, when notifications are on.
	Push *Push `json:"push,omitempty"`
	// Connected says it has a connection open now.
	Connected bool `json:"-"`
}

// Push is a device's Web Push subscription (ADR 0054).
type Push struct {
	Endpoint string `json:"endpoint"`
	P256DH   []byte `json:"p256dh"`
	Auth     []byte `json:"auth"`
}

// VAPIDKey is the key pair the daemon signs Web Push messages with
// (P-256: the private scalar and the uncompressed public key), made once.
type VAPIDKey struct {
	Private []byte `json:"private"`
	Public  []byte `json:"public"`
}

// Remote is remote access as it stands.
type Remote struct {
	RemoteSettings
	// State is "off", "connecting", "connected" (waiting at the relay) or
	// "error" (Error says what, and it tries again).
	State   string
	Error   string
	Devices []Device
	Pairing *Pairing
	// Rendezvous is the daemon's id at the relay, where its phones dial.
	Rendezvous string
	// Key is the daemon's Noise public key, for its fingerprint.
	Key []byte
	// Reset is set while remote access has started over and no phone has
	// been paired since.
	Reset *RemoteReset
}

// Pairing is a phone being paired: once it has connected, its name and
// the code both screens show.
type Pairing struct {
	Name, Code string
}
