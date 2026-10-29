package claudeacp

import (
	"strings"
	"sync"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/sessions"
)

// A session's title. Under an SDK claude doesn't name a session itself,
// so after each of the user's turns the agent reads the title claude
// keeps in the transcript (a /rename, or one named before); until there
// is one, it asks claude once to make one from the conversation so far
// (generate_session_title, which claude has but doesn't document) and to
// keep it. Each new title goes to the client. Nothing goes when that
// fails: a client names the session itself until it hears.

// titleText is how much of the conversation, at its end, a title is made
// from; titleMin is the least worth naming.
const (
	titleText = 1000
	titleMin  = 10
)

// titles is what a session keeps for its title.
type titles struct {
	mu     sync.Mutex
	text   string // the conversation's latest words: prompts and top-level answers
	sent   string // the title the client has
	asked  bool   // claude was asked to make one
	busy   bool   // a look is under way
	looked sync.WaitGroup
}

// heard adds words of the conversation to what a title is made from:
// the user's, and the main agent's (stream ""), not a subagent's.
func (s *session) heard(stream, text string) {
	if text == "" || stream != "" {
		return
	}
	t := &s.title
	t.mu.Lock()
	defer t.mu.Unlock()
	t.text += text + "\n"
	if n := len(t.text); n > titleText {
		t.text = strings.ToValidUTF8(t.text[n-titleText:], "")
	}
}

// titleReset is the conversation starting over (/clear): it is named
// anew.
func (s *session) titleReset() {
	t := &s.title
	t.mu.Lock()
	defer t.mu.Unlock()
	t.text, t.asked = "", false
}

// retitle looks for the session's title, after a turn of the user's, on
// a goroutine of its own: a look that is under way is enough.
func (s *session) retitle() {
	t := &s.title
	t.mu.Lock()
	if t.busy {
		t.mu.Unlock()
		return
	}
	t.busy = true
	t.looked.Add(1)
	t.mu.Unlock()
	go func() {
		defer t.looked.Done()
		title := s.findTitle()
		t.mu.Lock()
		t.busy = false
		news := title != "" && title != t.sent
		if news {
			t.sent = title
		}
		t.mu.Unlock()
		if news {
			now := time.Now().UTC().Format(time.RFC3339)
			s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "session_info_update", SessionInfoUpdate: &acp.SessionInfoUpdate{
				Title: acp.Nullable[string]{Value: &title, Present: true}, UpdatedAt: acp.Nullable[string]{Value: &now, Present: true},
			}})
		}
	}()
}

// findTitle is the title in the session's transcript, else the one claude
// makes, the first time it is asked; "" when there is none.
func (s *session) findTitle() string {
	if info, err := sessions.Get(s.a.cfg.ConfigDir, s.id, s.cwd); err == nil && info.CustomTitle != "" {
		return info.CustomTitle
	}
	t := &s.title
	t.mu.Lock()
	ask := !t.asked && len(strings.TrimSpace(t.text)) >= titleMin
	text := t.text
	if ask {
		t.asked = true
	}
	t.mu.Unlock()
	if !ask {
		return ""
	}
	var r struct {
		Title *string `json:"title"`
	}
	err := s.cs.Request(s.a.ctx, "generate_session_title", map[string]any{"description": text, "persist": true}, &r)
	if err != nil || r.Title == nil {
		s.log.Info("no title from claude", "err", err)
		return ""
	}
	return strings.TrimSpace(*r.Title)
}
