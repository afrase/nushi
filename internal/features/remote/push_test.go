package remote

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"testing/synctest"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/webpush"
	"github.com/afrase/nushi/noiseconn"
	"github.com/afrase/nushi/relay"
)

// pushes records what the daemon pushed, and answers with err.
type pushes struct {
	mu     sync.Mutex
	sent   []payload
	subj   []string
	topics []string
	err    error
}

func (p *pushes) send(_ context.Context, subject string, _ webpush.Subscription, m webpush.Message) error {
	var got payload
	if err := json.Unmarshal(m.Payload, &got); err != nil {
		return err
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	p.sent = append(p.sent, got)
	p.subj = append(p.subj, subject)
	p.topics = append(p.topics, m.Topic)
	return p.err
}

func (p *pushes) take() []payload {
	p.mu.Lock()
	defer p.mu.Unlock()
	out := p.sent
	p.sent = nil
	return out
}

// settle runs the bubble's clock past every turn's wait and lets each push
// go, then takes what was pushed: exactly that, nothing still to come.
func (p *pushes) settle() []payload {
	time.Sleep(time.Second)
	synctest.Wait()
	return p.take()
}

func subscription(t *testing.T) *webpush.Subscription {
	t.Helper()
	k, err := webpush.NewKeys()
	if err != nil {
		t.Fatal(err)
	}
	return &webpush.Subscription{Endpoint: "https://web.push.apple.com/QGuQyav", P256DH: k.Public, Auth: make([]byte, 16)}
}

// connect gives device a channel to s, as a phone dialing through the
// relay would have: over an in-memory transport, with no relay.
func connect(t *testing.T, s *Service, device string) *noiseconn.Conn {
	t.Helper()
	s.mu.Lock()
	key := s.key
	s.mu.Unlock()
	a, b := pipes()
	go func() {
		if c, err := noiseconn.Initiate(a, noiseconn.Config{Static: newKey(t), Prologue: prologue("x")}, key.Public); err == nil {
			_, _ = c.Write([]byte("hi"))
		}
	}()
	conn, err := noiseconn.Respond(b, noiseconn.Config{Static: key, Prologue: prologue("x")}, func([]byte) error { return nil })
	testcheck.NoErr(t, err)
	s.mu.Lock()
	s.conns[conn] = device
	s.mu.Unlock()
	return conn
}

// pushing is remote access with a paired web device, "d1", connected and
// with notifications on; chat "c1" is Claude's, anything else a side chat.
// A turn's end is pushed after 20 ms, and tune may shorten other waits.
// Remote access is off: no relay is needed to push. Run in a synctest
// bubble, its waits pass on the bubble's clock.
func pushing(t *testing.T, tune ...func(*timing)) (*Service, *pushes, string, string) {
	t.Helper()
	dir := t.TempDir()
	st := store.New(dir)
	testcheck.NoErr(t, st.SaveRemote(model.RemoteSettings{Relay: "ws://relay.test"}))
	testcheck.NoErr(t, st.SaveDevices([]model.Device{{ID: "d1", Name: "Test phone", Kind: "web", Key: newKey(t).Public, Paired: time.Now()}}))
	tm := defaultTiming()
	tm.finished = 20 * time.Millisecond
	for _, f := range tune {
		f(&tm)
	}
	s, err := newService(st, &relay.Dialer{}, echo, func() func() { return func() {} }, func(model.Event) {}, tm)
	testcheck.NoErr(t, err)
	t.Cleanup(s.Close)
	p := &pushes{}
	s.UsePush(Push{Key: "key", Send: p.send, Agent: func(id string) (string, bool) { return "Claude", id == "c1" }}, false)
	connect(t, s, "d1")
	if err := s.SetPush("d1", subscription(t)); err != nil {
		t.Fatal(err)
	}
	if !s.Get().Devices[0].Connected || s.Get().Devices[0].Push == nil {
		t.Fatal("not connected, or no subscription")
	}
	return s, p, "d1", dir
}

// turn is a turn in chat that the agent ended.
func turn(s *Service, chat string) {
	s.Follow(model.Event{ChatID: chat, Status: &model.Status{Busy: true, Started: time.Now()}})
	s.Follow(model.Event{ChatID: chat, Status: &model.Status{Busy: true, Started: time.Now(), Waiting: true}})
	s.Follow(model.Event{ChatID: chat, Status: &model.Status{Ended: model.TurnDone}})
	s.Follow(model.Event{ChatID: chat, Status: &model.Status{}})
}

func TestPushSaysOnlyWhatHappened(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		s, p, _, _ := pushing(t)
		turn(s, "c1")
		ask := func(kind model.ItemKind, id string) {
			s.Follow(model.Event{ChatID: "c1", Item: &model.Item{ID: id, Kind: kind, Status: "pending", Text: "SECRET the agent's words", Title: "SECRET rm -rf"}})
		}
		ask(model.Permission, "p1")
		ask(model.Permission, "p1") // an update of the same prompt
		ask(model.Question, "q1")
		s.Follow(model.Event{ChatID: "c1", Item: &model.Item{ID: "q1", Kind: model.Question, Status: "answered"}})
		s.Follow(model.Event{ChatID: "c1", Item: &model.Item{ID: "m", Kind: model.AgentMessage, Text: "SECRET"}})
		turn(s, "side") // not a stored chat
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Asleep: true}})
		got := p.settle()
		want := map[string]payload{
			"finished":   {Title: "Claude finished", Kind: "finished", Agent: "Claude", Chat: "c1"},
			"permission": {Title: "Claude needs you", Kind: "permission", Agent: "Claude", Chat: "c1"},
			"question":   {Title: "Claude has a question", Kind: "question", Agent: "Claude", Chat: "c1"},
		}
		if len(got) != 3 {
			t.Fatalf("pushed %+v", got)
		}
		for _, g := range got {
			if want[g.Kind] != g {
				t.Errorf("pushed %+v", g)
			}
			b, _ := json.Marshal(g)
			if strings.Contains(string(b), "SECRET") {
				t.Errorf("chat content in a push: %s", b)
			}
		}
		if p.subj[0] != "https://relay.test" {
			t.Errorf("subject %q", p.subj[0])
		}
	})
}

func TestNoPushWhileTheChatIsOpen(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		s, p, device, _ := pushing(t)
		s.SetView(device, "c1")
		turn(s, "c1")
		if got := p.settle(); len(got) != 0 {
			t.Fatalf("pushed while the chat was open: %+v", got)
		}
		s.SetView(device, "c2")
		turn(s, "c1")
		if got := p.settle(); len(got) != 1 {
			t.Fatalf("another chat open: %+v", got)
		}
		// Disconnected, the open chat doesn't count.
		s.SetView(device, "c1")
		s.mu.Lock()
		var conns []*noiseconn.Conn
		for c := range s.conns {
			conns = append(conns, c)
		}
		s.mu.Unlock()
		for _, c := range conns {
			_ = (&served{Conn: c, s: s, device: device}).Close() // as the API's server closes it
		}
		if s.Get().Devices[0].Connected {
			t.Fatal("still connected")
		}
		turn(s, "c1")
		if got := p.settle(); len(got) != 1 {
			t.Fatalf("disconnected: %+v", got)
		}
	})
}

func TestGoneSubscriptionIsForgotten(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		s, p, device, dir := pushing(t)
		p.err = webpush.ErrGone
		if err := s.TestPush(context.Background(), device); err == nil {
			t.Fatal("a gone subscription's test passed")
		}
		if s.Get().Devices[0].Push != nil {
			t.Fatal("kept a gone subscription")
		}
		if b, _ := os.ReadFile(filepath.Join(dir, "devices.json")); strings.Contains(string(b), "web.push.apple.com") {
			t.Fatalf("devices.json keeps it: %s", b)
		}
		turn(s, "c1")
		if got := p.settle(); len(got) != 1 { // the test only
			t.Fatalf("pushed after it was gone: %+v", got)
		}
	})
}

func TestRevokeDropsTheSubscription(t *testing.T) {
	s, _, device, dir := pushing(t)
	if b, _ := os.ReadFile(filepath.Join(dir, "devices.json")); !strings.Contains(string(b), "web.push.apple.com") {
		t.Fatalf("not kept: %s", b)
	}
	if err := s.Revoke(device); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "devices.json")); strings.Contains(string(b), "web.push.apple.com") {
		t.Fatalf("kept after Revoke: %s", b)
	}
	if err := s.TestPush(context.Background(), device); err == nil {
		t.Fatal("a revoked device's test passed")
	}
}

func TestSubscriptionsOnlyToPushServices(t *testing.T) {
	s, _, device, _ := pushing(t)
	for _, endpoint := range []string{"https://169.254.169.254/latest/meta-data", "http://web.push.apple.com/x", "https://evil.example.com/push"} {
		sub := subscription(t)
		sub.Endpoint = endpoint
		if err := s.SetPush(device, sub); err == nil {
			t.Errorf("took %s", endpoint)
		}
	}
	if s.Get().Devices[0].Push.Endpoint != "https://web.push.apple.com/QGuQyav" {
		t.Error("a refused subscription replaced the good one")
	}
	if err := s.SetPush("nobody", subscription(t)); err == nil {
		t.Error("a subscription for no device")
	}
	if err := s.SetPush(device, nil); err != nil || s.Get().Devices[0].Push != nil {
		t.Errorf("turning off: %v", err)
	}
}

// A turn the chat says failed (an error, or its agent quit mid-turn) is
// pushed as failed, as the Mac says it, and nothing of the error goes.
func TestAFailedTurnPushesFailed(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		s, p, _, _ := pushing(t)
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Busy: true, Started: time.Now()}})
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Ended: model.TurnFailed, Failure: "SECRET the agent's error"}})
		got := p.settle()
		if want := (payload{Title: "Claude's turn failed", Kind: "failed", Agent: "Claude", Chat: "c1"}); len(got) != 1 || got[0] != want {
			t.Fatalf("pushed %+v, want %+v", got, want)
		}
	})
}

// A turn's end replaces the last one at the push service, finished or
// failed, so a Try again that worked leaves no stale failure; a question
// keeps its own.
func TestATurnsEndReplacesTheLast(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		s, p, _, _ := pushing(t)
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Busy: true, Started: time.Now()}})
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Ended: model.TurnFailed, Failure: "boom"}})
		p.settle()
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Busy: true, Started: time.Now()}})
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Ended: model.TurnDone}})
		p.settle()
		p.mu.Lock()
		defer p.mu.Unlock()
		if len(p.topics) != 2 || p.topics[0] != p.topics[1] || p.topics[0] == "" {
			t.Fatalf("topics %q: want one for both ends", p.topics)
		}
	})
}

// A turn the chat says was stopped (the user stopped it, its agent was
// being archived or put to sleep), and a turn the agent goes straight on
// from (the next queued message), aren't pushed; nor is a status that
// merely has no turn running.
func TestNoFinishedForAStopOrAQueue(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		s, p, _, _ := pushing(t)
		started := &model.Status{Busy: true, Started: time.Now()}
		s.Follow(model.Event{ChatID: "c1", Status: started})
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Ended: model.TurnStopped}})
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{}})
		s.Follow(model.Event{ChatID: "c1", Status: started})
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Ended: model.TurnFailed}})
		s.Follow(model.Event{ChatID: "c1", Status: started}) // Try again, at once
		s.Follow(model.Event{ChatID: "c1", Status: started})
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Ended: model.TurnDone}})
		s.Follow(model.Event{ChatID: "c1", Status: started}) // the queue's next
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Asleep: true}})
		if got := p.settle(); len(got) != 0 {
			t.Fatalf("pushed %+v", got)
		}
		s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Ended: model.TurnDone}})
		if got := p.settle(); len(got) != 1 || got[0].Kind != "finished" {
			t.Fatalf("pushed %+v", got)
		}
	})
}

// An open chat counts only while the device keeps saying so.
func TestTheViewLapses(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		s, p, device, _ := pushing(t, func(tm *timing) { tm.viewLease = 50 * time.Millisecond })
		s.SetView(device, "c1")
		time.Sleep(49 * time.Millisecond)
		if !s.Shown("c1") {
			t.Fatal("the view lapsed early")
		}
		time.Sleep(time.Millisecond)
		turn(s, "c1")
		if got := p.settle(); len(got) != 1 {
			t.Fatalf("a lapsed view: %+v", got)
		}
	})
}

// Shown counts the Mac's view (device "", no connection) and a connected
// device's, each while its lease holds; the Mac's view sends no push.
func TestShownByTheMacOrADevice(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		s, p, device, _ := pushing(t, func(tm *timing) { tm.viewLease = 50 * time.Millisecond })
		s.SetView("", "c1")
		s.SetView(device, "c2")
		if !s.Shown("c1") || !s.Shown("c2") || s.Shown("c3") {
			t.Fatalf("shown: c1 %v, c2 %v, c3 %v", s.Shown("c1"), s.Shown("c2"), s.Shown("c3"))
		}
		turn(s, "c1")
		if got := p.settle(); len(got) != 1 {
			t.Fatalf("the Mac's view kept the phone's push: %+v", got)
		}
		if s.Shown("c1") || s.Shown("c2") {
			t.Error("a lapsed view still shows")
		}
	})
}

// A new VAPID key: the subscriptions made with the old one are dropped.
func TestFreshKeyDropsSubscriptions(t *testing.T) {
	s, _, _, dir := pushing(t)
	s.UsePush(Push{Key: "new"}, true)
	if s.Get().Devices[0].Push != nil {
		t.Fatal("kept a subscription to the old key")
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "devices.json")); strings.Contains(string(b), "web.push.apple.com") {
		t.Fatalf("devices.json keeps it: %s", b)
	}
}

// Not in a bubble: the file's time is the real clock's.
func TestSameSubscriptionWritesNothing(t *testing.T) {
	s, _, device, dir := pushing(t)
	path := filepath.Join(dir, "devices.json")
	before, _ := os.Stat(path)
	time.Sleep(20 * time.Millisecond)
	d := s.Get().Devices[0].Push
	if err := s.SetPush(device, &webpush.Subscription{Endpoint: d.Endpoint, P256DH: d.P256DH, Auth: d.Auth}); err != nil {
		t.Fatal(err)
	}
	if after, _ := os.Stat(path); !after.ModTime().Equal(before.ModTime()) {
		t.Error("rewrote devices.json for the same subscription")
	}
}

// While a push is in flight, other chats' pushes wait their turn: only the
// same chat's push of the same kind takes the place of one waiting.
func TestPushesWaitWhileOneIsSent(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		s, p, device, _ := pushing(t)
		release, first := make(chan struct{}), make(chan struct{}, 1)
		s.UsePush(Push{Key: "key", Agent: func(string) (string, bool) { return "Claude", true },
			Send: func(ctx context.Context, subject string, sub webpush.Subscription, m webpush.Message) error {
				select {
				case first <- struct{}{}:
					<-release // the first push is slow: a proxy, a hanging push service
				default:
				}
				return p.send(ctx, subject, sub, m)
			}}, false)
		waiting := func(n int) {
			t.Helper()
			synctest.Wait()
			s.notes.mu.Lock()
			defer s.notes.mu.Unlock()
			if ob := s.notes.outbox[device]; ob == nil || len(ob.waiting) != n {
				t.Fatalf("waiting: %+v, want %d", ob, n)
			}
		}
		ask := func(chat, id string, kind model.ItemKind) {
			s.Follow(model.Event{ChatID: chat, Item: &model.Item{ID: id, Kind: kind, Status: "pending"}})
		}
		ask("c1", "q", model.Question)
		<-first
		ask("c2", "p", model.Permission)
		waiting(1)
		ask("c3", "q", model.Question)
		waiting(2)
		ask("c2", "p2", model.Permission) // c2 waits already with a permission
		ask("c2", "q", model.Question)
		waiting(3)
		close(release)
		var got []string
		for _, g := range p.settle() {
			got = append(got, g.Chat+" "+g.Kind)
		}
		if want := []string{"c1 question", "c2 permission", "c3 question", "c2 question"}; !slices.Equal(got, want) {
			t.Errorf("pushed %q, want %q", got, want)
		}
	})
}

// A turn's "finished" wait is the service's: Close ends it, and nothing
// of it runs into the service (or the chats, through Agent) after Close
// returned.
func TestCloseEndsTheFinishedWait(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		s, p, _, _ := pushing(t, func(tm *timing) { tm.finished = 200 * time.Millisecond })
		var mu sync.Mutex
		closed, after := false, false
		s.UsePush(Push{Key: "key", Send: p.send,
			Agent: func(string) (string, bool) {
				mu.Lock()
				defer mu.Unlock()
				after = after || closed
				return "Claude", true
			}}, false)
		turn(s, "c1")
		s.Close()
		mu.Lock()
		closed = true
		mu.Unlock()
		if after || len(p.settle()) > 0 { // past the wait
			t.Error("the finished wait called into the service after Close returned")
		}
	})
}
