package tools

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// echoSet has one tool, for chats on an issue.
type echoSet struct{}

func (echoSet) Tools(g Grant) []Tool {
	if g.Issue == nil {
		return nil
	}
	return []Tool{{Name: "echo", InputSchema: json.RawMessage(`{"type":"object"}`)}}
}

func (echoSet) Call(_ context.Context, g Grant, _ string, args json.RawMessage) (string, error) {
	if string(args) == `"fail"` {
		return "", errors.New("it failed")
	}
	return g.Chat + " " + g.Issue.Key + " " + string(args), nil
}

func TestKeys(t *testing.T) {
	s := New(echoSet{})
	plain := Grant{Chat: "c0", Agent: "claude"}
	if s.HasTools(plain) {
		t.Error("a chat without an issue has tools")
	}
	g := Grant{Chat: "c1", Agent: "claude", Issue: &model.ChatIssue{Site: "acme.atlassian.net", Key: "ACME-12"}}
	key := s.Key(g)
	if again := s.Key(g); again != key {
		t.Error("a chat got a second key")
	}
	other := s.Key(Grant{Chat: "c2", Issue: &model.ChatIssue{Key: "ACME-9"}})
	if other == key {
		t.Error("two chats share a key")
	}
	if list, err := s.List(key); err != nil || len(list) != 1 || list[0].Name != "echo" {
		t.Errorf("list %v, %v", list, err)
	}
	if text, err := s.Call(t.Context(), key, "echo", json.RawMessage(`"hi"`)); err != nil || text != `c1 ACME-12 "hi"` {
		t.Errorf("call %q, %v", text, err)
	}
	if text, _ := s.Call(t.Context(), other, "echo", nil); text != "c2 ACME-9 " {
		t.Errorf("the other chat's call ran as %q", text)
	}
	if _, err := s.Call(t.Context(), key, "echo", json.RawMessage(`"fail"`)); err == nil {
		t.Error("a failing tool")
	}
	if _, err := s.Call(t.Context(), key, "rm", nil); err == nil {
		t.Error("a tool no set has")
	}
	for _, bad := range []string{"", "x", key + "x"} {
		if _, err := s.List(bad); !errors.Is(err, ErrKey) {
			t.Errorf("key %q: %v", bad, err)
		}
		if _, err := s.Call(t.Context(), bad, "echo", nil); !errors.Is(err, ErrKey) {
			t.Errorf("key %q: %v", bad, err)
		}
	}
}
