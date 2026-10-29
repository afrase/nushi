package claudeacp

import (
	"cmp"
	"context"
	"encoding/json"
	"fmt"
	"slices"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// elicit passes an MCP server's request for the user's input on to the
// client: a form, or a page to visit (an MCP server's sign-in). A client
// that can't show it declines it, as claude does with no one to ask; a
// request withdrawn is cancelled.
func (s *session) elicit(ctx context.Context, r claudeagent.ElicitationRequest) (claudeagent.ElicitationResult, error) {
	decline := claudeagent.ElicitationResult{Action: claudeagent.ElicitationDecline}
	caps := s.a.clientCaps()
	req := &acp.CreateElicitationRequest{Message: r.Message}
	switch r.Mode {
	case "url":
		if !caps.urls {
			return decline, nil
		}
		req.URL = &acp.ElicitationURLMode{SessionID: acp.SessionID(s.id), URL: r.URL,
			ElicitationID: acp.ElicitationID(cmp.Or(r.ElicitationID, s.a.newID()))}
	default:
		if !caps.forms {
			return decline, nil
		}
		schema, err := formSchema(r)
		if err != nil {
			s.log.Info("an MCP server's form the client can't be sent", "server", r.ServerName, "err", err)
			return decline, nil
		}
		req.Form = &acp.ElicitationFormMode{SessionID: acp.SessionID(s.id), RequestedSchema: schema}
	}
	ctx, done := s.opened(ctx)
	defer done()
	resp, err := s.a.client.CreateElicitation(ctx, req)
	switch {
	case err != nil && ctx.Err() == nil:
		s.log.Info("asking for an MCP server", "server", r.ServerName, "err", err)
		return decline, nil
	case err != nil:
	case resp.Accept != nil:
		var content map[string]any
		b, err := json.Marshal(resp.Accept.Content)
		if err == nil {
			err = json.Unmarshal(b, &content)
		}
		if err != nil {
			return decline, nil
		}
		return claudeagent.ElicitationResult{Action: claudeagent.ElicitationAccept, Content: content}, nil
	case resp.Decline:
		return decline, nil
	}
	return claudeagent.ElicitationResult{Action: claudeagent.ElicitationCancel}, nil
}

// formSchema is a form's schema as ACP's: always an object, its fields in
// the order the server asked for, if it did.
func formSchema(r claudeagent.ElicitationRequest) (acp.ElicitationSchema, error) {
	var schema acp.ElicitationSchema
	if err := json.Unmarshal(r.RequestedSchema, &schema); err != nil {
		return schema, fmt.Errorf("its schema: %w", err)
	}
	schema.Type = acp.ElicitationSchemaTypeObject
	if len(r.PropertyOrder) > 0 {
		rank := func(p acp.ElicitationProperty) int {
			if i := slices.Index(r.PropertyOrder, p.Name); i >= 0 {
				return i
			}
			return len(r.PropertyOrder)
		}
		slices.SortStableFunc(schema.Properties, func(a, b acp.ElicitationProperty) int { return rank(a) - rank(b) })
	}
	return schema, nil
}

// elicitationDone tells a client that shows URL elicitations that one
// has finished.
func (s *session) elicitationDone(m *claudeagent.ElicitationComplete) {
	if s.a.clientCaps().urls && m.ElicitationID != "" {
		_ = s.a.client.CompleteElicitation(s.a.ctx, &acp.CompleteElicitationNotification{ElicitationID: acp.ElicitationID(m.ElicitationID)})
	}
}
