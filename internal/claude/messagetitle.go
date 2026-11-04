package claude

import (
	"context"

	"github.com/afrase/nushi/claudeacp"
)

// MessageTitle asks Claude's Go agent, through call, for a short title for
// text, made by claude's fast model (claudeacp.GenerateTitleMethod): a
// pinned message's (ADR 0085). The session's own title and transcript are
// left as they were. "" when claude made none; the Node adapter hasn't the
// method, an error.
func (Harness) MessageTitle(ctx context.Context, call func(ctx context.Context, method string, params, result any) error, sessionID, text string) (string, error) {
	var r claudeacp.GenerateTitleResponse
	if err := call(ctx, claudeacp.GenerateTitleMethod, claudeacp.GenerateTitleRequest{SessionID: sessionID, Text: text}, &r); err != nil {
		return "", err
	}
	if r.Title == nil {
		return "", nil
	}
	return *r.Title, nil
}
