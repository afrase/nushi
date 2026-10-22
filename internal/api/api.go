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
const Version = 4

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

func (s *server) AnswerPermission(_ context.Context, req *connect.Request[nushiv1.AnswerPermissionRequest]) (*connect.Response[nushiv1.AnswerPermissionResponse], error) {
	if err := s.chats.AnswerPermission(req.Msg.ChatId, req.Msg.ItemId, req.Msg.OptionId); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.AnswerPermissionResponse{}), nil
}

func (s *server) AnswerQuestion(_ context.Context, req *connect.Request[nushiv1.AnswerQuestionRequest]) (*connect.Response[nushiv1.AnswerQuestionResponse], error) {
	var values map[string][]string
	if !req.Msg.Decline {
		values = map[string][]string{}
		for _, a := range req.Msg.Answers {
			values[a.FieldId] = a.Values
		}
	}
	if err := s.chats.AnswerQuestion(req.Msg.ChatId, req.Msg.ItemId, values); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.AnswerQuestionResponse{}), nil
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
	model.ToolCall:     nushiv1.ItemKind_ITEM_KIND_TOOL_CALL,
	model.Permission:   nushiv1.ItemKind_ITEM_KIND_PERMISSION,
	model.Question:     nushiv1.ItemKind_ITEM_KIND_QUESTION,
}

var fieldTypes = map[model.FieldType]nushiv1.FieldType{
	model.Text:    nushiv1.FieldType_FIELD_TYPE_TEXT,
	model.Choice:  nushiv1.FieldType_FIELD_TYPE_CHOICE,
	model.Choices: nushiv1.FieldType_FIELD_TYPE_CHOICES,
	model.Number:  nushiv1.FieldType_FIELD_TYPE_NUMBER,
	model.Integer: nushiv1.FieldType_FIELD_TYPE_INTEGER,
	model.Boolean: nushiv1.FieldType_FIELD_TYPE_BOOLEAN,
}

func toProto(e model.Event) *nushiv1.EventsResponse {
	out := &nushiv1.EventsResponse{ChatId: e.ChatID}
	switch {
	case e.Item != nil:
		out.Kind = &nushiv1.EventsResponse_Item{Item: &nushiv1.ItemEvent{Item: itemProto(e.Item), Append: e.Append}}
	case e.Status != nil:
		out.Kind = &nushiv1.EventsResponse_Status{Status: &nushiv1.ChatStatus{Busy: e.Status.Busy, Error: e.Status.Error}}
	}
	return out
}

func itemProto(it *model.Item) *nushiv1.Item {
	out := &nushiv1.Item{Id: it.ID, Kind: itemKinds[it.Kind], Text: it.Text,
		Title: it.Title, ToolKind: it.ToolKind, Status: it.Status, Answer: it.Answer}
	out.Options = optionsProto(it.Options)
	for _, f := range it.Fields {
		out.Fields = append(out.Fields, &nushiv1.Field{Id: f.ID, Title: f.Title, Description: f.Description,
			Type: fieldTypes[f.Type], Options: optionsProto(f.Options), Required: f.Required, Values: f.Values})
	}
	return out
}

func optionsProto(opts []model.Option) []*nushiv1.Option {
	var out []*nushiv1.Option
	for _, o := range opts {
		out = append(out, &nushiv1.Option{Id: o.ID, Name: o.Name, Kind: o.Kind, Description: o.Description})
	}
	return out
}
