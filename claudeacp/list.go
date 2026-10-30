package claudeacp

import (
	"context"
	"fmt"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/sessions"
)

// listPage is how many sessions a page of session/list has, as
// claude-agent-acp's; its cursor is "offset:N".
const listPage = 1000

// maxTitle is the most characters of a listed session's title.
const maxTitle = 256

func (a *agent) ListSessions(_ context.Context, req *acp.ListSessionsRequest) (*acp.ListSessionsResponse, error) {
	if req.Cwd != "" && !filepath.IsAbs(req.Cwd) {
		return nil, invalidParams("cwd %q isn't an absolute path", req.Cwd)
	}
	offset := 0
	if req.Cursor != "" {
		n, err := strconv.Atoi(strings.TrimPrefix(req.Cursor, "offset:"))
		if !strings.HasPrefix(req.Cursor, "offset:") || err != nil || n < 0 {
			return nil, invalidParams("no cursor %q", req.Cursor)
		}
		offset = n
	}
	infos, err := sessions.Store{ConfigDir: a.cfg.ConfigDir}.List(req.Cwd, listPage+1, offset)
	if err != nil {
		return nil, &acp.Error{Code: acp.ErrorCodeInternalError, Message: fmt.Sprintf("Listing sessions: %v", err)}
	}
	resp := &acp.ListSessionsResponse{Sessions: []acp.SessionInfo{}}
	if len(infos) > listPage {
		infos = infos[:listPage]
		resp.NextCursor = "offset:" + strconv.Itoa(offset+listPage)
	}
	for _, in := range infos {
		if in.Cwd == "" {
			continue
		}
		resp.Sessions = append(resp.Sessions, acp.SessionInfo{SessionID: acp.SessionID(in.ID), Cwd: in.Cwd,
			Title: listTitle(in.Summary), UpdatedAt: in.LastModified.UTC().Format(time.RFC3339)})
	}
	return resp, nil
}

// listTitle is a session's summary on one line, cut to maxTitle
// characters.
func listTitle(s string) string {
	s = strings.Join(strings.Fields(s), " ")
	if utf8.RuneCountInString(s) <= maxTitle {
		return s
	}
	return string([]rune(s)[:maxTitle-1]) + "…"
}

// DeleteSession deletes a session's transcripts for good. An open one is
// closed first, and claude has exited before its files go, since claude
// writes to its transcript as it ends. One claude has no transcript of
// is deleted already.
//
//nolint:contextcheck // closing runs to its end: the request's ctx doesn't bound it
func (a *agent) DeleteSession(_ context.Context, req *acp.DeleteSessionRequest) (*acp.DeleteSessionResponse, error) {
	if s, err := a.session(req.SessionID); err == nil {
		s.close()
	}
	store := sessions.Store{ConfigDir: a.cfg.ConfigDir}
	if err := store.Delete(string(req.SessionID), ""); err != nil {
		return nil, &acp.Error{Code: acp.ErrorCodeInternalError, Message: fmt.Sprintf("Deleting the session: %v", err)}
	}
	return &acp.DeleteSessionResponse{}, nil
}
