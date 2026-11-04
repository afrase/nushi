package api

import (
	"bytes"
	"testing"

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
