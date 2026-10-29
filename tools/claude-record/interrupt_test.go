package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// hangingAgent is an agent that answers initialize, tells the test at
// $RECORD_TEST_HOOK it has, and then hangs, even after its stdin ends:
// only the recorder's SIGTERM ends it.
func hangingAgent() {
	sc := bufio.NewScanner(os.Stdin)
	if sc.Scan() {
		var m struct {
			ID json.RawMessage `json:"id"`
		}
		_ = json.Unmarshal(sc.Bytes(), &m)
		_, _ = os.Stdout.WriteString(`{"jsonrpc":"2.0","id":` + string(m.ID) + `,"result":{"protocolVersion":1}}` + "\n")
	}
	req, _ := http.NewRequestWithContext(context.Background(), http.MethodPost, os.Getenv("RECORD_TEST_HOOK"), http.NoBody)
	if resp, err := http.DefaultClient.Do(req); err == nil {
		_ = resp.Body.Close()
	}
	time.Sleep(time.Hour) // until the recorder stops it
}

// A recorder interrupted mid-run (Ctrl-C) stops at once, fails the
// scenario and keeps its old recordings, even with an agent that
// wouldn't end on its own.
func TestRecordInterrupted(t *testing.T) {
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()
	hook := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { cancel() }))
	defer hook.Close()
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	r := &recorder{tee: "claude-tee", claude: "claude", agent: []string{exe}, acp: "acp-go.jsonl",
		env: []string{"RECORD_TEST_AGENT=hang", "RECORD_TEST_HOOK=" + hook.URL}, tmp: t.TempDir(), log: slog.New(slog.DiscardHandler)}
	old := map[string]string{"cli.jsonl": "an old recording\n", "acp-go.jsonl": "an old one too\n"}
	dir := scenario(t, filepath.Join("testdata", "permission"), map[string]string{
		"client.json": `{"timeout":"1h","steps":[{"initialize":{}},{"waitFor":{"method":"never/sent"}},{"pause":"1h"}]}`,
		"cli.jsonl":   old["cli.jsonl"], "acp-go.jsonl": old["acp-go.jsonl"],
	})
	if err := r.record(ctx, dir); !errors.Is(err, context.Canceled) {
		t.Fatalf("got %v", err)
	}
	for f, want := range old {
		if b, _ := os.ReadFile(filepath.Join(dir, f)); string(b) != want {
			t.Errorf("%s is now %q", f, b)
		}
	}
}

// Once interrupted, the recorder starts no further scenario.
func TestRunInterrupted(t *testing.T) {
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	err := run(ctx, "testdata", "all", "", &recorder{tee: "claude-tee", claude: "claude", agent: []string{"false"}, acp: "acp-go.jsonl", log: slog.New(slog.DiscardHandler)})
	if !errors.Is(err, context.Canceled) {
		t.Errorf("got %v", err)
	}
}

// Every wait ends when the agent's output does, or when the recorder is
// interrupted, not at its timeout.
func TestWaitsEnd(t *testing.T) {
	waits := map[string]func(ctx context.Context, c *conn, ch <-chan msg) error{
		"await": func(ctx context.Context, c *conn, ch <-chan msg) error {
			_, err := c.await(ctx, "x", ch, time.Hour)
			return err
		},
		"first": func(ctx context.Context, c *conn, _ <-chan msg) error {
			_, _, err := c.first(ctx, "y", 0, func(int, msg) bool { return false }, time.Hour)
			return err
		},
		"request": func(ctx context.Context, c *conn, _ <-chan msg) error {
			_, err := c.request(ctx, "session/request_permission", time.Hour)
			return err
		},
		"pause": func(ctx context.Context, c *conn, _ <-chan msg) error {
			p := &player{c: c, timeout: time.Hour}
			return p.step(ctx, &step{Pause: "1h"})
		},
		"play": func(ctx context.Context, c *conn, _ <-chan msg) error {
			p := &player{c: c, timeout: time.Hour, async: map[string]<-chan msg{}}
			return p.play(ctx, []step{{WaitFor: json.RawMessage(`{"method":"never/sent"}`)}})
		},
	}
	ends := []struct {
		name string
		end  func(t *testing.T, c *conn, out io.Closer) context.Context
		want func(error) bool
	}{
		{"agent gone before", func(t *testing.T, c *conn, out io.Closer) context.Context {
			t.Helper()
			_ = out.Close()
			<-c.done
			return t.Context()
		}, func(err error) bool { return err != nil && strings.Contains(err.Error(), "the agent's output ended") }},
		{"agent gone during", func(t *testing.T, _ *conn, out io.Closer) context.Context {
			t.Helper()
			go func() { _ = out.Close() }()
			return t.Context()
		}, func(err error) bool { return err != nil && strings.Contains(err.Error(), "the agent's output ended") }},
		{"interrupted", func(t *testing.T, _ *conn, _ io.Closer) context.Context {
			t.Helper()
			ctx, cancel := context.WithCancel(t.Context())
			cancel()
			return ctx
		}, func(err error) bool { return errors.Is(err, context.Canceled) }},
	}
	for _, e := range ends {
		for name, wait := range waits {
			if name == "pause" && e.name != "interrupted" {
				continue // a pause waits for nothing of the agent's
			}
			t.Run(e.name+"/"+name, func(t *testing.T) {
				r, w := io.Pipe()
				defer w.Close() //nolint:errcheck // a pipe
				c := newConn(io.Discard, r, io.Discard)
				ch, err := c.call("x", nil)
				if err != nil {
					t.Fatal(err)
				}
				if err := wait(e.end(t, c, w), c, ch); !e.want(err) {
					t.Errorf("got %v", err)
				}
			})
		}
	}
}

// An answer that came before the agent's output ended is still awaited.
func TestAwaitAnsweredThenGone(t *testing.T) {
	r, w := io.Pipe()
	c := newConn(io.Discard, r, io.Discard)
	ch, err := c.call("x", nil)
	if err != nil {
		t.Fatal(err)
	}
	go func() {
		_, _ = io.WriteString(w, `{"jsonrpc":"2.0","id":1,"result":{"ok":true}}`+"\n")
		_ = w.Close()
	}()
	<-c.done
	m, err := c.await(t.Context(), "x", ch, time.Hour)
	if err != nil || string(m.Result) != `{"ok":true}` {
		t.Errorf("got %s, %v", m.Result, err)
	}
}
