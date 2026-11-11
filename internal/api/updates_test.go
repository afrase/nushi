package api

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/model"
)

type fakeUpdates struct {
	found    model.Update
	installs int
	refuses  error
}

func (f *fakeUpdates) Install() error {
	f.installs++
	return f.refuses
}

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

// Only the Mac's socket has Homebrew install an update: a device's
// channel is refused by its guard (macOnly) and, past it, by the
// handler's own check. What the service refuses is a failed
// precondition, and the state of an install rides in Ping.
func TestOnlyTheMacInstallsAnUpdate(t *testing.T) {
	u := &fakeUpdates{found: model.Update{Version: "0.29.0", Installing: true, InstallError: "why", Installed: "0.28.1"}}
	req := connect.NewRequest(&nushiv1.InstallUpdateRequest{})
	mac := client(t, New(Services{Updates: u}))
	if _, err := mac.InstallUpdate(t.Context(), req); err != nil || u.installs != 1 {
		t.Fatalf("the Mac: %v, %d installs", err, u.installs)
	}
	for name, tc := range map[string]struct {
		c    nushiv1connect.NushiServiceClient
		says string
	}{
		"a device":            {client(t, ForDevices(Services{Updates: u})), "only the Mac can do this"},
		"a device, unguarded": {client(t, serve(Services{Updates: u}, "device")), "only the Mac installs an update"},
	} {
		_, err := tc.c.InstallUpdate(t.Context(), req)
		if connect.CodeOf(err) != connect.CodePermissionDenied || !strings.Contains(err.Error(), tc.says) || u.installs != 1 {
			t.Errorf("%s: %v, %d installs", name, err, u.installs)
		}
	}
	u.refuses = errors.New("Homebrew didn't install this Nushi")
	if _, err := mac.InstallUpdate(t.Context(), req); connect.CodeOf(err) != connect.CodeFailedPrecondition {
		t.Fatalf("refused: %v", err)
	}
	if _, err := client(t, New(Services{})).InstallUpdate(t.Context(), req); connect.CodeOf(err) != connect.CodeUnimplemented {
		t.Fatalf("no updates: %v", err)
	}
	r, err := mac.Ping(t.Context(), connect.NewRequest(&nushiv1.PingRequest{}))
	if got := r.Msg.GetUpdate(); err != nil || !got.GetInstalling() || got.GetInstallError() != "why" || got.GetInstalled() != "0.28.1" {
		t.Fatalf("ping: %v %v", got, err)
	}
}
