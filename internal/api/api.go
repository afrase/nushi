// Package api serves the daemon's Connect API.
package api

import (
	"context"
	"crypto/subtle"
	"net/http"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/model"
)

// Version is the API version reported by Ping. Bump it when methods are added.
const Version = 2

type server struct {
	chats *chats.Service
	hub   *events.Hub
}

// Handler returns the API, refusing requests that don't carry token.
func Handler(token string, chats *chats.Service, hub *events.Hub) http.Handler {
	mux := http.NewServeMux()
	mux.Handle(nushiv1connect.NewNushiServiceHandler(&server{chats: chats, hub: hub}))
	want := []byte("Bearer " + token)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), want) != 1 {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"code":"unauthenticated","message":"missing or wrong token"}`))
			return
		}
		mux.ServeHTTP(w, r)
	})
}

func (s *server) Ping(context.Context, *connect.Request[nushiv1.PingRequest]) (*connect.Response[nushiv1.PingResponse], error) {
	return connect.NewResponse(&nushiv1.PingResponse{ApiVersion: Version}), nil
}

func (s *server) StartChat(ctx context.Context, req *connect.Request[nushiv1.StartChatRequest]) (*connect.Response[nushiv1.StartChatResponse], error) {
	id, err := s.chats.Start(ctx, req.Msg.Folder)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(&nushiv1.StartChatResponse{ChatId: id}), nil
}

func (s *server) SendPrompt(_ context.Context, req *connect.Request[nushiv1.SendPromptRequest]) (*connect.Response[nushiv1.SendPromptResponse], error) {
	if err := s.chats.Prompt(req.Msg.ChatId, req.Msg.Text); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.SendPromptResponse{}), nil
}

func (s *server) Events(ctx context.Context, _ *connect.Request[nushiv1.EventsRequest], stream *connect.ServerStream[nushiv1.EventsResponse]) error {
	// An empty first message tells the client the subscription is live.
	if err := stream.Send(&nushiv1.EventsResponse{}); err != nil {
		return err
	}
	var err error
	s.hub.Subscribe(ctx.Done(), func(e model.Event) bool {
		err = stream.Send(toProto(e))
		return err == nil
	})
	return err
}

var itemKinds = map[model.ItemKind]nushiv1.ItemKind{
	model.UserMessage:  nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE,
	model.AgentMessage: nushiv1.ItemKind_ITEM_KIND_AGENT_MESSAGE,
}

func toProto(e model.Event) *nushiv1.EventsResponse {
	out := &nushiv1.EventsResponse{ChatId: e.ChatID}
	switch {
	case e.Item != nil:
		out.Kind = &nushiv1.EventsResponse_Item{Item: &nushiv1.ItemEvent{
			Item:   &nushiv1.Item{Id: e.Item.ID, Kind: itemKinds[e.Item.Kind], Text: e.Item.Text},
			Append: e.Append,
		}}
	case e.Status != nil:
		out.Kind = &nushiv1.EventsResponse_Status{Status: &nushiv1.ChatStatus{Busy: e.Status.Busy, Error: e.Status.Error}}
	}
	return out
}
