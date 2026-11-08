package chats

import (
	"context"
	"encoding/json"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// fakeServers runs a dev server in each of its folders, and says which
// folders it was asked to stop; its entries' commands are by name, and
// it says for which chats they were asked.
type fakeServers struct {
	mu       sync.Mutex
	in       []string
	stopped  []string
	commands map[string]string
	askedBy  []string
	answers  []string // each ask's id and whether it was allowed
}

func (f *fakeServers) Command(chatID, name string) (string, string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.askedBy = append(f.askedBy, chatID)
	return f.commands[name], "ask" + strconv.Itoa(len(f.askedBy))
}

func (f *fakeServers) Answered(askID string, allowed bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.answers = append(f.answers, askID+" "+strconv.FormatBool(allowed))
}

func (f *fakeServers) Within(dir string) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.ContainsFunc(f.in, func(folder string) bool { return within(folder, dir) })
}

func (f *fakeServers) StopWithin(dir string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.stopped = append(f.stopped, dir)
	f.in = slices.DeleteFunc(f.in, func(folder string) bool { return within(folder, dir) })
}

// A chat without messages that moves out of its worktree leaves it while
// a dev server runs there (ADR 0098), as it does a terminal's.
func TestAMoveKeepsAWorktreeWithAServer(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	w := t.TempDir()
	svc.UseServers(&fakeServers{in: []string{filepath.Join(w, "web")}})
	c.mu.Lock()
	c.record.Worktree = &model.Worktree{Path: w}
	c.mu.Unlock()
	testcheck.NoErr(t, svc.Move(context.Background(), c.id, t.TempDir(), false))
	c.mu.Lock()
	earlier := slices.Clone(c.record.EarlierWorktrees)
	c.mu.Unlock()
	if len(wts.removed) > 0 || len(earlier) != 1 || earlier[0].Path != w {
		t.Errorf("removed %q, earlier %v", wts.removed, earlier)
	}
}

// Deleting a chat with its worktree stops the worktree's servers before
// it goes.
func TestDeleteStopsTheWorktreesServers(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	w := t.TempDir()
	servers := &fakeServers{in: []string{w}}
	svc.UseServers(servers)
	c.mu.Lock()
	c.record.EarlierWorktrees = []model.Worktree{{Path: w}}
	c.mu.Unlock()
	testcheck.NoErr(t, svc.Delete(context.Background(), c.id, DeleteOptions{w: {RemoveWorktree: true}}))
	if !slices.Equal(servers.stopped, []string{w}) || !slices.Equal(wts.removed, []string{w}) {
		t.Errorf("stopped %q, removed %q", servers.stopped, wts.removed)
	}
}

// The card asking to run the agent's preview_start shows the command the
// entry runs, Claude's call by its input and Codex's by the call it names;
// another tool's card asks nothing of the servers (ADR 0100).
func TestAPreviewStartPromptSaysWhatRuns(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	servers := &fakeServers{commands: map[string]string{"web": "/usr/local/bin/npm run dev"}}
	svc.UseServers(servers)
	c.mu.Lock()
	c.addLocked(model.Item{ID: "codex", Kind: model.ToolCall, Title: "mcp.nushi.preview_start", Input: `{"arguments":{"name":"web"}}`})
	c.mu.Unlock()
	asked := func(call acp.ToolCallUpdate) model.Item {
		t.Helper()
		ctx, cancel := context.WithCancel(t.Context())
		go func() {
			_, _ = c.RequestPermission(ctx, &acp.RequestPermissionRequest{SessionID: "s1", ToolCall: call,
				Options: []acp.PermissionOption{{OptionID: "yes", Name: "Yes", Kind: "allow_once"}}})
		}()
		eventually(t, c, func() bool { return len(c.waiting) == 1 })
		c.mu.Lock()
		it := c.items[len(c.items)-1]
		c.mu.Unlock()
		cancel()
		eventually(t, c, func() bool { return len(c.waiting) == 0 })
		return it
	}
	it := asked(acp.ToolCallUpdate{ToolCallID: "claude", Title: "mcp__nushi__preview_start", RawInput: json.RawMessage(`{"name":"web"}`)})
	if it.ServerCommand != "/usr/local/bin/npm run dev" || !strings.Contains(it.Input, "web") {
		t.Errorf("Claude's card: %+v", it)
	}
	if it := asked(acp.ToolCallUpdate{ToolCallID: "codex"}); it.ServerCommand != "/usr/local/bin/npm run dev" {
		t.Errorf("Codex's card: %+v", it)
	}
	if it := asked(acp.ToolCallUpdate{ToolCallID: "x", Title: "mcp__nushi__preview_start", RawInput: json.RawMessage(`{"name":"api"}`)}); it.ServerCommand != "" {
		t.Errorf("a name with no entry: %+v", it)
	}
	if it := asked(acp.ToolCallUpdate{ToolCallID: "y", Title: "Bash", RawInput: json.RawMessage(`{"command":"ls"}`)}); it.ServerCommand != "" || it.Input != "" {
		t.Errorf("another card: %+v", it)
	}
	servers.mu.Lock()
	defer servers.mu.Unlock()
	if !slices.Equal(servers.askedBy, []string{c.id, c.id, c.id}) {
		t.Errorf("asked for %q", servers.askedBy)
	}
}

// Each preview_start ask's answer reaches the servers before the agent
// hears it: allowed by an allow option, else refused or cancelled; and
// the card's name is read with its keys as written (ADR 0100).
func TestAPreviewStartAnswerReachesTheServers(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	servers := &fakeServers{commands: map[string]string{"web": "npm run dev"}}
	svc.UseServers(servers)
	options := []acp.PermissionOption{{OptionID: "yes", Name: "Yes", Kind: "allow_once"}, {OptionID: "no", Name: "No", Kind: "reject_once"}}
	asked := func(input, pick string) model.Item {
		t.Helper()
		ctx, cancel := context.WithCancel(t.Context())
		defer cancel()
		done := make(chan struct{})
		go func() {
			defer close(done)
			_, _ = c.RequestPermission(ctx, &acp.RequestPermissionRequest{SessionID: "s1", Options: options,
				ToolCall: acp.ToolCallUpdate{ToolCallID: "x", Title: "mcp__nushi__preview_start", RawInput: json.RawMessage(input)}})
		}()
		eventually(t, c, func() bool { return len(c.waiting) == 1 })
		c.mu.Lock()
		it := c.items[len(c.items)-1]
		c.mu.Unlock()
		if pick == "" {
			cancel()
		} else {
			testcheck.NoErr(t, svc.AnswerPermission(c.id, it.ID, pick))
		}
		<-done
		return it
	}
	asked(`{"name":"web"}`, "yes")
	asked(`{"name":"web"}`, "no")
	asked(`{"name":"web"}`, "")
	if it := asked(`{"name":"api","NAME":"web"}`, "no"); it.ServerCommand != "" {
		t.Errorf("a name in another case was read: %+v", it)
	}
	servers.mu.Lock()
	defer servers.mu.Unlock()
	if want := []string{"ask1 true", "ask2 false", "ask3 false", "ask4 false"}; !slices.Equal(servers.answers, want) {
		t.Errorf("answers %q, want %q", servers.answers, want)
	}
}

func TestEntryName(t *testing.T) {
	for input, want := range map[string]string{
		`{"name":"web"}`:                   "web",
		`{"arguments":{"name":"web"}}`:     "web",
		`{"name":"web","arguments":null}`:  "web",
		`{"name":"web","arguments":{}}`:    "",
		`{"NAME":"web"}`:                   "",
		`{"name":"api","Name":"web"}`:      "api",
		`{"arguments":{"Name":"web"}}`:     "",
		`{"name":5}`:                       "",
		`not json`:                         "",
		`{"arguments":"web","name":"web"}`: "",
	} {
		if got := entryName(input); got != want {
			t.Errorf("entryName(%s) = %q, want %q", input, got, want)
		}
	}
}
