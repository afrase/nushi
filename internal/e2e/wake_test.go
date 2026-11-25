package e2e

import (
	"context"
	"errors"
	"os"
	"slices"
	"sync"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/api"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// asleepChat is a chat with a turn, put to sleep, in folder, and its
// agent's session.
func asleepChat(t *testing.T, a *app, folder string) (id, session string) {
	t.Helper()
	id = a.start(&nushiv1.StartChatRequest{Folder: folder})
	a.say(id, "one")
	must(a.c.SleepChat(t.Context(), connect.NewRequest(&nushiv1.SleepChatRequest{ChatId: id})))
	got := a.get(id)
	if !got.Status.Asleep {
		t.Fatalf("slept: status %v", got.Status)
	}
	return id, got.Chat.SessionId
}

func wake(ctx context.Context, a *app, id string) error {
	_, err := a.c.WakeChat(ctx, connect.NewRequest(&nushiv1.WakeChatRequest{ChatId: id}))
	return err
}

// WakeChat reopens a sleeping chat's session and sends nothing: the chat
// is busy with no turn while it opens, then awake, its transcript as it
// was; waking it again, awake, does nothing.
func TestWakeChat(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id, session := asleepChat(t, a, t.TempDir())
	before, prompts, loads := transcript(a.get(id).Items), d.history.Prompts(session), len(d.sent.loaded())

	if err := wake(t.Context(), a, id); err != nil {
		t.Fatalf("WakeChat: %v", err)
	}
	a.waitFor("the chat opening", func(e *nushiv1.EventsResponse) bool {
		st := e.GetStatus()
		return e.ChatId == id && st != nil && st.Busy && st.Started == 0 && !st.Asleep
	})
	a.waitFor("the chat open", func(e *nushiv1.EventsResponse) bool { return e.ChatId == id && idle(e) })
	got := a.get(id)
	if st := got.Status; st.Asleep || st.Busy || !st.CanSleep || st.ReopenFailed {
		t.Fatalf("woken: status %v", st)
	}
	if l := d.sent.loaded(); len(l) != loads+1 || string(l[len(l)-1]) != session {
		t.Errorf("session/load asked for %v, want one more of %s", l, session)
	}
	if p := d.history.Prompts(session); len(p) != len(prompts) {
		t.Errorf("prompts %v, want %v", p, prompts)
	}
	if after := transcript(got.Items); after != before {
		t.Errorf("transcript woken:\n%s\nwant:\n%s", after, before)
	}

	if err := wake(t.Context(), a, id); err != nil {
		t.Fatalf("WakeChat awake: %v", err)
	}
	if l := d.sent.loaded(); len(l) != loads+1 {
		t.Errorf("woken twice: %d loads, want %d", len(l), loads+1)
	}
	a.say(id, "two")
	if l := d.sent.loaded(); len(l) != loads+1 {
		t.Errorf("a message after the wake reopened it again: %d loads", len(l))
	}
}

// Two wakes at once open one session.
func TestTwoWakesOpenOneSession(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id, _ := asleepChat(t, a, t.TempDir())
	loads := len(d.sent.loaded())
	var wg sync.WaitGroup
	errs := make([]error, 2)
	for i := range errs {
		wg.Go(func() { errs[i] = wake(t.Context(), a, id) })
	}
	wg.Wait()
	if slices.ContainsFunc(errs, func(err error) bool { return err != nil }) {
		t.Fatalf("WakeChat: %v", errs)
	}
	until(t, "the chat awake", func() bool { st := a.get(id).Status; return !st.Busy && !st.Asleep })
	if l := d.sent.loaded(); len(l) != loads+1 {
		t.Errorf("%d loads, want 1", len(l)-loads)
	}
}

// A wake that fails says so through the chat's status, as a reopen does:
// reopen_failed and its notice, here that the folder is gone.
func TestAFailedWakeSaysSo(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	folder := t.TempDir()
	id, _ := asleepChat(t, a, folder)
	if err := os.RemoveAll(folder); err != nil {
		t.Fatal(err)
	}
	if err := wake(t.Context(), a, id); err != nil {
		t.Fatalf("WakeChat: %v", err)
	}
	a.waitFor("the notice", func(e *nushiv1.EventsResponse) bool {
		return e.ChatId == id && e.GetItem().GetItem().GetStatus() == "folder_gone"
	})
	until(t, "the chat's reopen failed", func() bool {
		st := a.get(id).Status
		return st.ReopenFailed && !st.Busy && !st.Asleep
	})
}

// An archived chat's wake is refused, as its other calls are.
func TestAnArchivedChatDoesntWake(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id, _ := asleepChat(t, a, t.TempDir())
	must(a.c.ArchiveChat(t.Context(), connect.NewRequest(&nushiv1.ArchiveChatRequest{ChatId: id, Archived: true})))
	loads := len(d.sent.loaded())
	if err := wake(t.Context(), a, id); connect.CodeOf(err) != connect.CodeFailedPrecondition {
		t.Fatalf("WakeChat archived: %v", err)
	}
	if l := d.sent.loaded(); len(l) != loads {
		t.Errorf("archived, %d loads", len(l)-loads)
	}
}

// Once the restart is due, a wake is refused as a prompt is (Unavailable,
// its reason restarting) and the chat stays asleep: the app asks the new
// daemon, rather than starting an agent the restart would stop.
func TestAWakeAtTheRestartIsRefused(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id, _ := asleepChat(t, a, t.TempDir())
	loads := len(d.sent.loaded())
	must(a.c.RestartWhenIdle(t.Context(), connect.NewRequest(&nushiv1.RestartWhenIdleRequest{})))
	<-d.restart.Due()
	err := wake(t.Context(), a, id)
	var ce *connect.Error
	if !errors.As(err, &ce) || ce.Code() != connect.CodeUnavailable || ce.Meta().Get(api.ReasonHeader) != api.ReasonRestarting {
		t.Fatalf("a wake after the restart was due: %v, want Unavailable, its reason restarting", err)
	}
	if st := a.get(id).Status; !st.Asleep || st.Busy || len(d.sent.loaded()) != loads {
		t.Errorf("refused, status %v, %d loads (was %d)", st, len(d.sent.loaded()), loads)
	}
}
