package api

import (
	"context"
	"testing"
	"time"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

type fakeUpdates struct{ found model.Update }

func (f *fakeUpdates) Get() model.Update { return f.found }
func (f *fakeUpdates) Check(context.Context) (model.Update, error) {
	f.found.Checked = time.UnixMilli(2000)
	return f.found, nil
}
func (f *fakeUpdates) On() bool         { return true }
func (f *fakeUpdates) SetOn(bool) error { return nil }

// Ping carries what the update check found; Check for updates asks now;
// a device's channel can't.
func TestPingSaysTheUpdate(t *testing.T) {
	u := &fakeUpdates{found: model.Update{Version: "0.1.17", URL: "https://github.com/afrase/nushi/releases/tag/v0.1.17", Latest: "0.1.17", Checked: time.UnixMilli(1000)}}
	c := client(t, New(Services{Updates: u}))
	r, err := c.Ping(t.Context(), connect.NewRequest(&nushiv1.PingRequest{}))
	if err != nil {
		t.Fatal(err)
	}
	if got := r.Msg.GetUpdate(); got.GetVersion() != "0.1.17" || got.GetUrl() != u.found.URL || got.GetCheckedMs() != 1000 {
		t.Fatalf("ping: %v", got)
	}
	cr, err := c.CheckForUpdates(t.Context(), connect.NewRequest(&nushiv1.CheckForUpdatesRequest{}))
	if err != nil || cr.Msg.GetUpdate().GetCheckedMs() != 2000 {
		t.Fatalf("check: %v %v", cr, err)
	}
	_, err = client(t, ForDevices(Services{Updates: u})).CheckForUpdates(t.Context(), connect.NewRequest(&nushiv1.CheckForUpdatesRequest{}))
	if connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Fatalf("a device: %v", err)
	}
}
