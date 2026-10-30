package claudeacp

import (
	"context"
	"encoding/json"
	"errors"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/sessions"
)

// conversation is a session of two turns, the first making a call.
func conversation() []rec {
	return []rec{
		userRec(uuid(101), "first"),
		asstRec(uuid(102), "msg_1", textBlock("one")),
		asstRec(uuid(103), "msg_1", useBlock("toolu_1", "Bash", `{"command":"ls"}`)),
		userRec(uuid(104), resultBlocks("toolu_1", "x.go", false)),
		asstRec(uuid(105), "msg_2", textBlock("two")),
		userRec(uuid(106), "second"),
		asstRec(uuid(107), "msg_3", textBlock("three")),
	}
}

// forkAtMeta is the _meta that cuts a fork after messageID.
func forkAtMeta(messageID string) map[string]any {
	return map[string]any{"jetbrains": map[string]any{"air": map[string]any{"fork": map[string]any{"version": 1, "messageId": messageID}}}}
}

// texts is a session's conversation in short, as claude has it now.
func historyTexts(t *testing.T, config, sid, cwd string) []string {
	t.Helper()
	ms, err := sessions.Store{ConfigDir: config}.Messages(sid, cwd)
	if err != nil {
		t.Fatal(err)
	}
	var out []string
	for _, m := range ms {
		var msg struct {
			Content json.RawMessage `json:"content"`
		}
		_ = json.Unmarshal(m.Message, &msg)
		var s string
		if json.Unmarshal(msg.Content, &s) != nil {
			var blocks []struct{ Type, Text string }
			_ = json.Unmarshal(msg.Content, &blocks)
			s = blocks[0].Type
			if blocks[0].Text != "" {
				s = blocks[0].Text
			}
		}
		out = append(out, m.Type+":"+s)
	}
	return out
}

// session/fork copies the conversation into a new session in the
// request's folder (from any folder's history: a client moving a session
// needs no copy first) and resumes claude on it; with
// _meta.jetbrains.air.fork it is cut after the message named, by its API
// id or a user message's uuid, the whole message kept. The commands come
// after the answer.
func TestFork(t *testing.T) {
	all := []string{"user:first", "assistant:one", "assistant:tool_use", "user:tool_result", "assistant:two", "user:second", "assistant:three"}
	for _, tc := range []struct {
		name, at string
		want     []string
	}{
		{"whole", "", all},
		{"at an agent message", "msg_1", all[:3]},
		{"at a message's segment", "msg_2:segment:1", all[:5]},
		{"at a user message", uuid(106), all[:6]},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := fake()
			p := start(t, nil, f)
			from, to, sid := t.TempDir(), t.TempDir(), uuid(1)
			p.writeHistory(t, from, sid, conversation()...)
			req := &acp.ForkSessionRequest{SessionID: acp.SessionID(sid), Cwd: to}
			if tc.at != "" {
				req.Meta = forkAtMeta(tc.at)
			}
			r, err := p.ForkSession(context.Background(), req)
			if err != nil {
				t.Fatal(err)
			}
			fork := string(r.SessionID)
			if fork == sid || r.Modes == nil {
				t.Errorf("%+v", r)
			}
			if got := historyTexts(t, p.agent.cfg.ConfigDir, fork, to); !slices.Equal(got, tc.want) {
				t.Errorf("fork has %q, want %q", got, tc.want)
			}
			if got := historyTexts(t, p.agent.cfg.ConfigDir, sid, from); !slices.Equal(got, all) {
				t.Errorf("the session has %q", got)
			}
			<-f.Played()
			if sp := f.Spec(); sp.Dir != to || !slices.Contains(sp.Args, "--resume="+fork) {
				t.Errorf("%+v", sp)
			}
			eventually(t, "the commands", func() bool { return slices.Equal(p.replayed(), []string{fork + " commands"}) })
		})
	}
}

// A fork of a session claude has no transcript of is resourceNotFound,
// and one at a message it doesn't have is invalidParams; neither starts
// claude.
func TestForkFails(t *testing.T) {
	p := start(t, nil)
	cwd, sid := t.TempDir(), uuid(1)
	p.writeHistory(t, cwd, sid, conversation()...)
	for _, tc := range []struct {
		sid, at string
		code    acp.ErrorCode
	}{
		{uuid(2), "", acp.ErrorCodeResourceNotFound},
		{sid, "msg_nothing", acp.ErrorCodeInvalidParams},
	} {
		req := &acp.ForkSessionRequest{SessionID: acp.SessionID(tc.sid), Cwd: cwd}
		if tc.at != "" {
			req.Meta = forkAtMeta(tc.at)
		}
		_, err := p.ForkSession(context.Background(), req)
		var e *acp.Error
		if !errors.As(err, &e) || e.Code != tc.code {
			t.Errorf("%s at %q: %v", tc.sid, tc.at, err)
		}
	}
	ms, _ := sessions.Store{ConfigDir: p.agent.cfg.ConfigDir}.List(cwd, 0, 0)
	if len(ms) != 1 {
		t.Errorf("sessions %+v", ms)
	}
}

func TestListTitle(t *testing.T) {
	long := strings.Repeat("é", 300)
	for _, tc := range []struct{ in, want string }{
		{"Fix  the\nlogin page ", "Fix the login page"},
		{long, strings.Repeat("é", 255) + "…"},
		{strings.Repeat("a", 256), strings.Repeat("a", 256)},
	} {
		if got := listTitle(tc.in); got != tc.want {
			t.Errorf("listTitle(%.20q) = %.20q…", tc.in, got)
		}
	}
}
