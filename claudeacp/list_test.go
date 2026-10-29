package claudeacp

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/sessions"
)

// session/list lists claude's sessions of a folder, newest first, a
// thousand a page, the cursor saying how many came before; each with its
// folder, its title on one line and when it was last written.
func TestListSessions(t *testing.T) {
	p := start(t, nil)
	cwd := t.TempDir()
	base := time.Date(2026, 10, 1, 12, 0, 0, 0, time.UTC)
	const n = listPage + 1
	for i := range n {
		sid := uuid(i + 1)
		p.writeHistory(t, cwd, sid, userRec(uuid(1000+i), "Fix  the\nlogin page "+sid[len(sid)-4:], "cwd", cwd))
		at := base.Add(time.Duration(i) * time.Minute)
		if err := os.Chtimes(filepath.Join(sessions.ProjectDir(p.agent.cfg.ConfigDir, cwd), sid+".jsonl"), at, at); err != nil {
			t.Fatal(err)
		}
	}
	list := func(cursor string) *acp.ListSessionsResponse {
		t.Helper()
		r, err := p.ListSessions(context.Background(), &acp.ListSessionsRequest{Cwd: cwd, Cursor: cursor})
		if err != nil {
			t.Fatal(err)
		}
		return r
	}
	first := list("")
	newest := first.Sessions[0]
	if len(first.Sessions) != listPage || first.NextCursor != "offset:1000" || newest.SessionID != acp.SessionID(uuid(n)) ||
		newest.Title != "Fix the login page 1001" || newest.UpdatedAt != "2026-10-02T04:40:00Z" {
		t.Errorf("%d sessions, cursor %q, newest %+v", len(first.Sessions), first.NextCursor, newest)
	}
	if resolved, _ := filepath.EvalSymlinks(cwd); newest.Cwd != cwd && newest.Cwd != resolved {
		t.Errorf("cwd %q", newest.Cwd)
	}
	if last := list(first.NextCursor); len(last.Sessions) != 1 || last.NextCursor != "" || last.Sessions[0].SessionID != acp.SessionID(uuid(1)) {
		t.Errorf("%+v", last)
	}
	for _, req := range []acp.ListSessionsRequest{{Cwd: cwd, Cursor: "1000"}, {Cwd: cwd, Cursor: "offset:-1"}, {Cwd: "relative"}} {
		_, err := p.ListSessions(context.Background(), &req)
		var e *acp.Error
		if !errors.As(err, &e) || e.Code != acp.ErrorCodeInvalidParams {
			t.Errorf("%+v: %v", req, err)
		}
	}
}

// session/delete closes an open session and waits for claude to exit
// before its transcript and folder go, as claude writes to them as it
// ends. One claude has no transcript of is deleted already.
func TestDeleteSession(t *testing.T) {
	f := fake()
	p := start(t, nil, f)
	cwd, sid := t.TempDir(), uuid(1)
	p.writeHistory(t, cwd, sid, userRec(uuid(2), "hello"))
	p.writeSubagent(t, cwd, sid, "agentA", "toolu_A", asstRec(uuid(3), "msg_1", textBlock("hi")))
	if _, err := p.load(sid, cwd); err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{sid, sid, uuid(9)} {
		if _, err := p.DeleteSession(context.Background(), &acp.DeleteSessionRequest{SessionID: acp.SessionID(id)}); err != nil {
			t.Fatal(err)
		}
		select {
		case <-f.Exited():
		default:
			t.Fatal("deleted while claude ran")
		}
	}
	project := sessions.ProjectDir(p.agent.cfg.ConfigDir, cwd)
	entries, err := os.ReadDir(project)
	if err != nil || len(entries) != 0 {
		t.Errorf("left %v %v", entries, err)
	}
	if _, err := p.Prompt(context.Background(), &acp.PromptRequest{SessionID: acp.SessionID(sid)}); err == nil ||
		!strings.Contains(err.Error(), "no open session") {
		t.Errorf("prompted a deleted session: %v", err)
	}
	if got := p.replayed(); !slices.Contains(got, sid+" commands") {
		t.Errorf("%q", got)
	}
}
