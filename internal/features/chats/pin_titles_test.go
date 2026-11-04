package chats

import (
	"context"
	"errors"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestPinTitle(t *testing.T) {
	for _, tc := range []struct{ text, want string }{
		{"## The plan\n\nFirst we read it.", "The plan"},
		{"Some words first.\n\n### Then a **heading** ###\n", "Then a heading"},
		{"Done: the relay restarts. Then the tests.", "Done: the relay restarts"},
		{"> **Fixed** the `login` [page](https://x.test). More.", "Fixed the login page"},
		{"- one item\n- two", "one item"},
		{"```go\n# not a heading\n```\nAfter the code!", "After the code"},
		{"The relay now restarts cleanly without dropping a paired phone or its pushes", "The relay now restarts cleanly without…"},
		{"Supercalifragilisticexpialidocious-and-then-some-more-letters", "Supercalifragilisticexpialidocious-and-t…"},
		{"```\nonly code\n```", "Message"},
		{"", "Message"},
		{"v0.3.1 is live on the Pi (nushi-relay 0.3.1). Next", "v0.3.1 is live on the Pi (nushi-relay…"},
	} {
		if got := pinTitle(tc.text); got != tc.want {
			t.Errorf("pinTitle(%q) = %q, want %q", tc.text, got, tc.want)
		}
	}
}

func TestAgentTitle(t *testing.T) {
	for _, tc := range []struct{ in, want string }{
		{`  "Relay restart plan"  `, "Relay restart plan"},
		{"Two\nlines\x07 here", "Two lines here"},
		{strings.Repeat("go on ", 15), strings.Repeat("go on ", 6) + "go…"},
		{" \n\t", ""},
	} {
		if got := agentTitle(tc.in); got != tc.want {
			t.Errorf("agentTitle(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
	long := strings.Repeat("é", titleTextRunes+10)
	if got := titleText(long); len([]rune(got)) != titleTextRunes {
		t.Errorf("titleText kept %d runes", len([]rune(got)))
	}
}

// fakeTitles makes a pin's title in the agent's place (TitleMaker): asked
// gets each text it's asked about, then it answers title or err.
type fakeTitles struct {
	title string
	err   error
	asked chan string
}

func (f fakeTitles) MessageTitle(_ context.Context, _ func(context.Context, string, any, any) error, sessionID, text string) (string, error) {
	f.asked <- sessionID + ": " + text
	return f.title, f.err
}

// titledHarness is Claude's, with a title maker of its own.
type titledHarness struct {
	testHarness
	fakeTitles
}

// pinTitles are the chat's pins' titles, in the order pinned.
func pinTitles(c *chat) []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []string
	for _, p := range c.record.Pins {
		out = append(out, p.Title)
	}
	return out
}

// A pin is titled from its message at once; the agent's title replaces
// it when it comes, even mid-turn, which goes on as it was. One the agent
// fails to make, or makes empty, leaves the message's.
func TestPinTitledByTheAgent(t *testing.T) {
	for _, tc := range []struct {
		name, title string
		err         error
		want        string
	}{
		{"made", "Relay restart plan", nil, "Relay restart plan"},
		{"failed", "", errors.New("method not found"), "The plan"},
		{"none", " ", nil, "The plan"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			agent := &fakeAgent{}
			titles := fakeTitles{title: tc.title, err: tc.err, asked: make(chan string, 1)}
			h := titledHarness{testHarness{Name: "claude", Title: "Claude"}, titles}
			svc := newService(t, []Kind{{Harness: h, Launch: agent.launch}}, Options{Scratch: t.TempDir()})
			t.Cleanup(svc.Close)
			id, err := svc.Start(t.Context(), "", t.TempDir(), false)
			testcheck.NoErr(t, err)
			c := svc.chats[id]
			answered(t, svc, agent, c, "t1", "m1")
			c.mu.Lock()
			c.items[c.indexLocked("m1")].Text = "## The plan\n\nFirst the relay."
			c.mu.Unlock()

			// The next turn runs while the pin is made and titled.
			agent.gate = make(chan struct{})
			agent.updates = []acp.SessionUpdate{chunk("m2", "working")}
			testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "t2"}, SendIdle))
			eventually(t, c, func() bool { return c.busy })
			testcheck.NoErr(t, svc.PinMessage(c.id, "m1", true))
			if got := <-titles.asked; got != "s1: ## The plan\n\nFirst the relay." {
				t.Errorf("asked %q", got)
			}
			if !testcheck.Eventually(func() bool { return strings.Join(pinTitles(c), "") == tc.want }) {
				t.Errorf("titles %q, want %q", pinTitles(c), tc.want)
			}
			eventually(t, c, func() bool { return c.busy }) // the turn runs on

			close(agent.gate)
			eventually(t, c, func() bool { return !c.busy })
			if got := shown(c); got != "user:t1 agent:m1 user:t2 agent:m2" {
				t.Errorf("shown %s", got)
			}
		})
	}
}
