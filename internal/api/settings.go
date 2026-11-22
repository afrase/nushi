package api

import (
	"context"
	"errors"
	"log/slog"
	"maps"
	"slices"
	"time"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/model"
)

// Settings are the daemon's own settings (internal/store's settings.json):
// the debug log, transcripts' copies and, by agent, whether its chats run
// through Nushi's Go agent (ADR 0142; the agents feature reads it each
// time an agent's chat starts it, so a change needs no restart). A change
// is one write, so a request is applied whole or not at all.
type Settings interface {
	DebugLog() bool
	KeepTranscripts() bool
	TranscriptDays() int
	GoAgent(name string) bool
	ChangeSettings(model.SettingsChange) error
}

func (s *server) GetSettings(context.Context, *connect.Request[nushiv1.GetSettingsRequest]) (*connect.Response[nushiv1.GetSettingsResponse], error) {
	set := &nushiv1.Settings{SleepAfterMinutes: int32(s.Chats.SleepAfter() / time.Minute)}
	if s.Settings != nil {
		set.DebugLog = s.Settings.DebugLog()
		keep, days := s.Settings.KeepTranscripts(), int32(s.Settings.TranscriptDays())
		set.KeepTranscripts, set.TranscriptDays = &keep, &days
	}
	if s.Updates != nil {
		on := s.Updates.On()
		set.CheckUpdates = &on
	}
	s.goAgents(set)
	return connect.NewResponse(&nushiv1.GetSettingsResponse{Settings: set}), nil
}

// SetSettings checks every field before anything is written, then makes
// the change in one write, then does what a changed value calls for.
// sleep_after_minutes and debug_log are always set (proto's Settings); the
// others only when given.
func (s *server) SetSettings(_ context.Context, req *connect.Request[nushiv1.SetSettingsRequest]) (*connect.Response[nushiv1.SetSettingsResponse], error) {
	set := req.Msg.GetSettings()
	switch {
	case s.Settings == nil:
		return nil, connect.NewError(connect.CodeUnimplemented, errors.New("this daemon keeps no settings"))
	case set.GetSleepAfterMinutes() < 0:
		return nil, invalid(errors.New("sleep_after_minutes can't be negative"))
	case set.TranscriptDays != nil && *set.TranscriptDays < 0:
		return nil, invalid(errors.New("transcript_days can't be negative"))
	}
	if err := s.checkGoAgents(set); err != nil {
		return nil, err
	}
	sleep, debug := time.Duration(set.GetSleepAfterMinutes())*time.Minute, set.GetDebugLog()
	change := model.SettingsChange{SleepAfter: &sleep, DebugLog: &debug, KeepTranscripts: set.KeepTranscripts, GoAgents: s.goAgentsChange(set)}
	if set.TranscriptDays != nil {
		change.TranscriptDays = new(int(*set.TranscriptDays))
	}
	turned := s.Updates != nil && set.CheckUpdates != nil && *set.CheckUpdates != s.Updates.On()
	if turned {
		change.CheckUpdates = set.CheckUpdates
	}
	debugWas, keepWas := s.Settings.DebugLog(), s.Settings.KeepTranscripts()
	if err := s.Settings.ChangeSettings(change); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	if debug != debugWas {
		logs.SetDebug(debug)
		slog.Info("debug lines", "on", debug, "level", logs.Level.Level())
	}
	if keep := set.KeepTranscripts; keep != nil && *keep != keepWas {
		slog.Info("transcript copies", "keep", *keep)
	}
	for _, name := range slices.Sorted(maps.Keys(change.GoAgents)) {
		slog.Info("go agent", "agent", name, "on", change.GoAgents[name])
	}
	if turned {
		s.Updates.Turned(*set.CheckUpdates)
	}
	return connect.NewResponse(&nushiv1.SetSettingsResponse{}), nil
}
