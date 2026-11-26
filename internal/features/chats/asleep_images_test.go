package chats

import (
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// png is a few bytes of an image, as a pasted one is sent.
var pastedPNG = model.Image{MimeType: "image/png", Data: []byte("\x89PNG\r\n\x1a\n")}

// what is the part of a status an asleep chat's app goes by before the
// chat wakes: images, forking, rewinding.
func what(st model.Status) [3]bool { return [3]bool{st.Images, st.CanFork, st.CanRewind} }

// listedStatus is the chat's status as the app gets it, by its record.
func listedStatus(svc *Service, id string) model.Status {
	sess, err := svc.sessions.Sessions()
	if err != nil {
		return model.Status{}
	}
	i := slices.IndexFunc(sess, func(r model.ChatRecord) bool { return r.ID == id })
	if i < 0 {
		return model.Status{}
	}
	return svc.Status(sess[i])
}

// An asleep chat says what its agent took when it last had a session,
// put to sleep and after a daemon restart alike, so a pasted image is
// taken; the image wakes the chat and goes with the message.
func TestAsleepChatTakesImages(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	awake := what(svc.Status(c.record))
	if awake != [3]bool{true, true, true} {
		t.Fatalf("awake: images, fork, rewind = %v", awake)
	}
	testcheck.NoErr(t, svc.Sleep(c.id))
	if st := svc.Status(c.record); !st.Asleep || what(st) != awake {
		t.Errorf("put to sleep: status %+v", st)
	}

	svc2 := restarted(t, agent, c, store)
	t.Cleanup(svc2.Close)
	if st := listedStatus(svc2, c.id); !st.Asleep || what(st) != awake {
		t.Errorf("after a restart, not looked up: status %+v", st)
	}
	c2, err := svc2.lookup(c.id)
	testcheck.NoErr(t, err)
	if st := listedStatus(svc2, c.id); !st.Asleep || what(st) != awake {
		t.Errorf("after a restart, looked up: status %+v", st)
	}

	agent.updates = []acp.SessionUpdate{chunk("m2", "seen")}
	testcheck.NoErr(t, svc2.Prompt(t.Context(), c.id, model.Message{Text: "look", Images: []model.Image{pastedPNG}}, SendIdle))
	eventually(t, c2, func() bool { return len(c2.queue) == 0 && c2.agent != nil })
	idle(t, c2)
	agent.mu.Lock()
	sent := slices.Clone(agent.prompt)
	agent.mu.Unlock()
	if !slices.ContainsFunc(sent, func(b acp.ContentBlock) bool { return b.Image != nil }) {
		t.Errorf("the agent got %+v, no image", sent)
	}
	if got := texts(c2); slices.ContainsFunc(got, func(s string) bool { return s == "notice:"+noImagesNotice }) {
		t.Errorf("transcript %q", got)
	}
}

// restartedFromSaved is the service after a daemon restart, built from
// the chat's record as svc's store holds it: the last one svc saved, or
// else the one it read at its start; never the record in memory, so what
// a test reads back is what reached the store.
func restartedFromSaved(t *testing.T, agent *fakeAgent, svc *Service, id string, store *transcripts.Store) *Service {
	t.Helper()
	mem := svc.sessions.(*memSessions)
	mem.mu.Lock()
	held := append(slices.Clone(mem.stored), mem.saved...)
	mem.mu.Unlock()
	var last *model.ChatRecord
	for i := range held {
		if held[i].ID == id {
			last = &held[i]
		}
	}
	if last == nil {
		t.Fatalf("chat %s isn't in the store", id)
	}
	next := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}, Options{Sessions: &memSessions{stored: []model.ChatRecord{*last}}, Scratch: t.TempDir(), Copies: store})
	t.Cleanup(next.Close)
	return next
}

// noImagesNotice is what a message whose images didn't go says.
const noImagesNotice = "The agent doesn't take images: your queued message went without them."

// A chat whose agent took images when it slept, and whose new session
// takes none (the model or the agent changed meanwhile), sends the text
// without them, saying so; asleep again, it says images aren't taken,
// and so it does after another restart, from what was stored when the
// session opened, though no turn ran on it.
func TestAsleepChatsNewSessionTakesNoImages(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	turn(t, svc, c, "one")
	testcheck.NoErr(t, svc.Sleep(c.id))
	svc.Close()
	agent.mu.Lock()
	agent.noImages = true
	agent.mu.Unlock()

	svc2 := restartedFromSaved(t, agent, svc, c.id, store)
	c2, err := svc2.lookup(c.id)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, svc2.Prompt(t.Context(), c.id, model.Message{Text: "look", Images: []model.Image{pastedPNG}}, SendIdle))
	eventually(t, c2, func() bool { return len(c2.queue) == 0 && c2.agent != nil })
	idle(t, c2)
	agent.mu.Lock()
	sent := slices.Clone(agent.prompt)
	agent.mu.Unlock()
	if slices.ContainsFunc(sent, func(b acp.ContentBlock) bool { return b.Image != nil }) || len(sent) == 0 || sent[0].Text == nil || sent[0].Text.Text != "look" {
		t.Errorf("the agent got %+v", sent)
	}
	if got := texts(c2); !slices.Contains(got, "notice:"+noImagesNotice) {
		t.Errorf("transcript %q, no notice", got)
	}
	testcheck.NoErr(t, svc2.Sleep(c.id))
	if st := listedStatus(svc2, c.id); !st.Asleep || st.Images {
		t.Errorf("asleep again: status %+v", st)
	}
	svc2.Close()

	// The same chat, as first stored, woken with no turn (opened and read,
	// then asleep): only the session's opening stores what it took.
	svcW := restartedFromSaved(t, agent, svc, c.id, store)
	reopened(t, svcW, c.id)
	testcheck.NoErr(t, svcW.Sleep(c.id))
	svcW.Close()
	svc3 := restartedFromSaved(t, agent, svcW, c.id, store)
	if st := listedStatus(svc3, c.id); !st.Asleep || st.Images {
		t.Errorf("after another restart: status %+v", st)
	}
}

// A chat stored by a daemon that didn't keep what its agent took (or one
// that never had a session) says so as before for forking and rewinding,
// which only show; images are taken, as the agents take them, and the
// session checks as the message goes.
func TestAsleepChatWithNothingRemembered(t *testing.T) {
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: (&fakeAgent{}).launch}},
		Options{Sessions: &memSessions{stored: []model.ChatRecord{{ID: "old", SessionID: "s1", Agent: "claude", Folder: t.TempDir()}}}})
	t.Cleanup(svc.Close)
	if st := listedStatus(svc, "old"); !st.Asleep || what(st) != [3]bool{true, false, false} {
		t.Errorf("status %+v", st)
	}
}
