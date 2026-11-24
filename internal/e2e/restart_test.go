package e2e

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/api"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// due says whether the daemon's restart has come, once its loop has had
// its chance: it looked twice from now (the second look began after this
// call), or stopped as its ask lapsed. A test that waits for the restart
// receives from Due, with no deadline of its own (a restart that never
// comes ends in go test's).
func (d *daemon) due(t *testing.T) bool {
	t.Helper()
	isDue := func() bool {
		select {
		case <-d.restart.Due():
			return true
		default:
			return false
		}
	}
	from := d.looks.Load()
	until(t, "the restart to look again", func() bool { return isDue() || d.lapsed.Load() || d.looks.Load() >= from+2 })
	return isDue()
}

// A restart asked while a turn waits on the user comes once the turn has
// ended; prompts are then refused as Unavailable, which the app sends
// again to the new daemon.
func TestRestartWaitsForTheTurn(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.send(id, "ask permission")
	perm := a.waitFor("the permission prompt", pendingPermission).GetItem().Item

	// It says what it waits for (API 85), for the app's bar.
	holds := must(a.c.RestartWhenIdle(ctx, connect.NewRequest(&nushiv1.RestartWhenIdleRequest{}))).Holds
	if len(holds) != 1 || holds[0].ChatId != id || holds[0].Why != "needs you" || holds[0].Terminal {
		t.Errorf("holds %v, want the chat, waiting on the user", holds)
	}
	if d.due(t) {
		t.Fatal("restarted while a turn waited on the user")
	}
	must(a.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: id, ItemId: perm.Id, OptionId: "allow"})))
	<-d.restart.Due() // once the turn has ended
	_, err := a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"}))
	var ce *connect.Error
	if !errors.As(err, &ce) || ce.Code() != connect.CodeUnavailable || !strings.Contains(ce.Message(), "restarting") ||
		ce.Meta().Get(api.ReasonHeader) != api.ReasonRestarting {
		t.Errorf("a prompt after the restart was due: %v, want Unavailable, its reason restarting", err)
	}
}

// With nothing running, a chat open between turns included, it comes at
// once.
func TestRestartWithNothingRunning(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.say(id, "hello")
	must(a.c.RestartWhenIdle(ctx, connect.NewRequest(&nushiv1.RestartWhenIdleRequest{})))
	<-d.restart.Due()
}

// A prompt sent as the restart is decided either runs first (the restart
// waits for its turn) or is refused to be sent again: never taken and
// then dropped.
func TestAPromptAtTheRestartIsntLost(t *testing.T) {
	ctx := context.Background()
	for range 5 {
		d := startDaemon(t, t.TempDir(), &acptest.History{})
		a := open(t, d)
		id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
		sent := make(chan error, 1)
		go func() {
			_, err := a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"}))
			sent <- err
		}()
		must(a.c.RestartWhenIdle(ctx, connect.NewRequest(&nushiv1.RestartWhenIdleRequest{})))
		<-d.restart.Due()
		err := <-sent
		items := a.get(id).Items
		switch {
		case err == nil && !strings.HasSuffix(transcript(items), "AGENT_MESSAGE:You said: hello:"):
			t.Fatalf("the prompt was taken, but its turn hadn't run when the restart came:\n%s", transcript(items))
		case err != nil && connect.CodeOf(err) != connect.CodeUnavailable:
			t.Fatalf("the prompt failed: %v, want Unavailable", err)
		}
		d.stop()
	}
}

// A terminal running a command holds the restart (the terminal ends with
// the daemon); one at its prompt doesn't.
func TestRestartWaitsForATerminalsCommand(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	term := must(a.c.OpenTerminal(ctx, connect.NewRequest(&nushiv1.OpenTerminalRequest{ChatId: id, Cols: 80, Rows: 24}))).Terminal
	must(a.c.WriteTerminal(ctx, connect.NewRequest(&nushiv1.WriteTerminalRequest{TerminalId: term.Id, Data: []byte("sleep 30\n")})))
	a.waitFor("the command", func(e *nushiv1.EventsResponse) bool {
		ts := e.GetTerminals().GetTerminals()
		return len(ts) == 1 && strings.HasPrefix(ts[0].Program, "sleep")
	})
	holds := must(a.c.RestartWhenIdle(ctx, connect.NewRequest(&nushiv1.RestartWhenIdleRequest{}))).Holds
	if len(holds) != 1 || holds[0].ChatId != id || !strings.HasPrefix(holds[0].Why, "running sleep") || !holds[0].Terminal {
		t.Errorf("holds %v, want the chat's terminal running sleep", holds)
	}
	if d.due(t) {
		t.Fatal("restarted while a terminal ran a command")
	}
	must(a.c.WriteTerminal(ctx, connect.NewRequest(&nushiv1.WriteTerminalRequest{TerminalId: term.Id, Data: []byte("\x03")})))
	<-d.restart.Due() // once the command has ended
}

// An ask that isn't repeated lapses: the app that would start the new
// daemon is gone.
func TestARestartNotAskedAgainLapses(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	d.restart.Lease = 100 * time.Millisecond
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.send(id, "wait")
	a.waitFor("the turn to start", func(e *nushiv1.EventsResponse) bool { return e.GetStatus().GetBusy() })
	must(a.c.RestartWhenIdle(ctx, connect.NewRequest(&nushiv1.RestartWhenIdleRequest{})))
	until(t, "the ask to lapse", d.lapsed.Load)
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: id})))
	a.waitFor("the turn to end", turnEnded(id))
	if d.due(t) {
		t.Fatal("restarted on an ask that had lapsed")
	}
}
