package claudeacp

import (
	"context"
	"encoding/json"
	"strings"

	acp "github.com/afrase/acp-go/unstable"
)

// GenerateTitleMethod is an extension of this agent's: a short title for a
// piece of text (a message the client pinned, say), made by claude's fast
// model through its generate_session_title control request, asked not to
// keep it. The session's own title, its transcript and a running turn are
// left as they were. It isn't part of ACP.
const GenerateTitleMethod = "_session/generateTitle"

// GenerateTitleRequest is GenerateTitleMethod's params: the open session
// whose claude makes the title, and the text it makes it from.
type GenerateTitleRequest struct {
	SessionID string `json:"sessionId"`
	Text      string `json:"text"`
}

// GenerateTitleResponse is its answer: the title, nil when claude made none.
type GenerateTitleResponse struct {
	Title *string `json:"title"`
}

// generateTitle answers GenerateTitleMethod. Unlike a session's own title
// (title.go) the request has persist false, so claude writes nothing to the
// transcript, and the session's titles state isn't touched.
func (a *agent) generateTitle(ctx context.Context, params json.RawMessage) (*GenerateTitleResponse, error) {
	var req GenerateTitleRequest
	if err := json.Unmarshal(params, &req); err != nil {
		return nil, invalidParams("%s: %v", GenerateTitleMethod, err)
	}
	if strings.TrimSpace(req.Text) == "" {
		return nil, invalidParams("%s: no text", GenerateTitleMethod)
	}
	s, err := a.session(acp.SessionID(req.SessionID))
	if err != nil {
		return nil, err
	}
	ask := struct {
		Description string `json:"description"`
		Persist     bool   `json:"persist"`
	}{req.Text, false}
	var out GenerateTitleResponse
	if err := s.cs.Request(ctx, "generate_session_title", ask, &out); err != nil {
		return nil, err
	}
	if out.Title != nil {
		t := strings.TrimSpace(*out.Title)
		out.Title = &t
	}
	return &out, nil
}
