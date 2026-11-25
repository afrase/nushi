package chats

import (
	"slices"
	"testing"
	"testing/synctest"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Close waits for what a request left running: here a reopen's deleting of
// the chat's thrown-away sessions, which saves the chat's record once done.
// Nothing of it may still run (and write) once Close has returned, as the
// daemon's data folder may go then; Close cancels it instead, and the
// record keeps the session for the next open.
func TestCloseWaitsForDiscarding(t *testing.T) {
	agent := &fakeAgent{deletes: true, deleteGate: make(chan struct{}), entered: make(chan string, 16)}
	t.Cleanup(func() { close(agent.deleteGate) }) // frees a delete Close left running
	sessions := &memSessions{stored: []model.ChatRecord{{ID: "c0", SessionID: "s0", Agent: "a", Folder: t.TempDir(), Throwaway: []string{"fork"}}}}
	svc := newService(t, []Kind{{Harness: model.HarnessInfo{Name: "a"}, Launch: agent.launch}}, Options{Sessions: sessions})
	if _, err := svc.Get("c0"); err != nil { // reopens the chat, which discards its throwaway
		t.Fatal(err)
	}
	for gate := range agent.entered {
		if gate == "delete" {
			break
		}
	}
	svc.Close()
	agent.mu.Lock()
	defer agent.mu.Unlock()
	if agent.gatedDeletes != 0 {
		t.Errorf("Close returned with %d deletes still running", agent.gatedDeletes)
	}
	if len(agent.deleted) != 0 {
		t.Errorf("deleted %v: Close cancels the discarding, and the record keeps them", agent.deleted)
	}
}

// A reopen racing Close says nothing in the chat: its agent, opened as
// the daemon stopped, is killed by Close, which isn't the agent quitting,
// and the reopen it ends hasn't failed. In a bubble: once Close has
// returned and everything settled, nothing is left to write.
func TestAReopenRacingCloseSaysNothing(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		agent := &fakeAgent{loadGate: make(chan struct{}), stopGate: make(chan struct{})}
		sessions := &memSessions{stored: []model.ChatRecord{{ID: "c0", SessionID: "s0", Agent: "a", Folder: t.TempDir(), HasMessages: true}}}
		svc := newService(t, []Kind{{Harness: model.HarnessInfo{Name: "a"}, Launch: agent.launch}}, Options{Sessions: sessions})
		if _, err := svc.Get("c0"); err != nil { // reopens the chat
			t.Fatal(err)
		}
		synctest.Wait() // its load waits
		closed := make(chan struct{})
		go func() {
			svc.Close()
			close(closed)
		}()
		synctest.Wait()
		close(agent.loadGate)
		<-closed
		synctest.Wait()
		c, err := svc.find("c0")
		if err != nil {
			t.Fatal(err)
		}
		c.mu.Lock()
		defer c.mu.Unlock()
		if i := slices.IndexFunc(c.items, func(it model.Item) bool { return it.Kind == model.Notice }); i >= 0 {
			t.Errorf("notice %q", c.items[i].Text)
		}
	})
}

// An agent a reopen adopts after Close has ended the chats', and that
// Close then kills with the agents still being opened, didn't quit: the
// chat says nothing (watch). In a bubble: the reopen's load is held past
// its session's opening (reading the messages' times) until Close has
// killed its agent, and adopts it after.
func TestAnAgentAdoptedAsCloseKillsItSaysNothing(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		agent := &fakeAgent{stopGate: make(chan struct{})} // its kill (Close) ends it
		dating, dated := make(chan struct{}), make(chan struct{})
		h := struct {
			model.HarnessInfo
			messageTimes
		}{model.HarnessInfo{Name: "a"}, func(string, string) map[string]time.Time {
			close(dating)
			<-dated
			return nil
		}}
		sessions := &memSessions{stored: []model.ChatRecord{{ID: "c0", SessionID: "s0", Agent: "a", Folder: t.TempDir(), HasMessages: true}}}
		svc := newService(t, []Kind{{Harness: h, Launch: agent.launch}}, Options{Sessions: sessions})
		if _, err := svc.Get("c0"); err != nil { // reopens the chat
			t.Fatal(err)
		}
		<-dating // its session is open, its agent not yet the chat's
		closed := make(chan struct{})
		go func() {
			svc.Close()
			close(closed)
		}()
		synctest.Wait() // Close has killed the agent, and waits for the reopen
		close(dated)
		<-closed
		synctest.Wait()
		c, err := svc.find("c0")
		if err != nil {
			t.Fatal(err)
		}
		c.mu.Lock()
		defer c.mu.Unlock()
		if i := slices.IndexFunc(c.items, func(it model.Item) bool { return it.Kind == model.Notice }); i >= 0 {
			t.Errorf("notice %q", c.items[i].Text)
		}
	})
}
