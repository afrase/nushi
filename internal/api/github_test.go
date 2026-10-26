package api

import (
	"bytes"
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/github"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/store"
)

type lockedBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (l *lockedBuffer) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.Write(p)
}

func (l *lockedBuffer) String() string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.String()
}

type memTokens map[string][]byte

func (m memTokens) Set(account, _ string, secret []byte) error {
	m[account] = bytes.Clone(secret)
	return nil
}
func (m memTokens) Get(account string, _ bool) ([]byte, error) { return m[account], nil }
func (m memTokens) Delete(account string) error {
	delete(m, account)
	return nil
}

type memHosts struct {
	*store.Store // the cache
	hosts        []string
}

func (m *memHosts) GitHubTokenHosts() ([]string, error)   { return m.hosts, nil }
func (m *memHosts) SaveGitHubTokenHosts(h []string) error { m.hosts = h; return nil }

// TestGitHubLogsNoTokenNorText: a token pasted through the API, a refused
// one, a reply and a failed write go through at DEBUG; neither token nor
// what was written reaches the log, and the token reaches only its host.
func TestGitHubLogsNoTokenNorText(t *testing.T) {
	const good, bad, text = "ghp_MARKERGOOD0123456789", "ghp_MARKERBAD0123456789", "MARKER-TEXT-of-a-reply"
	var seen []string // where the token went
	gh := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen = append(seen, r.Host)
		body, _ := io.ReadAll(r.Body)
		switch {
		case r.Header.Get("Authorization") != "Bearer "+good:
			w.WriteHeader(http.StatusUnauthorized)
		case r.URL.Path == "/api/v3/user":
			_, _ = w.Write([]byte(`{"login":"octo"}`))
		case bytes.Contains(body, []byte("mutation Reply")):
			_, _ = w.Write([]byte(`{"data":{"addPullRequestReviewThreadReply":{"comment":{"id":"C1","body":"` + text + `"}}}}`))
		default:
			w.WriteHeader(http.StatusUnprocessableEntity)
			_, _ = w.Write([]byte(`{"message":"Validation failed: ` + text + `"}`))
		}
	}))
	defer gh.Close()
	host := strings.TrimPrefix(gh.URL, "https://")
	log := &lockedBuffer{}
	defer slog.SetDefault(slog.Default())
	slog.SetDefault(slog.New(logs.Handler(log)))
	logs.SetDebug(true)
	defer logs.SetDebug(false)

	svc := github.New(github.Deps{
		Gh:     github.Gh{Token: func(string) (string, string) { return "", "" }, Hosts: func() []string { return nil }},
		Tokens: memTokens{}, Store: &memHosts{Store: store.New(t.TempDir())},
		Open:    func(h, token string) github.Client { return githubapi.New(h, token, gh.Client().Transport) },
		NeedsOK: func(error) bool { return false },
	})
	srv := httptest.NewServer(New(Services{GitHub: svc}))
	defer srv.Close()
	c := nushiv1connect.NewNushiServiceClient(http.DefaultClient, srv.URL)
	ctx := context.Background()
	if _, err := c.AddGitHubToken(ctx, connect.NewRequest(&nushiv1.AddGitHubTokenRequest{Host: host, Token: bad})); err == nil {
		t.Fatal("a refused token was kept")
	}
	if _, err := c.AddGitHubToken(ctx, connect.NewRequest(&nushiv1.AddGitHubTokenRequest{Host: host, Token: good})); err != nil {
		t.Fatal(err)
	}
	if _, err := c.ReplyGitHubThread(ctx, connect.NewRequest(&nushiv1.ReplyGitHubThreadRequest{Host: host, Thread: "T1", Body: text})); err != nil {
		t.Fatal(err)
	}
	if _, err := c.AddGitHubComment(ctx, connect.NewRequest(&nushiv1.AddGitHubCommentRequest{Host: host, Subject: "PR_1", Body: text})); err == nil {
		t.Fatal("the comment didn't fail")
	}
	if _, err := c.ListGitHubInbox(ctx, connect.NewRequest(&nushiv1.ListGitHubInboxRequest{Host: "evil.example"})); err == nil {
		t.Fatal("an unknown host was asked")
	}
	out := log.String()
	for _, secret := range []string{good, bad, "MARKERGOOD", "MARKERBAD"} {
		if strings.Contains(out, secret) {
			t.Errorf("the log has %s:\n%s", secret, out)
		}
	}
	if strings.Contains(out, "github write failed") && !strings.Contains(out, "why=\"GitHub answered 422\"") {
		t.Errorf("a failed write's log:\n%s", out)
	}
	for _, h := range seen {
		if h != host {
			t.Errorf("a request went to %s", h)
		}
	}
	// The API's own failure line may quote GitHub's error; the feature's doesn't.
	for line := range strings.Lines(out) {
		if strings.Contains(line, text) && !strings.Contains(line, "api call failed") {
			t.Errorf("what was written is in the log: %s", line)
		}
	}
}
