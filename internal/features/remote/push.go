package remote

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log/slog"
	"net/url"
	"slices"
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

// PushWait is how long one push may take.
var PushWait = 30 * time.Second

// UsePush turns notifications on: devices may subscribe, and Follow sends.
func (s *Service) UsePush(p Push) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.push = &p
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
	if err := s.setPushLocked(device, p); err != nil {
		return err
	}
	slog.Info("push subscription", "device", device, "on", p != nil)
	return nil
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

// SetView says which chat device shows ("" none); it gets no push for that
// chat while it's connected. A device's view goes with its last connection.
func (s *Service) SetView(device, chatID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if chatID == "" {
		delete(s.views, device)
	} else {
		s.views[device] = chatID
	}
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
	m := webpush.Message{Payload: body, Topic: base64.RawURLEncoding.EncodeToString(topic[:24]),
		Urgent: p.Kind != "finished", TTL: 4 * time.Hour}
	ctx, cancel := context.WithTimeout(ctx, PushWait)
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

// subjectOf is the VAPID contact: the relay's own address as https.
func subjectOf(relay string) string {
	u, err := url.Parse(relay)
	if err != nil || u.Host == "" {
		return "https://localhost"
	}
	scheme := "https"
	if u.Scheme == "ws" {
		scheme = "http"
	}
	return scheme + "://" + u.Host
}

// notifier turns chats' events into pushes: a turn that ended, and each
// permission prompt or question when it comes. It runs in Follow's
// goroutine only.
type notifier struct {
	running map[string]bool            // chats with a turn running
	asked   map[string]map[string]bool // per chat, prompts already pushed
}

// Follow sees every event (the hub's subscriber) and pushes what a device
// should hear of.
func (s *Service) Follow(e model.Event) {
	n := &s.notes
	if n.running == nil {
		n.running, n.asked = map[string]bool{}, map[string]map[string]bool{}
	}
	if e.ChatID == "" {
		return
	}
	if e.Removed {
		delete(n.running, e.ChatID)
		delete(n.asked, e.ChatID)
		return
	}
	var kind string
	switch {
	case e.Status != nil && !e.Status.Started.IsZero():
		n.running[e.ChatID] = true
	case e.Status != nil && n.running[e.ChatID]:
		delete(n.running, e.ChatID)
		delete(n.asked, e.ChatID)
		kind = "finished"
	case e.Item != nil && (e.Item.Kind == model.Permission || e.Item.Kind == model.Question) && e.Item.Status == "pending":
		if n.asked[e.ChatID] == nil {
			n.asked[e.ChatID] = map[string]bool{}
		}
		if n.asked[e.ChatID][e.Item.ID] {
			return
		}
		n.asked[e.ChatID][e.Item.ID] = true
		kind = map[bool]string{true: "permission", false: "question"}[e.Item.Kind == model.Permission]
	}
	if kind != "" {
		s.notify(e.ChatID, kind)
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
		showing := s.views[d.ID] == chatID && s.connectedLocked(d.ID)
		if d.Push != nil && !showing {
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
		go func() { _ = s.send(context.Background(), d, p) }() // its failure is logged
	}
}
