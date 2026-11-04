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
	SetOn(on bool) error
}

func (s *server) CheckForUpdates(ctx context.Context, _ *connect.Request[nushiv1.CheckForUpdatesRequest]) (*connect.Response[nushiv1.CheckForUpdatesResponse], error) {
	if s.Updates == nil {
		return nil, connect.NewError(connect.CodeUnimplemented, errNoUpdates)
	}
	u, err := s.Updates.Check(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeUnavailable, err)
	}
	return connect.NewResponse(&nushiv1.CheckForUpdatesResponse{Update: updateProto(u)}), nil
}

// update is what the last check found; nil when the daemon doesn't check.
func (s *server) update() *nushiv1.UpdateCheck {
	if s.Updates == nil {
		return nil
	}
	return updateProto(s.Updates.Get())
}

func updateProto(u model.Update) *nushiv1.UpdateCheck {
	return &nushiv1.UpdateCheck{Version: u.Version, Url: u.URL, Latest: u.Latest, CheckedMs: unixMs(u.Checked)}
}

// setCheckUpdates turns the checks on or off, when given and changed.
func (s *server) setCheckUpdates(set *nushiv1.Settings) error {
	if s.Updates == nil || set.CheckUpdates == nil || *set.CheckUpdates == s.Updates.On() {
		return nil
	}
	return s.Updates.SetOn(*set.CheckUpdates)
}
