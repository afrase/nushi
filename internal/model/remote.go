package model

import "time"

// RemoteSettings are remote access's switch and the relay it uses.
type RemoteSettings struct {
	On    bool   `json:"on"`
	Relay string `json:"relay,omitempty"`
}

// RemoteKey is the daemon's static Noise key and its rendezvous id at the
// relay, made once.
type RemoteKey struct {
	Private []byte `json:"private"`
	Public  []byte `json:"public"`
	ID      string `json:"id"`
}

// Device is a paired phone.
type Device struct {
	ID       string    `json:"id"`
	Name     string    `json:"name"`
	Key      []byte    `json:"key"` // its static public key
	Paired   time.Time `json:"paired"`
	LastSeen time.Time `json:"last_seen,omitzero"`
	// Connected says it has a connection open now.
	Connected bool `json:"-"`
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
}

// Pairing is a phone being paired: waiting for it until Expires, then,
// once it has connected, its name and the code both screens show.
type Pairing struct {
	Expires    time.Time
	Name, Code string
}
