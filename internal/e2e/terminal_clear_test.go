package e2e

import (
	"context"
	"strings"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// attachAll reads a terminal's whole stream until it ends with the
// shell's exit, or until want is in its data, and returns its messages.
func (a *app) attachAll(id, want string) []*nushiv1.AttachTerminalResponse {
	a.t.Helper()
	ctx, cancel := context.WithTimeout(a.t.Context(), 10*time.Second)
	defer cancel()
	stream, err := a.c.AttachTerminal(ctx, connect.NewRequest(&nushiv1.AttachTerminalRequest{TerminalId: id}))
	if err != nil {
		a.t.Fatal(err)
	}
	var msgs []*nushiv1.AttachTerminalResponse
	var out strings.Builder
	for stream.Receive() {
		msgs = append(msgs, stream.Msg())
		out.Write(stream.Msg().Data)
		if stream.Msg().Exited || want != "" && strings.Contains(out.String(), want) {
			return msgs
		}
	}
	a.t.Fatalf("no %q in %d bytes: %v", want, out.Len(), stream.Err())
	return nil
}

// first is the first message of an attach to a terminal.
func (a *app) first(id string) *nushiv1.AttachTerminalResponse {
	a.t.Helper()
	ctx, cancel := context.WithTimeout(a.t.Context(), 5*time.Second)
	defer cancel()
	stream, err := a.c.AttachTerminal(ctx, connect.NewRequest(&nushiv1.AttachTerminalRequest{TerminalId: id}))
	if err != nil || !stream.Receive() {
		a.t.Fatalf("no first message: %v %v", err, stream.Err())
	}
	return stream.Msg()
}

func (a *app) clear(id string, at int64) error {
	_, err := a.c.ClearTerminal(a.t.Context(), connect.NewRequest(&nushiv1.ClearTerminalRequest{TerminalId: id, At: at}))
	return err
}

// An attach says where each message's data falls in all the terminal
// printed, and where it was cleared (issue #122): the latest clear, an
// older one ignored, one past the output taken as its end. A restart
// starts the count again with no clear; a closed terminal, like one never
// known, refuses a clear as it refuses input.
func TestATerminalKeepsItsClear(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	chatID := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	term := must(a.c.OpenTerminal(t.Context(), connect.NewRequest(&nushiv1.OpenTerminalRequest{ChatId: chatID, Command: "printf 0123456789", Cols: 80, Rows: 24}))).Terminal

	msgs := a.attachAll(term.Id, "")
	if msgs[0].Offset != 0 || msgs[0].ClearedAt != nil {
		t.Errorf("first message at %d, cleared at %v", msgs[0].Offset, msgs[0].ClearedAt)
	}
	next := int64(0)
	var data strings.Builder
	for i, m := range msgs {
		if m.Offset != next {
			t.Errorf("message %d at %d, want %d", i, m.Offset, next)
		}
		next += int64(len(m.Data))
		data.Write(m.Data)
	}
	if last := msgs[len(msgs)-1]; !last.Exited || last.Offset != 10 || data.String() != "0123456789" {
		t.Fatalf("ended with %v after %q", last, data.String())
	}

	for _, c := range []struct{ at, want int64 }{{4, 4}, {7, 7}, {5, 7}, {99, 10}, {-1, 10}} {
		if err := a.clear(term.Id, c.at); err != nil {
			t.Fatal(err)
		}
		if got := a.first(term.Id); got.ClearedAt == nil || *got.ClearedAt != c.want || got.Offset != 0 {
			t.Errorf("after a clear at %d: cleared at %v, offset %d; want %d", c.at, got.ClearedAt, got.Offset, c.want)
		}
	}

	must(a.c.RestartTerminal(t.Context(), connect.NewRequest(&nushiv1.RestartTerminalRequest{TerminalId: term.Id, Cols: 80, Rows: 24})))
	if got := a.first(term.Id); got.ClearedAt != nil || got.Offset != 0 {
		t.Errorf("restarted: cleared at %v, offset %d", got.ClearedAt, got.Offset)
	}

	must(a.c.CloseTerminal(t.Context(), connect.NewRequest(&nushiv1.CloseTerminalRequest{TerminalId: term.Id})))
	for _, id := range []string{term.Id, "no-such-terminal"} {
		_, werr := a.c.WriteTerminal(t.Context(), connect.NewRequest(&nushiv1.WriteTerminalRequest{TerminalId: id, Data: []byte("x")}))
		if err := a.clear(id, 1); connect.CodeOf(err) != connect.CodeOf(werr) || werr == nil {
			t.Errorf("%s: clear %v, write %v", id, err, werr)
		}
	}
}

// A clear the kept output no longer reaches back to is reported as it
// is, before the first message's offset: the app clears before the
// bytes it is given.
func TestAClearBeforeTheKeptOutput(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	chatID := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	term := must(a.c.OpenTerminal(t.Context(), connect.NewRequest(&nushiv1.OpenTerminalRequest{ChatId: chatID, Cols: 80, Rows: 24}))).Terminal
	must(a.c.WriteTerminal(t.Context(), connect.NewRequest(&nushiv1.WriteTerminalRequest{TerminalId: term.Id, Data: []byte("echo early-$((1+1))\n")})))
	a.attachAll(term.Id, "early-2\r\n")
	if err := a.clear(term.Id, 3); err != nil {
		t.Fatal(err)
	}
	must(a.c.WriteTerminal(t.Context(), connect.NewRequest(&nushiv1.WriteTerminalRequest{TerminalId: term.Id,
		Data: []byte("i=0; while [ $i -lt 3000 ]; do printf '%01000d\\n' $i; i=$((i+1)); done; echo late-$((2+2))\n")})))
	a.attachAll(term.Id, "late-4\r\n")
	if got := a.first(term.Id); got.ClearedAt == nil || *got.ClearedAt != 3 || got.Offset <= 3 {
		t.Errorf("cleared at %v, the kept output at %d", got.ClearedAt, got.Offset)
	}
}

// Terminals end with the daemon (ADR 0022), and their clears with them: a
// daemon started again on the same data has neither.
func TestAClearEndsWithTheDaemon(t *testing.T) {
	dir := t.TempDir()
	d := startDaemon(t, dir, &acptest.History{})
	a := open(t, d)
	chatID := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	term := must(a.c.OpenTerminal(t.Context(), connect.NewRequest(&nushiv1.OpenTerminalRequest{ChatId: chatID, Cols: 80, Rows: 24}))).Terminal
	if err := a.clear(term.Id, 0); err != nil {
		t.Fatal(err)
	}
	d.stop()
	b := open(t, startDaemon(t, dir, &acptest.History{}))
	if l := must(b.c.ListTerminals(t.Context(), connect.NewRequest(&nushiv1.ListTerminalsRequest{ChatId: chatID}))).Terminals; len(l) != 0 {
		t.Errorf("terminals after a restart: %v", l)
	}
	if err := b.clear(term.Id, 0); connect.CodeOf(err) != connect.CodeFailedPrecondition {
		t.Errorf("a clear after a restart: %v", err)
	}
}
