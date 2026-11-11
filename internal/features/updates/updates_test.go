package updates

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"testing/synctest"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// prefs is the setting, kept as the store keeps it: under a lock.
type prefs struct {
	mu sync.Mutex
	on bool
}

func (p *prefs) CheckUpdates() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.on
}

func (p *prefs) SetCheckUpdates(on bool) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.on = on
	return nil
}

// events records what's published.
type events struct {
	mu  sync.Mutex
	got []model.Update
}

func (e *events) publish(ev model.Event) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.got = append(e.got, *ev.Update)
}

func (e *events) n() int {
	e.mu.Lock()
	defer e.mu.Unlock()
	return len(e.got)
}

// github is a fake GitHub whose latest release is tag, answering 304 to
// its ETag and failing while fail is set.
type github struct {
	mu     sync.Mutex
	tag    string
	fail   bool
	asked  int
	unseen int // 304s
}

func (g *github) serve(t *testing.T) *githubapi.Releases {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		g.mu.Lock()
		defer g.mu.Unlock()
		g.asked++
		etag := `"` + g.tag + `"`
		switch {
		case g.fail:
			w.WriteHeader(http.StatusServiceUnavailable)
		case r.Header.Get("If-None-Match") == etag:
			g.unseen++
			w.WriteHeader(http.StatusNotModified)
		default:
			w.Header().Set("ETag", etag)
			_, _ = w.Write([]byte(`{"tag_name": "` + g.tag + `", "published_at": "2026-10-29T01:29:31Z"}`))
		}
	}))
	t.Cleanup(srv.Close)
	return &githubapi.Releases{Repo: "afrase/nushi", Base: srv.URL}
}

func latest(r *githubapi.Releases) Latest { return r.Latest }

// A newer release is said with its page; the same, an older one, or any
// to a build that isn't a release (dev), is not, though the latest is.
func TestNewerOnly(t *testing.T) {
	g := &github{tag: "v0.1.17"}
	rel := g.serve(t)
	for _, c := range []struct{ running, want string }{
		{"0.1.16", "0.1.17"},
		{"0.1.17", ""},
		{"v0.1.18", ""},
		{"0.1.17-beta.1", "0.1.17"},
		{"", ""}, // dev
	} {
		var ev events
		s := New(latest(rel), &prefs{on: true}, c.running, "https://github.com/afrase/nushi", ev.publish)
		got, err := s.Check(t.Context())
		if err != nil || got.Version != c.want || got.Latest != "0.1.17" || got.Checked.IsZero() {
			t.Fatalf("running %q: %+v %v", c.running, got, err)
		}
		if c.want != "" && got.URL != "https://github.com/afrase/nushi/releases/tag/v0.1.17" {
			t.Fatalf("running %q: %+v", c.running, got)
		}
		if ev.n() != 1 || s.Get() != got {
			t.Fatalf("running %q: published %d, kept %+v", c.running, ev.n(), s.Get())
		}
	}
}

// A Nushi that follows beta versions (it is one, or Beta says so)
// compares with the highest version among the newest releases, a
// pre-release or not; any other, and one without Tags, with the latest
// release only.
func TestBetaVersions(t *testing.T) {
	tags := []string{"v0.29.0-beta.2", "nightly", "v0.28.1", "v0.29.0-beta.1"}
	ask := func(context.Context) (string, error) { return "v0.28.1", nil }
	yes := func() bool { return true }
	for _, c := range []struct {
		name, running string
		beta          func() bool
		tags          []string
		want          string
	}{
		{"a release", "0.28.0", nil, tags, "0.28.1"},
		{"a release, told no", "0.28.0", func() bool { return false }, tags, "0.28.1"},
		{"a release that follows them", "0.28.0", yes, tags, "0.29.0-beta.2"},
		{"a beta", "0.29.0-beta.1", nil, tags, "0.29.0-beta.2"},
		{"a beta whose release is out", "0.29.0-beta.2", nil, []string{"v0.29.0", "v0.29.0-beta.2"}, "0.29.0"},
		{"the newest beta", "0.29.0-beta.2", nil, tags, ""},
		{"no version among them", "0.28.0", yes, []string{"nightly"}, "0.28.1"},
	} {
		var ev events
		s := New(ask, &prefs{on: true}, c.running, "https://github.com/afrase/nushi", ev.publish)
		s.Beta = c.beta
		s.Tags = func(context.Context) ([]string, error) { return c.tags, nil }
		got, err := s.Check(t.Context())
		if err != nil || got.Version != c.want {
			t.Fatalf("%s: %+v %v", c.name, got, err)
		}
		if c.want == "0.29.0-beta.2" && got.URL != "https://github.com/afrase/nushi/releases/tag/v0.29.0-beta.2" {
			t.Fatalf("%s: %+v", c.name, got)
		}
	}
	var ev events
	s := New(ask, &prefs{on: true}, "0.29.0-beta.1", "https://github.com/afrase/nushi", ev.publish)
	if got, err := s.Check(t.Context()); err != nil || got.Version != "" || got.Latest != "0.28.1" {
		t.Fatalf("without Tags: %+v %v", got, err)
	}
}

// A 304 is the answer before, still newer; a failure keeps what was
// found and says so to Check now; turning the checks off forgets it.
func TestUnchangedFailedAndOff(t *testing.T) {
	g := &github{tag: "v0.2.0"}
	var ev events
	p := &prefs{on: true}
	s := New(latest(g.serve(t)), p, "0.1.16", "https://github.com/afrase/nushi", ev.publish)
	for range 2 {
		if got, err := s.Check(t.Context()); err != nil || got.Version != "0.2.0" {
			t.Fatalf("%+v %v", got, err)
		}
	}
	if g.unseen != 1 {
		t.Fatalf("304s: %d", g.unseen)
	}
	g.fail = true
	got, err := s.Check(t.Context())
	if err == nil || got.Version != "0.2.0" {
		t.Fatalf("a failure: %+v %v", got, err)
	}
	if err := s.SetOn(false); err != nil {
		t.Fatal(err)
	}
	if p.CheckUpdates() || s.Get().Version != "" || ev.got[len(ev.got)-1].Version != "" {
		t.Fatalf("off: %+v", s.Get())
	}
}

// GitHub limiting the network's requests, its pages as well as its API,
// is said to Check now in words about that, with how long to wait.
func TestLimitedSaysSo(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Retry-After", "300")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer srv.Close()
	rel := &githubapi.Releases{Repo: "afrase/nushi", Base: srv.URL, Web: srv.URL}
	var ev events
	s := New(rel.Latest, &prefs{on: true}, "0.1.16", "https://github.com/afrase/nushi", ev.publish)
	_, err := s.Check(t.Context())
	if err == nil || err.Error() != "GitHub is limiting requests from this network. Try again in about 5 minutes." || ev.n() != 0 {
		t.Fatalf("%v, published %d", err, ev.n())
	}
}

// Run checks at start and every 2 hours while on, at once when turned on,
// and not at all while off; a failure waits for the next tick.
func TestEveryTwoHours(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		var mu sync.Mutex
		asked, fail := 0, true
		ask := func(context.Context) (string, error) {
			mu.Lock()
			defer mu.Unlock()
			asked++
			if fail {
				return "", errors.New("offline")
			}
			return "v0.1.17", nil
		}
		count := func() int { mu.Lock(); defer mu.Unlock(); return asked }
		var ev events
		p := &prefs{on: true}
		s := New(ask, p, "0.1.16", "https://github.com/afrase/nushi", ev.publish)
		ctx, cancel := context.WithCancel(t.Context())
		go s.Run(ctx)
		synctest.Wait()
		if count() != 1 || ev.n() != 0 {
			t.Fatalf("at start: asked %d, published %d", count(), ev.n())
		}
		mu.Lock()
		fail = false
		mu.Unlock()
		time.Sleep(2*time.Hour - time.Second)
		synctest.Wait()
		if count() != 1 {
			t.Fatalf("before 2 hours: asked %d", count())
		}
		time.Sleep(time.Second)
		synctest.Wait()
		if count() != 2 || s.Get().Version != "0.1.17" {
			t.Fatalf("at 2 hours: asked %d, %+v", count(), s.Get())
		}
		_ = s.SetOn(false)
		time.Sleep(4 * time.Hour)
		synctest.Wait()
		if count() != 2 {
			t.Fatalf("off: asked %d", count())
		}
		_ = s.SetOn(true)
		synctest.Wait()
		if count() != 3 || s.Get().Version != "0.1.17" {
			t.Fatalf("turned on: asked %d", count())
		}
		cancel()
		synctest.Wait()
	})
}

// Turning the checks off while Run's check waits for GitHub drops what
// that check finds: no newer release comes back after Off.
func TestOffDuringACheck(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		asked, answer := make(chan struct{}), make(chan struct{})
		ask := func(context.Context) (string, error) {
			asked <- struct{}{}
			<-answer
			return "v0.1.17", nil
		}
		var ev events
		s := New(ask, &prefs{on: true}, "0.1.16", "https://github.com/afrase/nushi", ev.publish)
		ctx, cancel := context.WithCancel(t.Context())
		go s.Run(ctx)
		<-asked
		if err := s.SetOn(false); err != nil {
			t.Fatal(err)
		}
		close(answer)
		synctest.Wait()
		if s.Get().Version != "" || ev.n() != 1 || ev.got[0].Version != "" {
			t.Fatalf("off, then the check: %+v, published %+v", s.Get(), ev.got)
		}
		cancel()
		synctest.Wait()
	})
}
