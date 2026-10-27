package remote

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/webpush"
)

// pushes records what the daemon pushed, and answers with err.
type pushes struct {
	mu   sync.Mutex
	sent []payload
	subj []string
	err  error
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
	return p.err
}

func (p *pushes) take() []payload {
	p.mu.Lock()
	defer p.mu.Unlock()
	out := p.sent
	p.sent = nil
	return out
}

// settle waits for the pushes sent in the background, and takes them.
func (p *pushes) settle(t *testing.T, n int) []payload {
	t.Helper()
	waitFor(t, func() bool { p.mu.Lock(); defer p.mu.Unlock(); return len(p.sent) >= n })
	time.Sleep(50 * time.Millisecond) // none more than n
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

// pushing is remote access with a paired web device whose notifications
// are on; chat "c1" is Claude's, anything else a side chat.
func pushing(t *testing.T) (*Service, *pushes, string, string) {
	t.Helper()
	wait := FinishedWait
	FinishedWait = 20 * time.Millisecond
	t.Cleanup(func() { FinishedWait = wait })
	dir := t.TempDir()
	s := startRemote(t, dir, startRelay(t))
	p := &pushes{}
	s.UsePush(Push{Key: "key", Send: p.send, Agent: func(id string) (string, bool) { return "Claude", id == "c1" }}, false)
	pairOne(t, s, newKey(t))
	d := s.Get().Devices[0]
	if d.Kind != "web" {
		t.Fatalf("kind %q", d.Kind)
	}
	if err := s.SetPush(d.ID, subscription(t)); err != nil {
		t.Fatal(err)
	}
	if !s.Get().Devices[0].Connected || s.Get().Devices[0].Push == nil {
		t.Fatal("not connected, or no subscription")
	}
	return s, p, d.ID, dir
}

func turn(s *Service, chat string) {
	s.Follow(model.Event{ChatID: chat, Status: &model.Status{Busy: true, Started: time.Now()}})
	s.Follow(model.Event{ChatID: chat, Status: &model.Status{Busy: true, Started: time.Now(), Waiting: true}})
	s.Follow(model.Event{ChatID: chat, Status: &model.Status{}})
}

func TestPushSaysOnlyWhatHappened(t *testing.T) {
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
	got := p.settle(t, 3)
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
	if p.subj[0] != "https://"+strings.TrimPrefix(s.Get().Relay, "ws://") {
		t.Errorf("subject %q", p.subj[0])
	}
}

func TestNoPushWhileTheChatIsOpen(t *testing.T) {
	s, p, device, _ := pushing(t)
	s.SetView(device, "c1")
	turn(s, "c1")
	time.Sleep(100 * time.Millisecond)
	if got := p.take(); len(got) != 0 {
		t.Fatalf("pushed while the chat was open: %+v", got)
	}
	s.SetView(device, "c2")
	turn(s, "c1")
	if got := p.settle(t, 1); len(got) != 1 {
		t.Fatalf("another chat open: %+v", got)
	}
	// Disconnected, the open chat doesn't count.
	s.SetView(device, "c1")
	s.mu.Lock()
	for c := range s.conns {
		_ = c.Close()
	}
	s.mu.Unlock()
	waitFor(t, func() bool { return !s.Get().Devices[0].Connected })
	turn(s, "c1")
	if got := p.settle(t, 1); len(got) != 1 {
		t.Fatalf("disconnected: %+v", got)
	}
}

func TestGoneSubscriptionIsForgotten(t *testing.T) {
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
	time.Sleep(100 * time.Millisecond)
	if got := p.take(); len(got) != 1 { // the test only
		t.Fatalf("pushed after it was gone: %+v", got)
	}
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

// A stopped turn, and a turn the agent goes straight on from (the next
// queued message), aren't "finished".
func TestNoFinishedForAStopOrAQueue(t *testing.T) {
	s, p, _, _ := pushing(t)
	s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Busy: true, Started: time.Now()}})
	s.Follow(model.Event{ChatID: "c1", Item: &model.Item{ID: "n", Kind: model.Notice, Status: "cancelled"}})
	s.Follow(model.Event{ChatID: "c1", Status: &model.Status{}})
	s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Busy: true, Started: time.Now()}})
	s.Follow(model.Event{ChatID: "c1", Status: &model.Status{}})
	s.Follow(model.Event{ChatID: "c1", Status: &model.Status{Busy: true, Started: time.Now()}}) // the queue's next
	time.Sleep(100 * time.Millisecond)
	if got := p.take(); len(got) != 0 {
		t.Fatalf("pushed %+v", got)
	}
	s.Follow(model.Event{ChatID: "c1", Status: &model.Status{}})
	if got := p.settle(t, 1); len(got) != 1 || got[0].Kind != "finished" {
		t.Fatalf("pushed %+v", got)
	}
}

// An open chat counts only while the device keeps saying so.
func TestTheViewLapses(t *testing.T) {
	s, p, device, _ := pushing(t)
	lease := ViewLease
	ViewLease = 50 * time.Millisecond
	t.Cleanup(func() { ViewLease = lease })
	s.SetView(device, "c1")
	time.Sleep(80 * time.Millisecond)
	turn(s, "c1")
	if got := p.settle(t, 1); len(got) != 1 {
		t.Fatalf("a lapsed view: %+v", got)
	}
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
