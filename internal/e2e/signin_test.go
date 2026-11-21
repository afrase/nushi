package e2e

import (
	"context"
	"errors"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/api"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// startErr is StartChat's error for the "signin" agent, and the
// AgentSignIn it carries (nil: none).
func startErr(t *testing.T, a *app, folder string) (*connect.Error, *nushiv1.AgentSignIn) {
	t.Helper()
	_, err := a.c.StartChat(t.Context(), connect.NewRequest(&nushiv1.StartChatRequest{Agent: "signin", Folder: folder}))
	return signInErr(t, err)
}

// signInErr is a call's error, and the AgentSignIn it carries (nil: none).
func signInErr(t *testing.T, err error) (*connect.Error, *nushiv1.AgentSignIn) {
	t.Helper()
	var ce *connect.Error
	if !errors.As(err, &ce) {
		t.Fatalf("the call = %v", err)
	}
	for _, d := range ce.Details() {
		if v, err := d.Value(); err == nil {
			if in, ok := v.(*nushiv1.AgentSignIn); ok {
				return ce, in
			}
		}
	}
	return ce, nil
}

// An agent that isn't signed in: a new chat's start fails saying how
// Nushi can sign it in (its own ChatGPT sign-in, never a key's, nor the
// device code's), still as an agent start for an app that reads only that;
// SignInAgent runs the agent's login, which a cancelled call stops, and
// once it is signed in the chat starts.
func TestSignInBeforeStart(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	folder := t.TempDir()
	ce, in := startErr(t, a, folder)
	if ce.Code() != connect.CodeFailedPrecondition || ce.Meta().Get(api.ReasonHeader) != api.ReasonAgentStart || in == nil ||
		in.Agent != "signin" || len(in.Methods) != 1 || in.Methods[0].Id != "chat-gpt" || in.Methods[0].Name != "ChatGPT" {
		t.Fatalf("StartChat: %v (reason %q), sign-in %v", ce, ce.Meta().Get(api.ReasonHeader), in)
	}

	signIn := func(ctx context.Context, method string) error {
		_, err := a.c.SignInAgent(ctx, connect.NewRequest(&nushiv1.SignInAgentRequest{Agent: "signin", MethodId: method}))
		return err
	}
	if err := signIn(t.Context(), "api-key"); connect.CodeOf(err) != connect.CodeFailedPrecondition {
		t.Errorf("SignInAgent with a key's method: %v", err)
	}

	// The app gives up while the user is in the browser: the agent's
	// process ends, and the login with it.
	ctx, cancel := context.WithCancel(t.Context())
	done := make(chan error, 1)
	go func() { done <- signIn(ctx, "chat-gpt") }()
	<-d.signIn.Begun
	cancel()
	if err := <-done; connect.CodeOf(err) != connect.CodeCanceled {
		t.Errorf("a cancelled SignInAgent: %v", err)
	}
	<-d.signIn.Ended

	d.signIn.Finish <- errors.New("Sign-in did not complete")
	if err := signIn(t.Context(), "chat-gpt"); connect.CodeOf(err) != connect.CodeFailedPrecondition || err.Error() != "failed_precondition: Signin didn't sign in: Sign-in did not complete" {
		t.Fatalf("a failed SignInAgent: %v", err) // its Finish wasn't taken: the next send would wait for ever
	}
	d.signIn.Finish <- nil
	if err := signIn(t.Context(), "chat-gpt"); err != nil {
		t.Fatalf("SignInAgent: %v", err)
	}
	id := a.start(&nushiv1.StartChatRequest{Agent: "signin", Folder: folder})
	a.say(id, "hi")
}

// Opening a session of an agent that isn't signed in fails as a start
// does: with the ways to sign in, so the app offers them.
func TestSignInBeforeOpen(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	_, err := a.c.OpenAgentSession(t.Context(), connect.NewRequest(&nushiv1.OpenAgentSessionRequest{Agent: "signin", Folder: t.TempDir(), SessionId: "s-elsewhere"}))
	ce, in := signInErr(t, err)
	if ce.Code() != connect.CodeFailedPrecondition || in == nil || in.Agent != "signin" || len(in.Methods) != 1 || in.Methods[0].Id != "chat-gpt" {
		t.Fatalf("OpenAgentSession: %v, sign-in %v", ce, in)
	}
}

// A chat whose agent signed out while it slept says so as it wakes for a
// message, in a notice offering the ways to sign in; signed in, the chat
// reopens (ReopenChat) and the message goes.
func TestSignInOnWake(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	d.signIn.Finish <- nil
	must(a.c.SignInAgent(t.Context(), connect.NewRequest(&nushiv1.SignInAgentRequest{Agent: "signin", MethodId: "chat-gpt"})))
	id := a.start(&nushiv1.StartChatRequest{Agent: "signin", Folder: t.TempDir()})
	a.say(id, "one")
	must(a.c.SleepChat(t.Context(), connect.NewRequest(&nushiv1.SleepChatRequest{ChatId: id})))
	d.signIn.SignOut()

	a.send(id, "two")
	notice := a.waitFor("the sign-in notice", func(e *nushiv1.EventsResponse) bool {
		return e.ChatId == id && e.GetItem().GetItem().GetStatus() == "reopen_failed" && len(e.GetItem().GetItem().GetOptions()) > 0
	}).GetItem().GetItem()
	if o := notice.Options; len(o) != 1 || o[0].Id != "chat-gpt" || o[0].Name != "ChatGPT" {
		t.Fatalf("notice %v", notice)
	}
	if got := a.get(id); !got.Status.ReopenFailed || len(got.Queue.GetMessages()) != 1 {
		t.Fatalf("status %v, queue %v", got.Status, got.Queue)
	}

	d.signIn.Finish <- nil
	must(a.c.SignInAgent(t.Context(), connect.NewRequest(&nushiv1.SignInAgentRequest{Agent: "signin", MethodId: "chat-gpt"})))
	must(a.c.ReopenChat(t.Context(), connect.NewRequest(&nushiv1.ReopenChatRequest{ChatId: id})))
	a.waitFor("the reply to two", turnEnded(id))
	if items := a.get(id).Items; items[len(items)-1].Text != "You said: two" {
		t.Errorf("last item %v", items[len(items)-1])
	}
}
