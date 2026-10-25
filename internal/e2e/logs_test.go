package e2e

import (
	"bytes"
	"context"
	"log/slog"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/memory"
	"github.com/afrase/nushi/internal/features/terminals"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
)

type syncBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuffer) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.Write(p)
}

func (s *syncBuffer) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.String()
}

// TestNothingPrivateLogged runs a chat's turn at DEBUG on the fake agent
// as a real process, every kind of private thing seeded with a marker, and
// looks for the markers in the log (ADR 0038's "never logged").
func TestNothingPrivateLogged(t *testing.T) {
	bin := filepath.Join(t.TempDir(), "fakeagent")
	if out, err := exec.Command("go", "build", "-o", bin, "github.com/afrase/nushi/internal/acptest/fakeagent").CombinedOutput(); err != nil {
		t.Fatalf("building the fake agent: %v\n%s", err, out)
	}
	log := &syncBuffer{}
	defer slog.SetDefault(slog.Default())
	slog.SetDefault(slog.New(logs.Handler(log)))
	logs.SetDebug(true)
	defer logs.SetDebug(false)
	const token = "MARKER-TOKEN-0123456789abcdef"
	logs.Mask(token)
	t.Setenv("NUSHI_TEST_SECRET", "MARKER-ENV-5d1c")

	data, repo := t.TempDir(), t.TempDir()
	check(t, os.WriteFile(filepath.Join(repo, "notes.txt"), []byte("MARKER-FILE-c41a\n"), 0o600))
	if out, err := exec.Command("git", "-C", repo, "init", "-q").CombinedOutput(); err != nil {
		t.Fatalf("git init: %v %s", err, out)
	}
	launch := func(h acp.Handler, log *slog.Logger) (chats.Agent, error) {
		cmd := exec.Command(bin)
		cmd.Env = append(os.Environ(), "FAKE_KEY="+token)
		return acp.Start(cmd, h, log)
	}
	hub, st := &events.Hub{}, store.New(data)
	svc := chats.New([]chats.Kind{{Name: "fake", Launch: launch}}, st, st, git.Worktrees{}, filepath.Join(data, "scratch"), hub.Publish)
	terms := terminals.New(startSh, "sh", svc, hub.Publish)
	svc.UseTerminals(terms)
	srv := httptest.NewServer(api.WithToken("tok", api.New(api.Services{Chats: svc, Agents: agents.New(nil, nil, "", nil), Terms: terms, Hub: hub,
		Memory: memory.New(svc), Log: st})))
	go hub.Subscribe(nil, func() bool { return true }, func(e model.Event) bool { terms.Follow(e); return true })

	ctx := context.Background()
	a := open(t, &daemon{url: srv.URL})
	defer func() { a.quit(); srv.CloseClientConnections(); srv.Close(); terms.CloseAll(); svc.Close() }()
	chatID := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "MARKER-PROMPT-1b2e tool stderr",
		Files: []string{filepath.Join(repo, "notes.txt")}})))
	a.waitFor("the turn to end", func(e *nushiv1.EventsResponse) bool {
		return e.GetItem().GetItem().GetText() == "Ran it."
	})
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "MARKER-ASK-77aa permission"})))
	perm := a.waitFor("the permission", pendingPermission).GetItem().GetItem()
	must(a.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: chatID, ItemId: perm.Id, OptionId: "allow"})))
	must(a.c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo})))
	must(a.c.RenameChat(ctx, connect.NewRequest(&nushiv1.RenameChatRequest{ChatId: chatID, Title: "MARKER-TITLE-3c3c"})))
	term := must(a.c.OpenTerminal(ctx, connect.NewRequest(&nushiv1.OpenTerminalRequest{ChatId: chatID, Cols: 80, Rows: 24}))).Terminal
	must(a.c.WriteTerminal(ctx, connect.NewRequest(&nushiv1.WriteTerminalRequest{TerminalId: term.Id, Data: []byte("echo MARKER-TERM-$((40+2))\n")})))
	a.attach(ctx, term.Id, "MARKER-TERM-42\r\n")
	must(a.c.Log(ctx, connect.NewRequest(&nushiv1.LogRequest{Level: "error", Message: "Bad state: " + strings.Repeat("x", 3000),
		Stack: "#0 main (app.dart:1)", Attrs: map[string]string{"from": "zone"}})))
	must(a.c.SleepChat(ctx, connect.NewRequest(&nushiv1.SleepChatRequest{ChatId: chatID})))
	waitLog(t, log, `msg="agent exited"`)

	got := log.String()
	for _, marker := range []string{"MARKER-PROMPT", "MARKER-ASK", "MARKER-FILE", "MARKER-TITLE", "MARKER-TERM", "MARKER-ENV", "MARKER-TOKEN", "sk-ant-api03-Zr8"} {
		if strings.Contains(got, marker) {
			t.Errorf("%s is in the log:\n%s", marker, got)
		}
	}
	for _, want := range []string{`msg="agent started"`, `msg="turn ended"`, `msg="auth: using the key [redacted] from the environment"`, `source=agent`,
		`msg="acp call" chat=` + chatID, `rpc=session/prompt`, `msg="api call" rpc=SendPrompt`, `msg="terminal opened"`, `msg="chat asleep"`,
		`level=ERROR msg="Bad state: xxx`, `x…" source=app from=zone stack="#0 main (app.dart:1)"`} {
		if !strings.Contains(got, want) {
			t.Errorf("no %s in the log:\n%s", want, got)
		}
	}
}

func waitLog(t *testing.T, log *syncBuffer, want string) {
	t.Helper()
	for range 500 {
		if strings.Contains(log.String(), want) {
			return
		}
		sleep10ms()
	}
	t.Fatalf("no %s in the log:\n%s", want, log)
}

func sleep10ms() { time.Sleep(10 * time.Millisecond) }
