package claudeagent

import (
	"context"
	"encoding/json"
	"fmt"
)

// ElicitationRequest is an MCP server asking the user, through claude,
// for input: a form to fill (Mode "form", RequestedSchema) or a page to
// visit (Mode "url", URL). Raw has the whole request.
type ElicitationRequest struct {
	ServerName      string
	Message         string
	Mode            string // "form" or "url"; "" is a form
	URL             string
	ElicitationID   string          // a URL elicitation's, which ElicitationComplete names when done
	RequestedSchema json.RawMessage // a form's fields, as a JSON Schema object
	PropertyOrder   []string        // the order to show the form's fields in, when given
	Title           string
	DisplayName     string
	Description     string
	Raw             json.RawMessage
}

// ElicitationResult is the user's answer to an ElicitationRequest.
type ElicitationResult struct {
	Action  string         // ElicitationAccept, ElicitationDecline or ElicitationCancel
	Content map[string]any // with ElicitationAccept, a form's values by field
}

// An ElicitationResult's actions, as MCP names them.
const (
	ElicitationAccept  = "accept"  // the user answered
	ElicitationDecline = "decline" // the user said no
	ElicitationCancel  = "cancel"  // the user dismissed it without choosing
)

// elicitation asks OnElicitation about an elicitation request and
// returns the answer as claude reads it. Without OnElicitation the answer
// is a decline.
func (s *Session) elicitation(ctx context.Context, raw json.RawMessage) (any, error) {
	if s.o.OnElicitation == nil {
		return map[string]any{"action": ElicitationDecline}, nil
	}
	var w struct {
		ServerName      string          `json:"mcp_server_name"`
		Message         string          `json:"message"`
		Mode            string          `json:"mode"`
		URL             string          `json:"url"`
		ElicitationID   string          `json:"elicitation_id"`
		RequestedSchema json.RawMessage `json:"requested_schema"`
		PropertyOrder   json.RawMessage `json:"property_order"`
		Title           string          `json:"title"`
		DisplayName     string          `json:"display_name"`
		Description     string          `json:"description"`
	}
	if err := json.Unmarshal(raw, &w); err != nil {
		return nil, fmt.Errorf("claudeagent: an elicitation request that doesn't decode: %w", err)
	}
	r := ElicitationRequest{
		ServerName: w.ServerName, Message: w.Message, Mode: w.Mode, URL: w.URL, ElicitationID: w.ElicitationID,
		RequestedSchema: w.RequestedSchema, Title: w.Title, DisplayName: w.DisplayName, Description: w.Description, Raw: raw,
	}
	_ = json.Unmarshal(w.PropertyOrder, &r.PropertyOrder) // a hint: one of another shape is passed over
	result, err := s.o.OnElicitation(ctx, r)
	if err != nil {
		return nil, err
	}
	return elicitationAnswer(result)
}

// elicitationAnswer is result as claude reads it: the action, and a
// form's values only with an accept.
func elicitationAnswer(result ElicitationResult) (map[string]any, error) {
	switch result.Action {
	case ElicitationAccept:
		a := map[string]any{"action": result.Action}
		if result.Content != nil {
			a["content"] = result.Content
		}
		return a, nil
	case ElicitationDecline, ElicitationCancel:
		return map[string]any{"action": result.Action}, nil
	}
	return nil, fmt.Errorf("claudeagent: OnElicitation answered %q, not accept, decline or cancel", result.Action)
}
