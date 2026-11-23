package api

import (
	"bytes"
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// The daemon's id goes out in Remote.id and Remote.rendezvous stays
// empty: a phone on a web build from before the Noise key moved on a
// revoke moves to rendezvous with the key it pinned, which the new id
// doesn't answer. Left empty, it keeps dialing its old id, which still
// answers it with the old key, until its app updates.
func TestRemoteSendsTheIDOnlyWhereNewPhonesRead(t *testing.T) {
	key := bytes.Repeat([]byte{7}, 32)
	r := remoteProto(model.Remote{Rendezvous: "new-id", Key: key})
	if r.GetId() != "new-id" || !bytes.Equal(r.GetKey(), key) {
		t.Fatalf("id %q, key %x", r.GetId(), r.GetKey())
	}
	if r.GetRendezvous() != "" {
		t.Fatalf("rendezvous %q: an older phone would move there with its old key", r.GetRendezvous())
	}
}

// A reset goes out in Remote.was_reset, with its time and the files set
// aside; none, none.
func TestRemoteSaysItWasReset(t *testing.T) {
	if r := remoteProto(model.Remote{}); r.GetWasReset() != nil {
		t.Fatalf("no reset sent %v", r.GetWasReset())
	}
	at := time.UnixMilli(1_790_000_000_000)
	files := []string{"remote-key.json.unreadable-2026-11-22T10-00-00.000000"}
	r := remoteProto(model.Remote{Reset: &model.RemoteReset{At: at, Files: files}}).GetWasReset()
	if r.GetAt() != at.UnixMilli() || !slices.Equal(r.GetFiles(), files) {
		t.Fatalf("reset %v", r)
	}
}

// Every device goes out as the web app, which an older app labels it by,
// whatever devices.json kept.
func TestEveryDeviceIsTheWebApp(t *testing.T) {
	r := remoteProto(model.Remote{Devices: []model.Device{{ID: "d1"}, {ID: "d2"}}})
	for _, d := range r.GetDevices() {
		if d.GetKind() != "web" {
			t.Errorf("%s: kind %q", d.GetId(), d.GetKind())
		}
	}
	if len(r.GetDevices()) != 2 {
		t.Errorf("devices %v", r.GetDevices())
	}
}
