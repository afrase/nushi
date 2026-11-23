package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

var errNoUpdates = errors.New("this daemon doesn't check for updates")

// Updates checks for a newer release of Nushi
// (internal/features/updates).
type Updates interface {
	Get() model.Update
	Check(ctx context.Context) (model.Update, error)
	On() bool
	// Turned does what checks turned on or off call for, once the setting
	// is written (SetSettings): on checks at once, off forgets a release
	// found.
	Turned(on bool)
	// Install has Homebrew upgrade the cask that installed Nushi, and
	// returns once it has started.
	Install() error
}

func (s *server) CheckForUpdates(ctx context.Context, _ *connect.Request[nushiv1.CheckForUpdatesRequest]) (*connect.Response[nushiv1.CheckForUpdatesResponse], error) {
	if s.Updates == nil {
		return nil, connect.NewError(connect.CodeUnimplemented, errNoUpdates)
	}
	u, err := s.Updates.Check(ctx)
	if err != nil {
		return nil, githubErr(err) // the release check is GitHub's; not Unavailable, the daemon gone to the app
	}
	return connect.NewResponse(&nushiv1.CheckForUpdatesResponse{Update: updateProto(u)}), nil
}

// InstallUpdate has the daemon upgrade Nushi with Homebrew (ADR 0109).
// The request names nothing, and a paired device never asks: the call is
// in macOnly.
func (s *server) InstallUpdate(context.Context, *connect.Request[nushiv1.InstallUpdateRequest]) (*connect.Response[nushiv1.InstallUpdateResponse], error) {
	if s.Updates == nil {
		return nil, connect.NewError(connect.CodeUnimplemented, errNoUpdates)
	}
	if err := s.Updates.Install(); err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.InstallUpdateResponse{}), nil
}

// update is what the last check found; nil when the daemon doesn't check.
func (s *server) update() *nushiv1.UpdateCheck {
	if s.Updates == nil {
		return nil
	}
	return updateProto(s.Updates.Get())
}

func updateProto(u model.Update) *nushiv1.UpdateCheck {
	return &nushiv1.UpdateCheck{Version: u.Version, Url: u.URL, Latest: u.Latest, CheckedMs: unixMs(u.Checked),
		Installing: u.Installing, InstallError: u.InstallError, Installed: u.Installed}
}
