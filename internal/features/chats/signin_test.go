package chats

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// signInFake is fakeAgent behind a login, as Codex with none is: each of
// its processes advertises codex-acp's auth methods (and a terminal one,
// and a type acp-go doesn't know), and refuses session/new and load with
// ACP's Authentication required until authenticate has signed it in.
// authenticate waits for finish (nil signs in), or for its call to end.
type signInFake struct {
	*fakeAgent
	methods []acp.AuthMethod // advertised; nil: codexMethods

	mu       sync.Mutex
	signedIn bool
	finish   chan error    // what each authenticate waits for
	begun    chan string   // gets each authenticate's method as it begins (buffered)
	closed   chan struct{} // gets one as each process is killed (Close), in turn
	hold     chan struct{} // when set, a killed process isn't gone until it closes
	asked    []string      // the methods authenticate was asked for
}

func newSignInFake() *signInFake {
	return &signInFake{fakeAgent: &fakeAgent{}, finish: make(chan error, 1), begun: make(chan string, 4), closed: make(chan struct{}, 8)}
}

// codexMethods are codex-acp's methods, as it advertises them (api-key and
// gateway with their _meta), with ones Nushi must leave out besides.
func codexMethods(t *testing.T) []acp.AuthMethod {
	t.Helper()
	var out []acp.AuthMethod
	testcheck.NoErr(t, json.Unmarshal([]byte(`[
		{"id":"api-key","name":"API Key","_meta":{"api-key":{"provider":"openai"}}},
		{"id":"chat-gpt","name":"ChatGPT","description":"Use ChatGPT to authenticate"},
		{"id":"chat-gpt-device-code","name":"ChatGPT (device code)"},
		{"id":"gateway","name":"Custom model gateway","_meta":{"gateway":{"protocol":"openai"}}},
		{"id":"key-env","name":"Key","_meta":{"api-key":{}}},
		{"type":"terminal","id":"tui","name":"In a terminal"},
		{"type":"env_var","id":"env","name":"From the environment"}
	]`), &out))
	return out
}

// kindFor is the fake's Kind: its processes are signInProcs.
func (f *signInFake) kindFor(noSignIn ...string) Kind {
	return Kind{Harness: model.HarnessInfo{Name: "fake", Title: "Fake"}, NoSignIn: noSignIn, Launch: func(h acp.Client, log *slog.Logger) (Agent, error) {
		a, err := f.launch(h, log)
		if err != nil {
			return nil, err
		}
		return &signInProc{proc: a.(*proc), f: f}, nil
	}}
}

// signInProc is one of the fake's processes.
type signInProc struct {
	*proc
	f *signInFake
}

func (p *signInProc) Initialize(ctx context.Context, req *acp.InitializeRequest) (*acp.InitializeResponse, error) {
	resp, err := p.proc.Initialize(ctx, req)
	if err == nil {
		resp.AuthMethods = p.f.methods
	}
	return resp, err
}

func (p *signInProc) refused() error {
	p.f.mu.Lock()
	defer p.f.mu.Unlock()
	if p.f.signedIn {
		return nil
	}
	return &acp.Error{Code: acp.ErrorCodeAuthenticationRequired, Message: "Authentication required"}
}

func (p *signInProc) NewSession(ctx context.Context, req *acp.NewSessionRequest) (*acp.NewSessionResponse, error) {
	if err := p.refused(); err != nil {
		return nil, err
	}
	return p.proc.NewSession(ctx, req)
}

func (p *signInProc) LoadSession(ctx context.Context, req *acp.LoadSessionRequest) (*acp.LoadSessionResponse, error) {
	if err := p.refused(); err != nil {
		return nil, err
	}
	return p.proc.LoadSession(ctx, req)
}

func (p *signInProc) Authenticate(ctx context.Context, req *acp.AuthenticateRequest) (*acp.AuthenticateResponse, error) {
	p.f.mu.Lock()
	p.f.asked = append(p.f.asked, string(req.MethodID))
	p.f.mu.Unlock()
	p.f.begun <- string(req.MethodID)
	select {
	case err := <-p.f.finish:
		if err != nil {
			return nil, err
		}
		p.f.mu.Lock()
		p.f.signedIn = true
		p.f.mu.Unlock()
		return &acp.AuthenticateResponse{}, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func (p *signInProc) Close() error {
	p.f.closed <- struct{}{}
	if p.f.hold != nil {
		<-p.f.hold
	}
	return p.proc.Close()
}

func (f *signInFake) signOut() {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.signedIn = false
}

// A new chat whose agent isn't signed in fails to start, saying the ways
// to sign in Nushi can run: the agent's own, none taking a key or needing
// what Nushi can't show (NoSignIn).
func TestStartWantsSignIn(t *testing.T) {
	f := newSignInFake()
	f.methods = codexMethods(t)
	svc := newService(t, []Kind{f.kindFor("chat-gpt-device-code")}, Options{})
	_, err := svc.Start(t.Context(), "", t.TempDir(), false)
	in, ok := errors.AsType[*SignInError](err)
	if !errors.Is(err, ErrStart) || !ok || in.Agent != "fake" {
		t.Fatalf("Start = %v", err)
	}
	if want := []model.Option{{ID: "chat-gpt", Name: "ChatGPT", Description: "Use ChatGPT to authenticate"}}; !slices.Equal(in.Methods, want) {
		t.Errorf("methods %+v, want %+v", in.Methods, want)
	}
	// None it can run: the plain error, as before.
	f.methods = f.methods[:1]
	if _, err := svc.Start(t.Context(), "", t.TempDir(), false); errors.As(err, new(*SignInError)) || !authRequired(err) {
		t.Errorf("Start with only a key's method = %v", err)
	}
}

// A sleeping chat whose agent signed out says so as it wakes for a
// message, which stays queued; once signed in (SignIn), the chat reopens
// when shown and the message goes.
func TestWakeWantsSignIn(t *testing.T) {
	f := newSignInFake()
	f.methods = codexMethods(t)
	f.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	f.signedIn = true
	svc := newService(t, []Kind{f.kindFor("chat-gpt-device-code")}, Options{})
	c := startChat(t, svc, t.TempDir())
	turn(t, svc, c, "one")
	testcheck.NoErr(t, svc.Sleep(c.id))
	f.signOut()
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendIdle))
	eventually(t, c, func() bool { f := c.failureLocked(); return f != nil && wantsSignIn(*f) })
	c.mu.Lock()
	notice, queued := *c.failureLocked(), len(c.queue)
	c.mu.Unlock()
	if len(notice.Options) != 1 || notice.Options[0].ID != "chat-gpt" || !strings.Contains(notice.Text, "Authentication required") || queued != 1 {
		t.Fatalf("notice %+v, %d queued", notice, queued)
	}

	f.finish <- nil
	testcheck.NoErr(t, svc.SignIn(t.Context(), "fake", "chat-gpt"))
	testcheck.NoErr(t, svc.Reopen(c.id))
	eventually(t, c, func() bool { return c.agent != nil && len(c.queue) == 0 && !c.busy })
	f.fakeAgent.mu.Lock()
	prompts := slices.Clone(f.prompts)
	f.fakeAgent.mu.Unlock()
	if !slices.Equal(prompts, []string{"one", "two"}) || !slices.Contains(texts(c), "user:two") {
		t.Errorf("after signing in: prompts %q, %q", prompts, texts(c))
	}
}

// SignIn runs the method in a process of its own, closed once the agent
// has answered, whichever way: signed in, or its error in plain words.
func TestSignIn(t *testing.T) {
	f := newSignInFake()
	f.methods = codexMethods(t)
	svc := newService(t, []Kind{f.kindFor("chat-gpt-device-code")}, Options{})

	f.finish <- &acp.Error{Code: acp.ErrorCodeAuthenticationRequired, Message: "Sign-in did not complete"}
	if err := svc.SignIn(t.Context(), "fake", "chat-gpt"); err == nil || err.Error() != "Fake didn't sign in: Sign-in did not complete" {
		t.Errorf("a failed sign-in = %v", err)
	}
	<-f.closed

	f.finish <- nil
	testcheck.NoErr(t, svc.SignIn(t.Context(), "fake", "chat-gpt"))
	<-f.closed
	if _, err := svc.Start(t.Context(), "", t.TempDir(), false); err != nil {
		t.Errorf("Start once signed in = %v", err)
	}

	// Only a method it offers, and Nushi runs: never a key's.
	for _, m := range []string{"api-key", "gateway", "chat-gpt-device-code", "tui", "nope"} {
		if err := svc.SignIn(t.Context(), "fake", m); err == nil || !strings.Contains(err.Error(), "doesn't offer that way") {
			t.Errorf("SignIn %s = %v", m, err)
		}
		<-f.closed
	}
	if err := svc.SignIn(t.Context(), "other", "chat-gpt"); err == nil {
		t.Error("an unknown agent signed in")
	}
	if !slices.Equal(f.asked, []string{"chat-gpt", "chat-gpt"}) {
		t.Errorf("authenticate asked %v", f.asked)
	}
}

// A sign-in left waiting in the browser past SignInTimeout ends, saying
// so, and its agent, and with it the login, is stopped.
func TestSignInTimesOut(t *testing.T) {
	old := SignInTimeout
	SignInTimeout = 50 * time.Millisecond
	t.Cleanup(func() { SignInTimeout = old })
	f := newSignInFake()
	f.methods = codexMethods(t)
	svc := newService(t, []Kind{f.kindFor()}, Options{})
	err := svc.SignIn(t.Context(), "fake", "chat-gpt")
	if err == nil || err.Error() != "Fake didn't finish signing in within 50ms: context deadline exceeded" {
		t.Errorf("a sign-in that ran out of time = %v", err)
	}
	<-f.closed
	if got := minutes(10 * time.Minute); got != "10 minutes" {
		t.Errorf("minutes(10m) = %q", got)
	}
}

// A sign-in whose call ends (the app cancelled, or went) stops its agent,
// and with it the login; a second one of the same agent meanwhile is
// refused.
func TestSignInCancelled(t *testing.T) {
	f := newSignInFake()
	f.methods = codexMethods(t)
	svc := newService(t, []Kind{f.kindFor()}, Options{})
	ctx, cancel := context.WithCancel(t.Context())
	done := make(chan error, 1)
	go func() { done <- svc.SignIn(ctx, "fake", "chat-gpt") }()
	<-f.begun
	if err := svc.SignIn(t.Context(), "fake", "chat-gpt"); err == nil || !strings.Contains(err.Error(), "signing in already") {
		t.Errorf("a second sign-in = %v", err)
	}
	cancel()
	if err := <-done; !errors.Is(err, context.Canceled) {
		t.Errorf("a cancelled sign-in = %v", err)
	}
	<-f.closed // its process was killed
	// And the next one may run.
	f.finish <- nil
	testcheck.NoErr(t, svc.SignIn(t.Context(), "fake", "chat-gpt"))
}

// A sign-in begun while a cancelled one still stops its agent (the app's
// Cancel, then Sign in again) isn't refused: it waits for that agent to be
// gone, or for its own call to end, and then runs.
func TestSignInAfterACancelledOne(t *testing.T) {
	f := newSignInFake()
	f.methods = codexMethods(t)
	f.hold = make(chan struct{})
	svc := newService(t, []Kind{f.kindFor()}, Options{})
	ctx, cancel := context.WithCancel(t.Context())
	first := make(chan error, 1)
	go func() { first <- svc.SignIn(ctx, "fake", "chat-gpt") }()
	<-f.begun
	cancel()
	<-f.closed // its process is being killed, and isn't gone

	// One whose own call has ended gives up waiting, saying so.
	over, end := context.WithCancel(t.Context())
	end()
	if err := svc.SignIn(over, "fake", "chat-gpt"); !errors.Is(err, context.Canceled) {
		t.Errorf("a sign-in whose call ended while the cancelled one's agent stops = %v", err)
	}

	f.finish <- nil
	next := make(chan error, 1)
	go func() { next <- svc.SignIn(t.Context(), "fake", "chat-gpt") }()
	close(f.hold)
	if err := <-first; !errors.Is(err, context.Canceled) {
		t.Errorf("the cancelled sign-in = %v", err)
	}
	testcheck.NoErr(t, <-next)
	if !slices.Equal(f.asked, []string{"chat-gpt", "chat-gpt"}) {
		t.Errorf("authenticate asked %v", f.asked)
	}
}
