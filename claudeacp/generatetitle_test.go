package claudeacp

import (
	"encoding/json"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// titleAsks are the generate_session_title requests f answered: each's
// description and persist.
func titleAsks(t *testing.T, f *claudetest.Fake) []string {
	t.Helper()
	var out []string
	for _, l := range f.Responded() {
		if !strings.Contains(l, `"generate_session_title"`) {
			continue
		}
		var ask struct {
			Request struct {
				Description string `json:"description"`
				Persist     bool   `json:"persist"`
			} `json:"request"`
		}
		if err := json.Unmarshal([]byte(l), &ask); err != nil {
			t.Fatal(err)
		}
		persist := "persist"
		if !ask.Request.Persist {
			persist = "once"
		}
		out = append(out, persist+": "+ask.Request.Description)
	}
	return out
}

// A title for a piece of text is claude's, asked not to keep it, while a
// turn runs: the turn goes on, nothing tells the client of a session
// title, and the session is named after its own conversation later, as
// ever, not after the text.
func TestGenerateTitle(t *testing.T) {
	taken, release, done := make(chan struct{}), make(chan struct{}), make(chan struct{})
	f := started(`{}`, `" Relay restart plan "`, user("id2"), echo("id2"), signal(taken), claudetest.Do(func() { <-release }),
		assistant(`{"type":"text","text":"Sure."}`), result(names("id2")), claudetest.Send(idle), signal(done))
	p := start(t, nil, f)
	sid := p.open(t)
	w := p.prompt(t, sid, "Fix the relay")
	wait(t, taken, "the prompt taken")

	var r GenerateTitleResponse
	text := "## The plan\n\nRestart the relay without dropping a phone."
	if err := p.Call(t.Context(), GenerateTitleMethod, GenerateTitleRequest{SessionID: string(sid), Text: text}, &r); err != nil {
		t.Fatal(err)
	}
	if r.Title == nil || *r.Title != "Relay restart plan" {
		t.Fatalf("title %v", r.Title)
	}
	if got := titleAsks(t, f); len(got) != 1 || got[0] != "once: "+text {
		t.Fatalf("asked %q", got)
	}
	s, _ := p.agent.session(sid)
	s.title.mu.Lock()
	sent, asked := s.title.sent, s.title.asked
	s.title.mu.Unlock()
	if sent != "" || asked || len(p.titles()) != 0 {
		t.Fatalf("the session's title moved: sent %q, asked %v, told %q", sent, asked, p.titles())
	}

	close(release)
	if got := stopReason(w); got != string(acp.StopReasonEndTurn) {
		t.Errorf("the turn ended %s", got)
	}
	wait(t, done, "the script")
	eventually(t, "the session's own title", func() bool { return len(p.titles()) == 1 })
	if got := titleAsks(t, f); len(got) != 2 || got[1] != "persist: Fix the relay\nSure.\n" {
		t.Errorf("asked %q", got)
	}
}

// No title is an answer, not an error; a session that isn't open, or no
// text, is refused.
func TestGenerateTitleNone(t *testing.T) {
	p := start(t, nil, fake())
	sid := p.open(t)
	var r GenerateTitleResponse
	if err := p.Call(t.Context(), GenerateTitleMethod, GenerateTitleRequest{SessionID: string(sid), Text: "hello there"}, &r); err != nil || r.Title != nil {
		t.Fatalf("%v %v", r.Title, err)
	}
	for _, req := range []GenerateTitleRequest{{SessionID: "nope", Text: "x"}, {SessionID: string(sid), Text: " "}} {
		if err := p.Call(t.Context(), GenerateTitleMethod, req, &r); err == nil {
			t.Errorf("%+v answered", req)
		}
	}
}
