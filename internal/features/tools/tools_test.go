package tools

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
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

func (echoSet) Instructions(g Grant) string {
	if g.Issue == nil {
		return ""
	}
	return "Echoes for " + g.Issue.Key + "."
}

// quietError is a failure whose text the log mustn't have.
type quietError struct{}

func (quietError) Error() string  { return "the server said: secret words" }
func (quietError) Logged() string { return "the server failed" }

func (echoSet) Call(_ context.Context, g Grant, _ string, args json.RawMessage) (string, error) {
	switch string(args) {
	case `"fail"`:
		return "", errors.New("it failed")
	case `"quiet"`:
		return "", fmt.Errorf("starting: %w", quietError{})
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
	if list, text, err := s.List(key); err != nil || len(list) != 1 || list[0].Name != "echo" || text != "Echoes for ACME-12." {
		t.Errorf("list %v, %q, %v", list, text, err)
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
		if _, _, err := s.List(bad); !errors.Is(err, ErrKey) {
			t.Errorf("key %q: %v", bad, err)
		}
		if _, err := s.Call(t.Context(), bad, "echo", nil); !errors.Is(err, ErrKey) {
			t.Errorf("key %q: %v", bad, err)
		}
	}
}

// A failure that says it's Logged reaches the agent whole and the log as
// what Logged says.
func TestALoggedFailure(t *testing.T) {
	var log bytes.Buffer
	was := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&log, nil)))
	t.Cleanup(func() { slog.SetDefault(was) })
	s := New(echoSet{})
	key := s.Key(Grant{Chat: "c", Issue: &model.ChatIssue{Key: "ACME-1"}})
	if _, err := s.Call(t.Context(), key, "echo", json.RawMessage(`"quiet"`)); err == nil || !strings.Contains(err.Error(), "secret words") {
		t.Errorf("the agent got %v", err)
	}
	if l := log.String(); strings.Contains(l, "secret") || !strings.Contains(l, `err="the server failed"`) {
		t.Errorf("the log:\n%s", l)
	}
}
