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
	mu    sync.Mutex
	text  string // the conversation's latest words: prompts and top-level answers
	sent  string // the title the client has
	asked bool   // claude was asked to make one
	busy  bool   // a look is under way
}

// heard adds words of the conversation to what a title is made from:
// the user's, and the main agent's (stream ""), not a subagent's.
func (t *titles) heard(stream, text string) {
	if text == "" || stream != "" {
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	t.text += text + "\n"
	if n := len(t.text); n > titleText {
		t.text = strings.ToValidUTF8(t.text[n-titleText:], "")
	}
}

// reset is the conversation starting over (/clear): it is named anew.
func (t *titles) reset() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.text, t.asked = "", false
}

// look starts a look for the title: false when one is under way.
func (t *titles) look() bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.busy {
		return false
	}
	t.busy = true
	return true
}

// found ends a look that found title ("" for none): true when it is news
// to the client, which now has it.
func (t *titles) found(title string) bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.busy = false
	news := title != "" && title != t.sent
	if news {
		t.sent = title
	}
	return news
}

// toMake is the text claude makes a title from, the first time there is
// enough of it; false after, and until then.
func (t *titles) toMake() (string, bool) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.asked || len(strings.TrimSpace(t.text)) < titleMin {
		return "", false
	}
	t.asked = true
	return t.text, true
}

// retitle looks for the session's title, after a turn of the user's, on
// a goroutine of its own: a look that is under way is enough.
func (s *session) retitle() {
	if !s.title.look() {
		return
	}
	s.bg.Go(func() {
		title := s.findTitle()
		if s.title.found(title) {
			now := time.Now().UTC().Format(time.RFC3339)
			s.update(acp.SessionUpdate{SessionUpdate: "session_info_update", SessionInfoUpdate: &acp.SessionInfoUpdate{
				Title: acp.Nullable[string]{Value: &title, Present: true}, UpdatedAt: acp.Nullable[string]{Value: &now, Present: true},
			}})
		}
	})
}

// findTitle is the title in the session's transcript, else the one claude
// makes, the first time it is asked; "" when there is none.
func (s *session) findTitle() string {
	store := sessions.Store{ConfigDir: s.a.cfg.ConfigDir}
	if info, err := store.Get(s.id, s.cwd); err == nil && info.CustomTitle != "" {
		return info.CustomTitle
	}
	text, ok := s.title.toMake()
	if !ok {
		return ""
	}
	req := struct {
		Description string `json:"description"`
		Persist     bool   `json:"persist"` // claude keeps it in the transcript
	}{text, true}
	var r struct {
		Title *string `json:"title"`
	}
	err := s.cs.Request(s.a.ctx, "generate_session_title", req, &r)
	if err != nil || r.Title == nil {
		s.log.Info("no title from claude", "err", err)
		return ""
	}
	return strings.TrimSpace(*r.Title)
}
