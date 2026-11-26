package pi

import (
	"bytes"
	"context"
	"io"
	"strings"
	"sync"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/pi/pitest"
	"github.com/afrase/nushi/internal/testcheck"
)

// A fork or clone starts the new session's extensions: PiG 0.8.0 runs
// their session_start once, before its answer, 0.5.3 a second time after
// it. The bridge waits for neither: each fork opens once, says what the
// extension said as often as pi did, and its next turn is its own; the
// session forked from hears none of it.
func TestForksGreetOnceOrTwice(t *testing.T) {
	shapes(t, func(t *testing.T, shape pitest.Shape) { //nolint:thelper // a test, run on each shape
		store := &pitest.Store{Sessions: t.TempDir(), Shape: shape, Greets: true}
		c := start(t, store, io.Discard)
		cwd := t.TempDir()
		s := openNew(t, c, cwd)
		prompt(t, c, s.SessionID, "first")
		prompt(t, c, s.SessionID, "second")
		before := strings.Join(c.texts(s.SessionID), " | ")
		firstReply := ""
		for _, text := range c.texts(s.SessionID) {
			if strings.HasSuffix(text, ":You said: first") {
				firstReply = strings.Split(text, ":")[1]
			}
		}
		ctx := context.Background()
		after, err := c.ForkSession(ctx, &acp.ForkSessionRequest{SessionID: s.SessionID, Cwd: cwd,
			Meta: Harness{Flavor: PiG}.ForkAt(&acp.InitializeResponse{AgentInfo: &acp.Implementation{Name: PiG.AgentName()}})(firstReply)})
		testcheck.NoErr(t, err)
		whole, err := c.ForkSession(ctx, &acp.ForkSessionRequest{SessionID: s.SessionID, Cwd: cwd})
		testcheck.NoErr(t, err)
		want := map[pitest.Shape]int{pitest.PiG080: 1, pitest.PiG053: 2}[shape]
		for _, f := range []acp.SessionID{after.SessionID, whole.SessionID} {
			if f == s.SessionID || after.SessionID == whole.SessionID {
				t.Fatalf("fork ids: %s, %s of %s", after.SessionID, whole.SessionID, s.SessionID)
			}
			if r := prompt(t, c, f, "again"); r.StopReason != "end_turn" { // after every event pi sent before it
				t.Errorf("%s: stop = %s", f, r.StopReason)
			}
			texts := c.texts(f)
			if got := strings.Count(strings.Join(texts, "\n"), "Started (fork)"); got != want {
				t.Errorf("%s: %d greetings, want %d: %q", f, got, want, texts)
			}
			if last := texts[len(texts)-1]; !strings.HasSuffix(last, ":You said: again") {
				t.Errorf("%s: last = %q", f, last)
			}
		}
		if got := strings.Join(c.texts(s.SessionID), " | "); got != before {
			t.Errorf("the source heard the forks: %s", got)
		}
	})
}

// A Stop with a steer pi hasn't taken: PiG 0.8.0 keeps it queued, and
// the next run would bring it in after that run's own prompt, a turn
// late; 0.5.3 brought it into the stopped run. The bridge clears pi's
// queue once the stop settled, and answers a steer that comes back as
// not taken (promptRequired), so the chat puts it back in its queue as
// unsent; one pi took is injected. Either way the next turn's model
// reads its prompt alone, and a reload replays only what reached it.
func TestStopWithASteerQueued(t *testing.T) {
	shapes(t, func(t *testing.T, shape pitest.Shape) { //nolint:thelper // a test, run on each shape
		store := &pitest.Store{Sessions: t.TempDir(), Waiting: make(chan string), Steered: make(chan string), Shape: shape}
		c := start(t, store, io.Discard)
		cwd := t.TempDir()
		s := openNew(t, c, cwd)
		wait := begin(t, c, store, s.SessionID, "hold")
		t.Cleanup(func() { _ = c.Cancel(context.Background(), &acp.CancelNotification{SessionID: s.SessionID}) }) // a failed wait leaves no run behind
		ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
		defer cancel()
		type steered struct {
			ok  bool
			err error
		}
		answer := make(chan steered, 1)
		go func() {
			ok, err := c.Steer(ctx, s.SessionID, []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "turn left"}}})
			answer <- steered{ok, err}
		}()
		next(ctx, t, store.Steered, "the steer queued in pi")
		testcheck.NoErr(t, c.Cancel(ctx, &acp.CancelNotification{SessionID: s.SessionID}))
		if r := wait(); r.StopReason != "cancelled" {
			t.Errorf("stop = %s", r.StopReason)
		}
		took := shape == pitest.PiG053
		if a := next(ctx, t, answer, "the steer's answer"); a.ok != took || a.err != nil {
			t.Errorf("steer = %v, %v; want taken %v", a.ok, a.err, took)
		}
		if r := prompt(t, c, s.SessionID, "hello"); r.StopReason != "end_turn" {
			t.Errorf("next = %s", r.StopReason)
		}
		if texts := c.texts(s.SessionID); !strings.HasSuffix(texts[len(texts)-1], ":You said: hello") {
			t.Errorf("texts = %q, want the model to have read hello alone", texts)
		}
		c2 := start(t, store, io.Discard)
		_, err := c2.LoadSession(ctx, &acp.LoadSessionRequest{SessionID: s.SessionID, Cwd: cwd})
		testcheck.NoErr(t, err)
		replay := strings.Join(c2.texts(s.SessionID), " | ")
		if got := strings.Contains(replay, "turn left"); got != took {
			t.Errorf("replay = %s; want turn left in it %v", replay, took)
		}
	})
}

// An answer cut at the model's limit ends the turn as max_tokens; the
// entry PiG appends for it (a context_edit) is no plan, and no event the
// bridge doesn't know.
func TestCutAtTheLimit(t *testing.T) {
	var log bytes.Buffer
	var mu sync.Mutex
	c := start(t, &pitest.Store{Sessions: t.TempDir()}, writerFunc(func(p []byte) (int, error) {
		mu.Lock()
		defer mu.Unlock()
		return log.Write(p)
	}))
	s := openNew(t, c, t.TempDir())
	if r := prompt(t, c, s.SessionID, "long"); r.StopReason != "max_tokens" {
		t.Errorf("stop = %s", r.StopReason)
	}
	c.mu.Lock()
	for _, n := range c.updates {
		if n.Update.Plan != nil {
			t.Errorf("a plan: %+v", n.Update.Plan)
		}
	}
	c.mu.Unlock()
	mu.Lock()
	defer mu.Unlock()
	if strings.Contains(log.String(), "doesn't know") {
		t.Errorf("log: %s", log.String())
	}
}

// A steer that reaches pi after its run settled, before the bridge has
// read the agent_settled on its way: pi queues it for the next prompt's
// run (0.8.0, and the fake's 0.5.3, as pi's queue doesn't care whether a
// run goes), where the model would read it a turn late. The turn's end
// clears it, so it is answered as not taken (promptRequired: the chat
// sends it again as a prompt of its own), the chat is told nothing of it,
// and the next turn's model reads its prompt alone.
func TestASteerJustAfterTheRunSettled(t *testing.T) {
	shapes(t, func(t *testing.T, shape pitest.Shape) { //nolint:thelper // a test, run on each shape
		store := &pitest.Store{Sessions: t.TempDir(), Shape: shape, Steered: make(chan string), Settles: make(chan chan struct{})}
		c := start(t, store, io.Discard)
		cwd := t.TempDir()
		s := openNew(t, c, cwd)
		ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
		defer cancel()
		first, err := c.StartPrompt(ctx, &acp.PromptRequest{SessionID: s.SessionID, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "first"}}}})
		testcheck.NoErr(t, err)
		settling := next(ctx, t, store.Settles, "the first run's end")
		type steered struct {
			ok  bool
			err error
		}
		answer := make(chan steered, 1)
		go func() {
			ok, err := c.Steer(ctx, s.SessionID, []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "turn left"}}})
			answer <- steered{ok, err}
		}()
		next(ctx, t, store.Steered, "the steer queued in pi")
		close(settling)
		if r, err := first(ctx); err != nil || r.StopReason != "end_turn" {
			t.Errorf("first = %+v, %v", r, err)
		}
		if a := next(ctx, t, answer, "the steer's answer"); a.ok || a.err != nil {
			t.Errorf("steer = %v, %v; want not taken", a.ok, a.err)
		}
		go func() { close(next(ctx, t, store.Settles, "the second run's end")) }()
		if r := prompt(t, c, s.SessionID, "hello"); r.StopReason != "end_turn" {
			t.Errorf("next = %s", r.StopReason)
		}
		texts := c.texts(s.SessionID)
		if !strings.HasSuffix(texts[len(texts)-1], ":You said: hello") || strings.Contains(strings.Join(texts, "\n"), "turn left") {
			t.Errorf("texts = %q, want the model to have read hello alone, and no turn left told", texts)
		}
		c2 := start(t, store, io.Discard)
		_, err = c2.LoadSession(ctx, &acp.LoadSessionRequest{SessionID: s.SessionID, Cwd: cwd})
		testcheck.NoErr(t, err)
		if replay := strings.Join(c2.texts(s.SessionID), " | "); strings.Contains(replay, "turn left") {
			t.Errorf("replay = %s, with the steer that never reached the model", replay)
		}
	})
}
