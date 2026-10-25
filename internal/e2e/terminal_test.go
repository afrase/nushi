package e2e

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/acp/acptest"
	"github.com/afrase/nushi/internal/features/terminals"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/terminal"
)

func startSh(folder string, cols, rows int, changed func()) (terminals.Shell, error) {
	return terminal.Start([]string{"/bin/sh"}, folder, []string{"PS1=$ ", "TERM=xterm-256color"}, cols, rows, changed)
}

// attach reads a terminal's output until it contains want, or its exit.
func (a *app) attach(ctx context.Context, id, want string) *nushiv1.AttachTerminalResponse {
	a.t.Helper()
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	stream, err := a.c.AttachTerminal(ctx, connect.NewRequest(&nushiv1.AttachTerminalRequest{TerminalId: id}))
	if err != nil {
		a.t.Fatal(err)
	}
	var out string
	for stream.Receive() {
		if stream.Msg().Exited {
			return stream.Msg()
		}
		if out += string(stream.Msg().Data); want != "" && strings.Contains(out, want) {
			return nil
		}
	}
	a.t.Fatalf("no %q in %q: %v", want, out, stream.Err())
	return nil
}

func TestTerminalOutlivesTheApp(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	folder, _ := filepath.EvalSymlinks(t.TempDir())
	first := open(t, d)
	chatID := must(first.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: folder}))).ChatId
	term := must(first.c.OpenTerminal(ctx, connect.NewRequest(&nushiv1.OpenTerminalRequest{ChatId: chatID, Cols: 80, Rows: 24}))).Terminal
	if term.Folder != folder {
		t.Fatalf("folder %q, want %q", term.Folder, folder)
	}
	must(first.c.WriteTerminal(ctx, connect.NewRequest(&nushiv1.WriteTerminalRequest{TerminalId: term.Id, Data: []byte("pwd\n")})))
	first.attach(ctx, term.Id, folder+"\r\n")
	first.quit()

	// The app comes back: the terminal is listed, and attaching replays it.
	second := open(t, d)
	list := must(second.c.ListTerminals(ctx, connect.NewRequest(&nushiv1.ListTerminalsRequest{ChatId: chatID}))).Terminals
	if len(list) != 1 || list[0].Id != term.Id || list[0].Exited {
		t.Fatalf("terminals = %v", list)
	}
	second.attach(ctx, term.Id, folder+"\r\n")

	// Its exit is reported, and it stays listed until closed.
	must(second.c.WriteTerminal(ctx, connect.NewRequest(&nushiv1.WriteTerminalRequest{TerminalId: term.Id, Data: []byte("exit 4\n")})))
	if exit := second.attach(ctx, term.Id, ""); exit == nil || exit.ExitCode != 4 {
		t.Fatalf("exit = %v, want code 4", exit)
	}
	second.waitFor("the exit in the list", func(e *nushiv1.EventsResponse) bool {
		ts := e.GetTerminals().GetTerminals()
		return len(ts) == 1 && ts[0].Exited && ts[0].ExitCode == 4
	})

	// Archiving the chat closes its terminals.
	other := must(second.c.OpenTerminal(ctx, connect.NewRequest(&nushiv1.OpenTerminalRequest{ChatId: chatID, Folder: os.TempDir(), Cols: 80, Rows: 24}))).Terminal
	plan := must(second.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: chatID})))
	if len(plan.Terminals) != 1 || plan.Terminals[0].Id != other.Id {
		t.Fatalf("delete plan's terminals = %v, want the running one", plan.Terminals)
	}
	must(second.c.ArchiveChat(ctx, connect.NewRequest(&nushiv1.ArchiveChatRequest{ChatId: chatID, Archived: true})))
	second.waitFor("the terminals to close", func(e *nushiv1.EventsResponse) bool {
		return e.GetTerminals() != nil && len(e.GetTerminals().GetTerminals()) == 0
	})
}
