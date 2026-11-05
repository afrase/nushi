package api

import (
	"context"
	"errors"
	"time"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func (s *server) GetSettings(context.Context, *connect.Request[nushiv1.GetSettingsRequest]) (*connect.Response[nushiv1.GetSettingsResponse], error) {
	set := &nushiv1.Settings{SleepAfterMinutes: int32(s.Chats.SleepAfter() / time.Minute)}
	if s.LogPrefs != nil {
		set.DebugLog = s.LogPrefs.DebugLog()
	}
	if s.Transcripts != nil {
		keep, days := s.Transcripts.KeepTranscripts(), int32(s.Transcripts.TranscriptDays())
		set.KeepTranscripts, set.TranscriptDays = &keep, &days
	}
	if s.Updates != nil {
		on := s.Updates.On()
		set.CheckUpdates = &on
	}
	return connect.NewResponse(&nushiv1.GetSettingsResponse{Settings: set}), nil
}

func (s *server) SetSettings(_ context.Context, req *connect.Request[nushiv1.SetSettingsRequest]) (*connect.Response[nushiv1.SetSettingsResponse], error) {
	m := req.Msg.GetSettings().GetSleepAfterMinutes()
	if m < 0 {
		return nil, connect.NewError(connect.CodeInvalidArgument, errors.New("sleep_after_minutes can't be negative"))
	}
	if err := s.Chats.SetSleepAfter(time.Duration(m) * time.Minute); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	if err := s.setDebugLog(req.Msg.GetSettings().GetDebugLog()); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	if err := s.setTranscripts(req.Msg.GetSettings()); err != nil {
		return nil, invalid(err)
	}
	if err := s.setCheckUpdates(req.Msg.GetSettings()); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	return connect.NewResponse(&nushiv1.SetSettingsResponse{}), nil
}
