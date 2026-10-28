package remote

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log/slog"
	"net/url"
	"slices"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/webpush"
)

// Push is how remote access notifies devices through Web Push (ADR 0054).
type Push struct {
	Key   string // the VAPID public key, as browsers take it
	Send  func(ctx context.Context, subject string, s webpush.Subscription, m webpush.Message) error
	Agent func(chatID string) (title string, ok bool) // a stored chat's agent, as people read it ("Claude")
}

// UsePush turns notifications on: devices may subscribe, and Follow sends.
// fresh says the VAPID key is new: subscriptions made with another one no
// longer work, so they're forgotten.
func (s *Service) UsePush(p Push, fresh bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.push = &p
	if !fresh {
		return
	}
	devices := slices.Clone(s.devices)
	for i := range devices {
		devices[i].Push = nil
	}
	if err := s.st.SaveDevices(devices); err == nil {
		s.devices = devices
	}
}

// PushKey is the VAPID public key, or "" without push.
func (s *Service) PushKey() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.push == nil {
		return ""
	}
	return s.push.Key
}

// SetPush keeps device's push subscription (nil: none), after checking
// it names a known push service.
func (s *Service) SetPush(device string, sub *webpush.Subscription) error {
	var p *model.Push
	if sub != nil {
		if err := webpush.CheckSubscription(*sub); err != nil {
			return err
		}
		p = &model.Push{Endpoint: sub.Endpoint, P256DH: sub.P256DH, Auth: sub.Auth}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.push == nil && p != nil {
		return errors.New("this daemon doesn't send notifications")
	}
	i := slices.IndexFunc(s.devices, func(d model.Device) bool { return d.ID == device })
	if i >= 0 && samePush(s.devices[i].Push, p) {
		return nil // nothing to write or tell
	}
	if err := s.setPushLocked(device, p); err != nil {
		return err
	}
	slog.Info("push subscription", "device", device, "on", p != nil)
	return nil
}

func samePush(a, b *model.Push) bool {
	if a == nil || b == nil {
		return a == b
	}
	return a.Endpoint == b.Endpoint && bytes.Equal(a.P256DH, b.P256DH) && bytes.Equal(a.Auth, b.Auth)
}

// setPushLocked stores device's subscription. Called with s.mu.
func (s *Service) setPushLocked(device string, p *model.Push) error {
	i := slices.IndexFunc(s.devices, func(d model.Device) bool { return d.ID == device })
	if i < 0 {
		return errors.New("no such device")
	}
	devices := slices.Clone(s.devices)
	devices[i].Push = p
	if err := s.st.SaveDevices(devices); err != nil {
		return err
	}
	s.devices = devices
	s.changed()
	return nil
}

// view is the chat a device shows, and when it last said so.
type view struct {
	chat string
	at   time.Time
}

// SetView says which chat device shows ("" none); it gets no push for that
// chat while it's connected and keeps saying so (the view lease). A device's
// view goes with its last connection. The Mac is device "": its socket
// has no connection to lose, so only the lease ends its view.
func (s *Service) SetView(device, chatID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if chatID == "" {
		delete(s.views, device)
	} else {
		s.views[device] = view{chatID, time.Now()}
	}
}

// showingLocked says whether device shows chatID now. Called with s.mu.
func (s *Service) showingLocked(device, chatID string) bool {
	v, ok := s.views[device]
	return ok && v.chat == chatID && time.Since(v.at) < s.timing.viewLease && (device == "" || s.connectedLocked(device))
}

// Shown says whether any client, the Mac or a device, shows chatID now.
func (s *Service) Shown(chatID string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	for device := range s.views {
		if s.showingLocked(device, chatID) {
			return true
		}
	}
	return false
}

// connectedLocked says whether device has a connection open. Called with
// s.mu.
func (s *Service) connectedLocked(device string) bool {
	for _, d := range s.conns {
		if d == device {
			return true
		}
	}
	return false
}

// payload is what a push carries: what happened, never anything from the
// chat but its id.
type payload struct {
	Title string `json:"title"`          // "Claude finished"
	Kind  string `json:"kind"`           // "finished", "question", "permission", "test"
	Agent string `json:"agent,omitzero"` // "Claude"
	Chat  string `json:"chat,omitzero"`  // the chat to open
}

// TestPush sends device a test notification and says how it went.
func (s *Service) TestPush(ctx context.Context, device string) error {
	return s.send(ctx, device, payload{Title: "Nushi test notification", Kind: "test"})
}

// send pushes p to device, if it has a subscription. A subscription the
// push service no longer knows is forgotten.
func (s *Service) send(ctx context.Context, device string, p payload) error {
	s.mu.Lock()
	i := slices.IndexFunc(s.devices, func(d model.Device) bool { return d.ID == device })
	if i < 0 || s.devices[i].Push == nil || s.push == nil {
		s.mu.Unlock()
		return errors.New("notifications are off on that device")
	}
	sub := *s.devices[i].Push
	send, subject := s.push.Send, subjectOf(s.settings.Relay)
	s.mu.Unlock()
	body, _ := json.Marshal(p)
	topic := sha256.Sum256([]byte(p.Chat + "\x00" + p.Kind))
	// A prompt or question goes stale: an hour; a turn's end can wait.
	ttl := time.Hour
	if p.Kind == "finished" {
		ttl = 4 * time.Hour
	}
	m := webpush.Message{Payload: body, Topic: base64.RawURLEncoding.EncodeToString(topic[:24]), Urgent: p.Kind != "finished", TTL: ttl}
	ctx, cancel := context.WithTimeout(ctx, s.timing.push)
	defer cancel()
	err := send(ctx, subject, webpush.Subscription{Endpoint: sub.Endpoint, P256DH: sub.P256DH, Auth: sub.Auth}, m)
	if errors.Is(err, webpush.ErrGone) {
		s.mu.Lock()
		// Only if it's still the subscription that's gone.
		if j := slices.IndexFunc(s.devices, func(d model.Device) bool { return d.ID == device }); j >= 0 &&
			s.devices[j].Push != nil && s.devices[j].Push.Endpoint == sub.Endpoint {
			_ = s.setPushLocked(device, nil)
		}
		s.mu.Unlock()
		slog.Info("push subscription gone", "device", device)
		return errors.New("the device's push subscription has expired: turn notifications on again there")
	}
	if err != nil {
		slog.Warn("push failed", "device", device, "kind", p.Kind, "err", err)
	}
	return err
}

// subjectOf is the VAPID contact: the relay's own address, as https (RFC
// 8292 asks for https: or mailto:).
func subjectOf(relay string) string {
	if u, err := url.Parse(relay); err == nil && u.Host != "" {
		return "https://" + u.Host
	}
	return "mailto:nushi@users.noreply.github.com"
}

// notifier turns chats' events into pushes: a turn that ended (unless it
// was stopped, or the agent went straight on), and each permission prompt
// or question when it comes.
type notifier struct {
	mu        sync.Mutex
	running   map[string]bool            // chats with a turn running
	cancelled map[string]bool            // chats whose running turn was stopped
	asked     map[string]map[string]bool // per chat, prompts already pushed
	finishing map[string]*time.Timer     // turns' ends waiting timing.finished
	outbox    map[string]*outbox         // per device, the push in flight and the next
}

// outbox is one device's pushes: one in flight at a time, and of those
// that come meanwhile only the newest waits.
type outbox struct {
	next *payload
}

// Follow sees every event (the hub's subscriber) and pushes what a device
// should hear of.
func (s *Service) Follow(e model.Event) {
	n := &s.notes
	n.mu.Lock()
	defer n.mu.Unlock()
	if n.running == nil {
		n.running, n.cancelled, n.asked = map[string]bool{}, map[string]bool{}, map[string]map[string]bool{}
		n.finishing, n.outbox = map[string]*time.Timer{}, map[string]*outbox{}
	}
	chat := e.ChatID
	if chat == "" {
		return
	}
	if e.Removed {
		delete(n.running, chat)
		delete(n.cancelled, chat)
		delete(n.asked, chat)
		if t := n.finishing[chat]; t != nil {
			t.Stop()
			delete(n.finishing, chat)
		}
		return
	}
	switch {
	case e.Status != nil && !e.Status.Started.IsZero():
		n.running[chat] = true
		if t := n.finishing[chat]; t != nil { // the agent went on: no "finished"
			t.Stop()
			delete(n.finishing, chat)
		}
	case e.Status != nil && n.running[chat]:
		stopped := n.cancelled[chat]
		delete(n.running, chat)
		delete(n.cancelled, chat)
		delete(n.asked, chat)
		if !stopped {
			var t *time.Timer
			t = time.AfterFunc(s.timing.finished, func() {
				n.mu.Lock()
				waited := n.finishing[chat] == t
				if waited {
					delete(n.finishing, chat)
				}
				n.mu.Unlock()
				if waited {
					s.notify(chat, "finished")
				}
			})
			n.finishing[chat] = t
		}
	case e.Item != nil && e.Item.Kind == model.Notice && e.Item.Status == "cancelled" && n.running[chat]:
		n.cancelled[chat] = true // someone stopped it: they know
	case e.Item != nil && (e.Item.Kind == model.Permission || e.Item.Kind == model.Question) && e.Item.Status == "pending":
		if n.asked[chat] == nil {
			n.asked[chat] = map[string]bool{}
		}
		if n.asked[chat][e.Item.ID] {
			return
		}
		n.asked[chat][e.Item.ID] = true
		kind := "question"
		if e.Item.Kind == model.Permission {
			kind = "permission"
		}
		s.spawn(func() { s.notify(chat, kind) }) // not under n.mu: queue takes it
	}
}

// notify pushes what happened in chatID to every device with notifications
// on, but not one connected and showing that chat.
func (s *Service) notify(chatID, kind string) {
	s.mu.Lock()
	if s.push == nil {
		s.mu.Unlock()
		return
	}
	agent := s.push.Agent
	var to []string
	for _, d := range s.devices {
		if d.Push != nil && !s.showingLocked(d.ID, chatID) {
			to = append(to, d.ID)
		}
	}
	s.mu.Unlock()
	if len(to) == 0 {
		return
	}
	title, ok := agent(chatID)
	if !ok {
		return // a side chat, or one that's gone
	}
	p := payload{Kind: kind, Agent: title, Chat: chatID, Title: title + map[string]string{
		"finished": " finished", "question": " has a question", "permission": " needs you"}[kind]}
	for _, d := range to {
		s.queue(d, p)
	}
}

// queue sends p to device, one push at a time per device: one that comes
// while another is in flight waits, replacing any already waiting.
func (s *Service) queue(device string, p payload) {
	n := &s.notes
	n.mu.Lock()
	if ob := n.outbox[device]; ob != nil {
		ob.next = &p
		n.mu.Unlock()
		return
	}
	n.outbox[device] = &outbox{}
	n.mu.Unlock()
	sending := s.spawn(func() {
		for next := &p; next != nil; {
			_ = s.send(s.ctx, device, *next) // its failure is logged
			n.mu.Lock()
			ob := n.outbox[device]
			if next = ob.next; next == nil {
				delete(n.outbox, device)
			}
			ob.next = nil
			n.mu.Unlock()
		}
	})
	if !sending {
		n.mu.Lock()
		delete(n.outbox, device)
		n.mu.Unlock()
	}
}

// spawn runs f in a goroutine Close waits for, unless the service is
// closed.
func (s *Service) spawn(f func()) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.goLocked(f)
}
