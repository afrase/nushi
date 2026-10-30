package claudeacp

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
	"github.com/afrase/nushi/claudeagent/sessions"
)

// load asks to load session sid in cwd.
func (p *peer) load(sid, cwd string) (*acp.LoadSessionResponse, error) {
	return p.LoadSession(context.Background(), &acp.LoadSessionRequest{SessionID: acp.SessionID(sid), Cwd: cwd, MCPServers: []acp.MCPServer{}})
}

// session/load resumes claude on the session and replays its history as
// claude-agent-acp does: the user's messages under claude's uuids, the
// model's under the API's ids, each call with its whole input then its
// result; markers claude adds taken out, a command as typed, hidden
// commands and claude's sign-in message left out, no usage. The commands
// come after.
func TestLoadReplaysHistory(t *testing.T) {
	f := fake()
	p := start(t, nil, f)
	cwd, sid := t.TempDir(), nthUUID(1)
	p.writeHistory(t, cwd, sid,
		userRec("u1", "Fix the bug"),
		asstRec("a1", "msg_1", map[string]any{"type": "thinking", "thinking": "Looking"}),
		asstRec("a2", "msg_1", textBlock("I'll read it.")),
		asstRec("a3", "msg_1", useBlock("toolu_1", "Bash", `{"command":"cat x.go"}`)),
		userRec("u2", resultBlocks("toolu_1", "package x", false), "toolUseResult", map[string]any{"stdout": "package x"}),
		asstRec("a4", "msg_2", textBlock("Fixed.")),
		userRec("caveat", "Caveat: the messages below…", "isMeta", true),
		userRec("u3", "<command-name>/context</command-name><command-message>context</command-message><command-args></command-args>"),
		userRec("u4", "<local-command-stdout>## Context Usage</local-command-stdout>"),
		userRec("u5", "<command-message>review</command-message>\n<command-name>/review</command-name>\n<command-args>main</command-args>"),
		userRec("u6", []any{textBlock("<system-reminder>Branch renamed.</system-reminder>\nGo on"), textBlock("[Request interrupted by user]")}),
		rec{"type": "assistant", "uuid": "a5", "message": map[string]any{"id": "msg_3", "role": "assistant", "model": "<synthetic>",
			"content": []any{textBlock("Not logged in · Please run /login")}}},
	)
	r, err := p.load(sid, cwd)
	if err != nil {
		t.Fatal(err)
	}
	if r.Modes == nil || len(r.ConfigOptions) == 0 {
		t.Errorf("%+v", r)
	}
	want := []string{
		sid + " user u1 Fix the bug",
		sid + " thought msg_1 Looking",
		sid + " text msg_1 I'll read it.",
		sid + " call toolu_1 cat x.go pending",
		sid + " update toolu_1 completed",
		sid + " text msg_2 Fixed.",
		sid + " user u5 /review main",
		sid + " user u6 Go on",
		sid + " user u6 [Request interrupted by user]",
		sid + " commands",
	}
	if got := p.replayed(); !slices.Equal(got, want) {
		t.Errorf("got:\n%s\nwant:\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
	<-f.Played()
	if args := f.Spec().Args; !slices.Contains(args, "--resume="+sid) || slices.ContainsFunc(args, func(a string) bool { return strings.HasPrefix(a, "--session-id") }) {
		t.Errorf("args %q", args)
	}
}

// Two loads of a session at once run one claude: the second finds the
// session the first opened.
func TestLoadTwiceAtOnce(t *testing.T) {
	p := start(t, nil, fake()) // one claude: a second start would fail
	cwd, sid := t.TempDir(), nthUUID(1)
	p.writeHistory(t, cwd, sid, userRec("u1", "hello"))
	errs := make(chan error, 2)
	for range 2 {
		go func() {
			_, err := p.load(sid, cwd)
			errs <- err
		}()
	}
	for range 2 {
		if err := <-errs; err != nil {
			t.Error(err)
		}
	}
	// Once both are done the session's lock is forgotten.
	p.agent.mu.Lock()
	defer p.agent.mu.Unlock()
	if n := len(p.agent.reopening); n != 0 {
		t.Errorf("%d reopening locks kept", n)
	}
}

// A session claude has no transcript of is resourceNotFound, naming it.
func TestLoadMissing(t *testing.T) {
	p := start(t, nil)
	cwd := t.TempDir()
	for _, sid := range []string{nthUUID(1), "../../etc"} {
		_, err := p.load(sid, cwd)
		var e *acp.Error
		if !errors.As(err, &e) || e.Code != acp.ErrorCodeResourceNotFound || string(e.Data) != `{"uri":"`+sid+`"}` {
			t.Errorf("%s: %v", sid, err)
		}
	}
	if _, err := p.ResumeSession(context.Background(), &acp.ResumeSessionRequest{SessionID: acp.SessionID(nthUUID(3)), Cwd: cwd}); err == nil {
		t.Error("resumed a session claude doesn't have")
	}
	if len(p.notes()) != 0 {
		t.Errorf("sent %q", p.replayed())
	}
}

// A transcript claude has but that can't be read is an internal error,
// not resourceNotFound: the session isn't gone, so a client keeps it.
func TestLoadUnreadable(t *testing.T) {
	p := start(t, nil)
	cwd, sid := t.TempDir(), nthUUID(1)
	p.writeHistory(t, cwd, sid, userRec("u1", "Fix the bug"))
	path := filepath.Join(sessions.Store{ConfigDir: p.agent.cfg.ConfigDir}.ProjectDir(cwd), sid+".jsonl")
	if err := os.Chmod(path, 0); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(path, 0o600) })
	if f, err := os.Open(path); err == nil { // root reads it anyway
		_ = f.Close()
		t.Skip("the transcript is readable")
	}
	_, err := p.load(sid, cwd)
	var e *acp.Error
	if !errors.As(err, &e) || e.Code != acp.ErrorCodeInternalError || !strings.Contains(e.Message, "history") {
		t.Errorf("%v", err)
	}
}

// A claude that quits on a resume before it answers leaves the session
// not found only when its transcript has gone meanwhile; else it is an
// internal error with what claude said, and the client keeps the session.
func TestResumeClaudeQuits(t *testing.T) {
	for _, tc := range []struct {
		name string
		gone bool // the transcript is removed while claude starts
		want acp.ErrorCode
	}{
		{"transcript there", false, acp.ErrorCodeInternalError},
		{"transcript gone", true, acp.ErrorCodeResourceNotFound},
	} {
		t.Run(tc.name, func(t *testing.T) {
			cwd, sid := t.TempDir(), nthUUID(1)
			var path string
			quits := claudetest.New(claudetest.Expect(initRequest),
				claudetest.Do(func() {
					if tc.gone {
						_ = os.Remove(path)
					}
				}),
				claudetest.Exit(1, "Error: settings.json: unexpected token\n"))
			p := start(t, nil, quits)
			p.writeHistory(t, cwd, sid, userRec("u1", "hello"))
			path = filepath.Join(sessions.Store{ConfigDir: p.agent.cfg.ConfigDir}.ProjectDir(cwd), sid+".jsonl")
			_, err := p.ResumeSession(context.Background(), &acp.ResumeSessionRequest{SessionID: acp.SessionID(sid), Cwd: cwd})
			var e *acp.Error
			if !errors.As(err, &e) || e.Code != tc.want {
				t.Fatalf("%v", err)
			}
			if !tc.gone && !strings.Contains(e.Message, "settings.json: unexpected token") {
				t.Errorf("claude's stderr isn't in %q", e.Message)
			}
		})
	}
}

// session/resume resumes claude without the history; a session open
// already is answered as it is, by the same claude, and a load of it
// replays its history again.
func TestResume(t *testing.T) {
	f := fake()
	p := start(t, nil, f) // one claude: a second start would fail
	cwd, sid := t.TempDir(), nthUUID(1)
	p.writeHistory(t, cwd, sid, userRec("u1", "hello"), asstRec("a1", "msg_1", textBlock("hi")))
	for range 2 {
		r, err := p.ResumeSession(context.Background(), &acp.ResumeSessionRequest{SessionID: acp.SessionID(sid), Cwd: cwd})
		if err != nil || r.Modes == nil {
			t.Fatalf("%+v %v", r, err)
		}
	}
	if _, err := p.load(sid, cwd); err != nil {
		t.Fatal(err)
	}
	want := []string{sid + " commands", sid + " commands", sid + " user u1 hello", sid + " text msg_1 hi", sid + " commands"}
	if got := p.replayed(); !slices.Equal(got, want) {
		t.Errorf("got:\n%s\nwant:\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}
