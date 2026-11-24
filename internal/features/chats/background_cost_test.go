package chats

import (
	"context"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"
	"testing/synctest"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// What following a background command costs while it runs for hours (a
// dev server): its file read only when it changed, its tail sent at most
// every commandTail, and the copy written with its row at its call's end
// and its command's, not at each model call (ADR 0130).

// countedFile is Claude's harness with its reads of a command's file
// counted.
type countedFile struct {
	testHarness
	reads *atomic.Int32
}

func (h countedFile) ReadBackgroundCommand(id, file string) (output, end, state string, err error) {
	h.reads.Add(1)
	return h.testHarness.ReadBackgroundCommand(id, file)
}

// rowCopies keeps the rows of waitCall the copy was given, in order.
type rowCopies struct {
	Copies
	mu   sync.Mutex
	rows []model.BackgroundCommand
}

func (r *rowCopies) Append(_ string, items []model.Item, _ []string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, it := range items {
		if it.ID == waitCall && it.BackgroundCommand != nil {
			r.rows = append(r.rows, *it.BackgroundCommand)
		}
	}
	return nil
}

func (r *rowCopies) copied() []model.BackgroundCommand {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]model.BackgroundCommand(nil), r.rows...)
}

// costFixture is a chat of Claude's, in a synctest bubble, whose
// waitCall left its command running, followed each commandPoll: its
// file's reads counted, the rows its events carried and the copy's.
type costFixture struct {
	c      *chat
	file   string
	reads  *atomic.Int32
	copies *rowCopies
	stop   context.CancelFunc // the service closes
	mu     sync.Mutex
	rows   []model.BackgroundCommand
}

func costChat(t *testing.T, text string) *costFixture {
	t.Helper()
	f := &costFixture{file: filepath.Join(taskDir(t), waitTask+".output"), reads: &atomic.Int32{}, copies: &rowCopies{}}
	testcheck.NoErr(t, os.WriteFile(f.file, []byte(text), 0o600))
	ctx, stop := context.WithCancel(t.Context())
	f.stop = stop
	f.c = &chat{svc: &Service{remembered: &memModes{}, ctx: ctx}, id: "s1", sid: "s1", agent: &fakeAgent{},
		kind: testKind(countedFile{testHarness{}, f.reads}), copies: f.copies, copiesOn: func() bool { return true }, unsaved: map[string]bool{},
		items: []model.Item{{ID: waitCall, Kind: model.ToolCall, Tool: "Bash", Status: "completed",
			BackgroundCommand: &model.BackgroundCommand{ID: waitTask, State: model.RunRunning, Started: time.Now()}}},
		publish: func(e model.Event) {
			if e.Item != nil && e.Item.ID == waitCall && e.Item.BackgroundCommand != nil {
				f.mu.Lock()
				f.rows = append(f.rows, *e.Item.BackgroundCommand)
				f.mu.Unlock()
			}
		}}
	go f.c.followCommand(waitCall, waitTask, f.file, f.c.agent, commandPoll)
	synctest.Wait()
	return f
}

// published is the rows the command's events carried.
func (f *costFixture) published() []model.BackgroundCommand {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]model.BackgroundCommand(nil), f.rows...)
}

// add appends s to the command's output file.
func (f *costFixture) add(t *testing.T, s string) {
	t.Helper()
	w, err := os.OpenFile(f.file, os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	_, err = w.WriteString(s)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, w.Close())
}

// tell feeds Claude's word on the task, as its updates would.
func (f *costFixture) tell(task map[string]any) {
	f.c.mu.Lock()
	defer f.c.mu.Unlock()
	f.c.commandTaskLocked(taskUpdate(task).Update)
}

// A file that didn't change isn't opened again, yet the steps that wait
// on the same output twice still end the command: the file's end line
// once the file stopped growing, and the end Claude told of.
func TestAnUnchangedBackgroundCommandFileIsNotReadAgain(t *testing.T) {
	t.Run("the file's end", func(t *testing.T) {
		synctest.Test(t, func(t *testing.T) {
			f := costChat(t, "waiting\n")
			pass(10 * commandPoll)
			if n := f.reads.Load(); n != 1 {
				t.Fatalf("an unchanged file read %d times in 10 polls", n)
			}
			f.add(t, "\n[exited with code 0]\n")
			pass(3 * commandPoll)
			if sh := commandOf(f.c); sh.State != model.RunDone || sh.Output != "waiting" || sh.End != "exited with code 0" {
				t.Errorf("ended as %+v", sh)
			}
			if n := f.reads.Load(); n != 2 {
				t.Errorf("read %d times, want 2 (once, then once it grew)", n)
			}
		})
	})
	t.Run("the task's end", func(t *testing.T) {
		synctest.Test(t, func(t *testing.T) {
			f := costChat(t, "waiting\n")
			f.tell(taskRunning)
			pass(5 * commandPoll)
			f.tell(taskCompleted[0])
			f.tell(taskCompleted[1])
			pass(commandPoll)
			if sh := commandOf(f.c); sh.State != model.RunDone || sh.Output != "waiting\n" || sh.End != "exited with code 0" {
				t.Errorf("ended as %+v", sh)
			}
			if n := f.reads.Load(); n != 1 {
				t.Errorf("an unchanged file read %d times", n)
			}
		})
	})
}

// A command that writes on every poll has its tail sent at most every
// commandTail; its end comes at once, with all it wrote.
func TestAChattyCommandsTailIsSentEveryFewSeconds(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := costChat(t, "line 0\n")
		f.tell(taskRunning)
		const polls = 30
		for i := range polls {
			f.add(t, "line "+string(rune('a'+i%26))+"\n")
			pass(commandPoll)
		}
		running := len(f.published())
		if most := int(polls*commandPoll/commandTail) + 2; running > most {
			t.Errorf("%d events in %d polls, want at most %d", running, polls, most)
		}
		f.add(t, "last\n")
		f.tell(taskCompleted[0])
		f.tell(taskCompleted[1])
		pass(commandPoll)
		want, err := os.ReadFile(f.file)
		testcheck.NoErr(t, err)
		rows := f.published()
		if last := rows[len(rows)-1]; last.State != model.RunDone || last.Output != string(want) {
			t.Errorf("the last event: %+v, want done with %q", last, want)
		}
	})
}

// A command that writes all through a turn of many model calls adds its
// row to the copy a bounded number of times; the copy has its end, with
// all it wrote, once it ended.
func TestAChattyCommandDoesntGrowTheCopy(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := costChat(t, "line 0\n")
		f.tell(taskRunning)
		for i := range 30 {
			f.add(t, "line "+string(rune('a'+i%26))+"\n")
			pass(commandPoll)
			f.c.mu.Lock()
			f.c.copyLocked(false) // a model call's end
			f.c.mu.Unlock()
		}
		if rows := f.copies.copied(); len(rows) > 2 {
			t.Errorf("the copy took the row %d times in 30 model calls", len(rows))
		}
		f.add(t, "last\n")
		f.tell(taskCompleted[0])
		f.tell(taskCompleted[1])
		pass(commandPoll)
		want, err := os.ReadFile(f.file)
		testcheck.NoErr(t, err)
		rows := f.copies.copied()
		if len(rows) == 0 {
			t.Fatal("the copy never took the row")
		}
		if last := rows[len(rows)-1]; last.State != model.RunDone || last.Output != string(want) {
			t.Errorf("the copy's row: %+v, want done with %q", last, want)
		}
	})
}

// A daemon that closes mid-command (an update, a logout) stops following
// it before its agent ends; the copy then still takes the row with the
// output last sent, which the file may no longer give after a reboot.
func TestTheCopyHasTheLastTailWhenTheDaemonCloses(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := costChat(t, "boot\n")
		f.tell(taskRunning)
		for i := range 10 {
			f.add(t, "line "+string(rune('a'+i))+"\n")
			pass(commandPoll)
			f.c.mu.Lock()
			f.c.copyLocked(false) // a model call's end
			f.c.mu.Unlock()
		}
		f.add(t, "last before stop\n")
		pass(commandTail)
		sent := f.published()
		f.stop() // Close cancels the service first
		synctest.Wait()
		f.c.mu.Lock()
		f.c.copyLocked(true) // the agent's end (orphanLocked)
		f.c.mu.Unlock()
		rows := f.copies.copied()
		if len(rows) == 0 {
			t.Fatal("the copy never took the row")
		}
		if last, want := rows[len(rows)-1], sent[len(sent)-1]; last.Output != want.Output {
			t.Errorf("the copy's row has %q, want the last sent %q", last.Output, want.Output)
		}
		if len(rows) > 2 {
			t.Errorf("the copy took the row %d times", len(rows))
		}
	})
}
