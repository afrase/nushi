package api

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// TranscriptPrefs keeps whether chats' transcripts are copied, and for how
// long (internal/store).
type TranscriptPrefs interface {
	KeepTranscripts() bool
	SetKeepTranscripts(on bool) error
	TranscriptDays() int
	SetTranscriptDays(days int) error
}

func (s *server) ListTranscripts(context.Context, *connect.Request[nushiv1.ListTranscriptsRequest]) (*connect.Response[nushiv1.ListTranscriptsResponse], error) {
	list, err := s.chats.ListCopies()
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	resp := &nushiv1.ListTranscriptsResponse{}
	for _, c := range list {
		resp.TotalBytes += c.Bytes
		resp.Copies = append(resp.Copies, &nushiv1.TranscriptCopy{ChatId: c.Chat, Title: c.Title, Agent: c.Agent, Bytes: c.Bytes, LastWrittenMs: c.Modified.UnixMilli()})
	}
	return connect.NewResponse(resp), nil
}

func (s *server) ClearTranscripts(ctx context.Context, req *connect.Request[nushiv1.ClearTranscriptsRequest]) (*connect.Response[nushiv1.ClearTranscriptsResponse], error) {
	ids := req.Msg.ChatIds
	switch days := req.Msg.OlderThanDays; {
	case req.Msg.All:
		list, err := s.chats.ListCopies()
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}
		ids = nil
		for _, c := range list {
			ids = append(ids, c.Chat)
		}
	case len(ids) == 0 && days > 0:
		var err error
		if ids, err = s.chats.Older(time.Duration(days) * 24 * time.Hour); err != nil {
			return nil, connect.NewError(connect.CodeInternal, err)
		}
	case len(ids) == 0:
		return nil, connect.NewError(connect.CodeInvalidArgument, errors.New("say which copies: chat_ids, all or older_than_days"))
	}
	n, bytes, err := s.chats.ClearCopies(ctx, ids)
	slog.Info("transcript copies cleared", "copies", n, "bytes", bytes, "all", req.Msg.All, "older_than_days", req.Msg.OlderThanDays)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	return connect.NewResponse(&nushiv1.ClearTranscriptsResponse{Cleared: int32(n), Bytes: bytes}), nil
}

// setTranscripts sets what SetSettings gives of the transcripts' settings.
func (s *server) setTranscripts(set *nushiv1.Settings) error {
	if s.transcripts == nil {
		return nil
	}
	if set.TranscriptDays != nil && *set.TranscriptDays < 0 {
		return errors.New("transcript_days can't be negative")
	}
	if set.KeepTranscripts != nil && *set.KeepTranscripts != s.transcripts.KeepTranscripts() {
		if err := s.transcripts.SetKeepTranscripts(*set.KeepTranscripts); err != nil {
			return err
		}
		slog.Info("transcript copies", "keep", *set.KeepTranscripts)
	}
	if set.TranscriptDays != nil {
		return s.transcripts.SetTranscriptDays(int(*set.TranscriptDays))
	}
	return nil
}
