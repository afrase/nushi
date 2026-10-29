package claudeagent_test

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

const initRequest = `{"type":"control_request","request":{"subtype":"initialize"}}`

// answer is claude's success answer to the request Expect saw last.
func answer(payload string) claudetest.Step {
	return claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":` + payload + `}}`)
}

// start starts a session on a fake claude that answers initialize with
// {} and then plays steps.
func start(t *testing.T, o claudeagent.Options, steps ...claudetest.Step) (*claudeagent.Session, *claudetest.Fake) {
	t.Helper()
	return startWith(t, o, `{}`, steps...)
}

func startWith(t *testing.T, o claudeagent.Options, initAnswer string, steps ...claudetest.Step) (*claudeagent.Session, *claudetest.Fake) {
	t.Helper()
	f := claudetest.New(append([]claudetest.Step{claudetest.Expect(initRequest), answer(initAnswer)}, steps...)...)
	o.CLIPath, o.Env, o.Spawner = "/claude", []string{}, f.Spawn
	s, err := claudeagent.Start(context.Background(), o)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })
	return s, f
}

// finish waits for the fake to play its script and for claude's requests
// to be answered, closes the session and checks that nothing more was
// written to the fake, which exited with 0.
func finish(t *testing.T, s *claudeagent.Session, f *claudetest.Fake) {
	t.Helper()
	select {
	case <-f.Played():
	case <-f.Exited():
	case <-time.After(5 * time.Second): // a guard, not an order
		t.Error("the script didn't play through")
	}
	claudeagent.WaitHandlers(s)
	_ = s.Close()
	if err := s.Wait(); err != nil {
		t.Error(err)
	}
	if err := f.Err(); err != nil {
		t.Error(err)
	}
}

// next is the session's next message.
func next(t *testing.T, s *claudeagent.Session) claudeagent.Message {
	t.Helper()
	select {
	case m, ok := <-s.Messages():
		if !ok {
			t.Fatal("the messages ended")
		}
		return m
	case <-time.After(5 * time.Second): // a guard, not an order
		t.Fatal("no message")
	}
	return nil
}

// Initialize goes first and carries Init; claude's answer is kept, and
// one with no payload is an empty answer.
func TestStart(t *testing.T) {
	for _, tc := range []struct {
		name    string
		init    claudeagent.Init
		request string
		answer  string
		model   string
	}{
		{"init", claudeagent.Init{Title: "T", PerTaskStopAffordance: true, Extra: map[string]any{"workspaceTrust": true}},
			`{"subtype":"initialize","title":"T","perTaskStopAffordance":true,"workspaceTrust":true}`, `{"current_model":"opus"}`, "opus"},
		{"null", claudeagent.Init{}, `{"subtype":"initialize"}`, `null`, ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := claudetest.New(claudetest.Expect(`{"type":"control_request","request":`+tc.request+`}`), answer(tc.answer))
			s, err := claudeagent.Start(context.Background(), claudeagent.Options{CLIPath: "/claude", Env: []string{}, Spawner: f.Spawn, Init: tc.init})
			if err != nil {
				t.Fatal(err)
			}
			if s.Init() == nil || s.Init().CurrentModel != tc.model {
				t.Errorf("%+v", s.Init())
			}
			finish(t, s, f)
		})
	}
	if _, err := claudeagent.Start(context.Background(), claudeagent.Options{Init: claudeagent.Init{Extra: map[string]any{"title": 1}}}); err == nil {
		t.Error("started with Extra setting the title")
	}
}

// A request claude sends before initialize is written is answered only
// after it: claude takes its first stdin line for the session's start.
func TestInitializeFirst(t *testing.T) {
	f := claudetest.New(
		claudetest.Send(`{"type":"control_request","request_id":"early","request":{"subtype":"ping"}}`),
		claudetest.Expect(initRequest),
		answer(`{}`),
		claudetest.Expect(`{"type":"control_response","response":{"subtype":"error","request_id":"early"}}`),
	)
	s, err := claudeagent.Start(context.Background(), claudeagent.Options{CLIPath: "/claude", Env: []string{}, Spawner: f.Spawn})
	if err != nil {
		t.Fatal(err)
	}
	finish(t, s, f)
}

// A claude that ends before it answers initialize fails the start with
// how it ended; an error answer fails it with claude's reason.
func TestStartFails(t *testing.T) {
	for _, tc := range []struct {
		name  string
		steps []claudetest.Step
		want  string
	}{
		{"exits", []claudetest.Step{claudetest.Expect(initRequest), claudetest.Exit(1, "No conversation found with session ID: s1\n")},
			"claude ended before answering initialize: claude exited with code 1: No conversation found with session ID: s1"},
		{"refuses", []claudetest.Step{claudetest.Expect(initRequest), claudetest.Send(`{"type":"control_response","response":{"subtype":"error","request_id":"$req","error":"bad hooks"}}`)},
			"claude refused initialize: bad hooks"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := claudetest.New(tc.steps...)
			_, err := claudeagent.Start(context.Background(), claudeagent.Options{CLIPath: "/claude", Env: []string{}, Spawner: f.Spawn})
			if err == nil || !strings.HasSuffix(err.Error(), tc.want) {
				t.Fatalf("%v", err)
			}
			<-f.Exited()
		})
	}
}

// Has is the union of initialize's capabilities and every system/init's,
// and agrees with a system/init by the time it is read.
func TestCapabilities(t *testing.T) {
	s, f := startWith(t, claudeagent.Options{}, `{"capabilities":["a"]}`,
		claudetest.Send(`{"type":"system","subtype":"init","capabilities":["b"]}`),
		claudetest.Send(`{"type":"system","subtype":"init","capabilities":["c"]}`),
	)
	if _, ok := next(t, s).(*claudeagent.SystemInit); !ok || !s.Has("a") || !s.Has("b") {
		t.Error("after the first init")
	}
	if _, ok := next(t, s).(*claudeagent.SystemInit); !ok || !s.Has("a") || !s.Has("b") || !s.Has("c") || s.Has("d") {
		t.Error("after the second")
	}
	finish(t, s, f)
}
