package e2e

import (
	"context"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/claude-acp-go/claudeagent/sessions"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/claudehistory"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// claudeSearch is Claude's harness with the search of its transcripts in
// the test daemon's own Claude config folder, and nothing else of
// claudehistory.Local, whose other readers look at this machine's
// processes.
type claudeSearch struct {
	claude.Harness
	projects string
}

func (c claudeSearch) SearchSessions(ctx context.Context, s model.SessionSearch) ([]model.SessionHit, bool, error) {
	return claudehistory.Local{Projects: c.projects}.SearchSessions(ctx, s)
}

// A Claude session started in a terminal is found by what was said in it,
// in its folder and in every folder's; a chat's own session isn't. Opened,
// it's a chat, and no longer found. An agent whose transcripts Nushi
// doesn't read says so.
func TestSearchSessionsStartedElsewhere(t *testing.T) {
	ctx := context.Background()
	data := t.TempDir()
	d := startDaemon(t, data, &acptest.History{})
	a := open(t, d)
	dir, _ := filepath.EvalSymlinks(t.TempDir())
	ours := a.get(a.start(&nushiv1.StartChatRequest{Agent: "claude", Folder: dir})).Chat.SessionId
	history := sessions.Store{ConfigDir: filepath.Join(data, "claude")}.ProjectDir(dir)
	const theirs = "5b0c3f1e-0000-4000-8000-000000000001"
	record := func(typ, content string) string {
		return `{"type":"` + typ + `","cwd":"` + dir + `","sessionId":"` + theirs + `","uuid":"u","timestamp":"2026-11-01T10:00:00.000Z","message":{"role":"` + typ + `","content":` + content + "}}\n"
	}
	testcheck.Write(t, filepath.Join(history, theirs+".jsonl"), record("user", `"Why is the flaky test flaky?"`)+
		record("assistant", `[{"type":"thinking","thinking":"a flaky test"},{"type":"text","text":"Its clock races."}]`))
	testcheck.Write(t, filepath.Join(history, ours+".jsonl"), record("user", `"A chat's own flaky test."`))

	search := func(agent, folder string) *nushiv1.SearchAgentSessionsResponse {
		return must(a.c.SearchAgentSessions(ctx, connect.NewRequest(&nushiv1.SearchAgentSessionsRequest{Agent: agent, Folder: folder, Text: "FLAKY  test"})))
	}
	for _, folder := range []string{dir, ""} {
		found := search("claude", folder)
		if !found.CanSearch || found.More || found.SeesOpen || found.OneWriter || len(found.Hits) != 1 {
			t.Fatalf("in %q: %v", folder, found)
		}
		h := found.Hits[0]
		if s := h.Session; s.SessionId != theirs || s.Title != "Why is the flaky test flaky?" || s.Folder != dir || s.UpdatedUnixMs == 0 ||
			h.Before != "Why is the " || h.Match != "flaky test" || h.After != " flaky?" || h.Count != 1 {
			t.Errorf("in %q: found %v", folder, h)
		}
	}
	if found := search("codex", ""); found.CanSearch || len(found.Hits) != 0 {
		t.Errorf("codex: %v, want no search (its files aren't read here)", found)
	}

	h := search("claude", dir).Hits[0].Session
	id := must(a.c.OpenAgentSession(ctx, connect.NewRequest(&nushiv1.OpenAgentSessionRequest{Agent: "claude", Folder: dir, SessionId: h.SessionId, Title: h.Title}))).ChatId
	if c := a.get(id).Chat; c.SessionId != theirs || !strings.Contains(c.Title, "flaky") {
		t.Errorf("opened %v", c)
	}
	if found := search("claude", dir); len(found.Hits) != 0 {
		t.Errorf("found a chat's: %v", found.Hits)
	}
}
