package servers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// published keeps the service's events.
type published struct {
	mu     sync.Mutex
	events []model.Event
}

func (p *published) publish(e model.Event) {
	p.mu.Lock()
	p.events = append(p.events, e)
	p.mu.Unlock()
}

// shown is the pages shown, as chat and url.
func (p *published) shown() []string {
	p.mu.Lock()
	defer p.mu.Unlock()
	var out []string
	for _, e := range p.events {
		if e.ShowURL != "" {
			out = append(out, e.ChatID+" "+e.ShowURL)
		}
	}
	return out
}

// agentTools is the tool set on s, its events kept.
func agentTools(s *Service) (*AgentTools, *published) {
	p := &published{}
	s.Publish = p.publish
	t := &AgentTools{}
	t.Use(s)
	return t, p
}

// call calls a tool for chat "c" with args as JSON.
func call(t *testing.T, set *AgentTools, tool string, args any) (string, error) {
	t.Helper()
	b, err := json.Marshal(args)
	testcheck.NoErr(t, err)
	return set.Call(t.Context(), tools.Grant{Chat: "c"}, tool, b)
}

func TestAnAgentRunsAServer(t *testing.T) {
	p := freePort(t)
	s, _, _ := setup(t, entry("web", p, "-delay", "200ms"))
	set, events := agentTools(s)
	text, err := call(t, set, "preview_list", map[string]any{})
	testcheck.NoErr(t, err)
	var list struct {
		Servers []listed `json:"servers"`
	}
	testcheck.NoErr(t, json.Unmarshal([]byte(text), &list))
	if len(list.Servers) != 1 || list.Servers[0].Name != "web" || list.Servers[0].State != Stopped || list.Servers[0].Source != ".agents/launch.json" {
		t.Fatalf("preview_list: %s", text)
	}
	url := "http://localhost:" + strconv.Itoa(p)
	text, err = call(t, set, "preview_start", map[string]string{"name": "WEB"})
	if err != nil || !strings.Contains(text, "web runs on port "+strconv.Itoa(p)) || !strings.Contains(text, url) {
		t.Fatalf("preview_start: %q, %v", text, err)
	}
	if got := events.shown(); len(got) != 1 || got[0] != "c "+url {
		t.Errorf("shown %q", got)
	}
	// A second start leaves it, and shows it again: the agent asked.
	if text, err = call(t, set, "preview_start", map[string]string{"name": "web"}); err != nil || !strings.Contains(text, "runs") {
		t.Errorf("a second preview_start: %q, %v", text, err)
	}
	text, err = call(t, set, "preview_logs", map[string]any{"name": "web", "lines": 1})
	if err != nil || !strings.Contains(text, "listening on "+strconv.Itoa(p)) || strings.Contains(text, "fakeserver starting") {
		t.Errorf("preview_logs: %q, %v", text, err)
	}
	if text, err = call(t, set, "preview_stop", map[string]string{"name": "web"}); err != nil || text != "Stopped web." {
		t.Errorf("preview_stop: %q, %v", text, err)
	}
	r := row(t, s, "web", Stopped)
	if r.LogID == "" || s.Busy() {
		t.Errorf("stopped: %+v", r)
	}
	if text, err = call(t, set, "preview_logs", map[string]string{"name": "web"}); err != nil || !strings.Contains(text, "fakeserver starting") || !strings.Contains(text, "(stopped)") {
		t.Errorf("an ended server's preview_logs: %q, %v", text, err)
	}
	if text, err = call(t, set, "preview_stop", map[string]string{"name": "web"}); err != nil || text != "web isn't running." {
		t.Errorf("preview_stop again: %q, %v", text, err)
	}
}

// What the agent sends is bounded, and a refusal is fixed text.
func TestTheAgentNamesAnEntry(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t)), `{"name": "bad name", "runtimeExecutable": "$SERVER"}`)
	set, _ := agentTools(s)
	for _, name := range []string{"", "a\x00b", strings.Repeat("a", 65), "../web", "-web", "bad name"} {
		if _, err := call(t, set, "preview_start", map[string]string{"name": name}); !errors.Is(err, errToolName) {
			t.Errorf("%q: %v", name, err)
		}
	}
	for _, tool := range []string{"preview_start", "preview_stop", "preview_logs"} {
		if _, err := call(t, set, tool, map[string]string{"name": "api"}); !errors.Is(err, errNotFound) {
			t.Errorf("%s of no entry: %v", tool, err)
		}
		if _, err := set.Call(t.Context(), tools.Grant{Chat: "c"}, tool, json.RawMessage(`{"name": 5}`)); !errors.Is(err, errToolArgs) {
			t.Errorf("%s of a number: %v", tool, err)
		}
	}
	for _, lines := range []int{0, -1, 501} {
		if _, err := call(t, set, "preview_logs", map[string]any{"name": "web", "lines": lines}); !errors.Is(err, errLines) {
			t.Errorf("%d lines: %v", lines, err)
		}
	}
	if _, err := call(t, set, "preview_logs", map[string]string{"name": "web"}); err == nil || !strings.Contains(err.Error(), "no output kept") {
		t.Errorf("logs of one that never ran: %v", err)
	}
	text, err := call(t, set, "preview_list", nil)
	if err != nil || strings.Contains(text, "bad name") || !strings.Contains(text, `"unnamed":1`) {
		t.Errorf("preview_list: %q, %v", text, err)
	}
	if s.Busy() {
		t.Error("a refused start runs")
	}
}

// The ask's card shows the command the entry runs, and the start that
// follows runs that, not what the file says since.
func TestTheCardsCommandIsWhatRuns(t *testing.T) {
	p := freePort(t)
	s, _, folder := setup(t, `{"name": "web", "runtimeExecutable": "$SERVER", "runtimeArgs": ["--port", "`+strconv.Itoa(p)+`", "it's"], "env": {"MODE": "dev x"}}`)
	set, _ := agentTools(s)
	want := "MODE='dev x' " + fakeServer + " --port " + strconv.Itoa(p) + ` 'it'\''s'`
	got, ask := s.Command("c", "WEB")
	if got != want {
		t.Errorf("Command = %q, want %q", got, want)
	}
	for _, name := range []string{"api", "", "a\x00"} {
		got, other := s.Command("c", name)
		if got != "" {
			t.Errorf("Command(%q) = %q", name, got)
		}
		s.Answered(other, false)
	}
	s.Answered(ask, true)
	launchFile(t, folder, entry("web", p, "-exit", "1"))
	_, err := call(t, set, "preview_start", map[string]string{"name": "web"})
	if err == nil || !strings.Contains(err.Error(), "changed since the permission card") {
		t.Errorf("a changed entry: %v", err)
	}
	// The ask was used: the next start (no card, say) runs the file's.
	if _, err = call(t, set, "preview_start", map[string]string{"name": "web"}); err == nil || !strings.Contains(err.Error(), "boom: can't start") {
		t.Errorf("the next start: %v", err)
	}
}

// launchFile writes a chat's folder's .agents/launch.json, of
// configurations as setup takes them.
func launchFile(t *testing.T, folder string, configurations ...string) {
	t.Helper()
	testcheck.Write(t, filepath.Join(folder, ".agents", "launch.json"),
		`{"configurations": [`+strings.ReplaceAll(strings.Join(configurations, ","), "$SERVER", fakeServer)+`]}`)
}

// Each ask holds only the start it was allowed for: two asks of one name
// keep their own entries, a refused ask holds nothing, and an ask that
// showed no entry, or no name, refuses its start whatever the file says
// by then.
func TestAnAskHoldsItsOwnStart(t *testing.T) {
	p := freePort(t)
	s, _, folder := setup(t, entry("web", p, "-exit", "1"))
	set, _ := agentTools(s)
	start := func(name string) error {
		t.Helper()
		_, err := call(t, set, "preview_start", map[string]string{"name": name})
		return err
	}
	changed := func(err error) bool {
		return err != nil && strings.Contains(err.Error(), "changed since the permission card")
	}

	// Two cards for web, the file changed between them: the first allowed
	// is refused, as its card showed what no longer runs; the second runs.
	_, first := s.Command("c", "web")
	launchFile(t, folder, entry("web", p, "-exit", "2"))
	_, second := s.Command("c", "web")
	s.Answered(first, true)
	if err := start("web"); !changed(err) {
		t.Errorf("the first card's start: %v", err)
	}
	s.Answered(second, true)
	if err := start("web"); err == nil || !strings.Contains(err.Error(), "exit code 2") {
		t.Errorf("the second card's start: %v", err)
	}

	// A refused card holds nothing: a later start (no card) runs the file's.
	_, refused := s.Command("c", "web")
	s.Answered(refused, false)
	launchFile(t, folder, entry("web", p, "-exit", "3"))
	if err := start("web"); err == nil || !strings.Contains(err.Error(), "exit code 3") {
		t.Errorf("after a refused card: %v", err)
	}

	// A card that said no entry could run, or couldn't tell which: its
	// start is refused once the file has one.
	command, none := s.Command("c", "api")
	if command != "" {
		t.Fatalf("Command(api) = %q", command)
	}
	s.Answered(none, true)
	launchFile(t, folder, entry("web", p, "-exit", "3"), entry("api", p+1, "-exit", "4"))
	if err := start("api"); !changed(err) {
		t.Errorf("a card with no entry: %v", err)
	}
	_, unnamed := s.Command("c", "")
	s.Answered(unnamed, true)
	if err := start("api"); !changed(err) {
		t.Errorf("a card with no name: %v", err)
	}
	if err := start("api"); err == nil || !strings.Contains(err.Error(), "exit code 4") {
		t.Errorf("the next start: %v", err)
	}

	// A removed chat's asks go.
	_, gone := s.Command("c", "web")
	s.Answered(gone, true)
	s.Follow(model.Event{ChatID: "c", Removed: true})
	s.mu.Lock()
	left := len(s.asks)
	s.mu.Unlock()
	if left != 0 {
		t.Errorf("%d asks left", left)
	}
}

// A failed start tells the agent why and what it printed; the log has
// fixed words alone.
func TestAFailedStartTellsTheAgent(t *testing.T) {
	var log bytes.Buffer
	was := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&log, nil)))
	t.Cleanup(func() { slog.SetDefault(was) })
	s, _, _ := setup(t, entry("web", freePort(t), "-exit", "2"), `{"name": "gone", "runtimeExecutable": "no-such-program-here"}`)
	set, _ := agentTools(s)
	svc := tools.New(set)
	key := svc.Key(tools.Grant{Chat: "c", Agent: "claude"})
	_, err := svc.Call(context.Background(), key, "preview_start", json.RawMessage(`{"name":"web"}`))
	if err == nil || !strings.Contains(err.Error(), "exit code 2") || !strings.Contains(err.Error(), "boom: can't start") {
		t.Errorf("a failed start: %v", err)
	}
	_, err = svc.Call(context.Background(), key, "preview_start", json.RawMessage(`{"name":"gone"}`))
	if err == nil || !strings.Contains(err.Error(), "no-such-program-here") {
		t.Errorf("a missing program: %v", err)
	}
	if l := log.String(); strings.Contains(l, "boom") || strings.Contains(l, "no-such-program") || !strings.Contains(l, "err=\"the server failed\"") {
		t.Errorf("the log:\n%s", l)
	}
}

// preview_start answers after StartWait for a server still starting;
// its page is shown once it answers.
func TestASlowServerIsShownOnceItAnswers(t *testing.T) {
	p := freePort(t)
	s, _, _ := setup(t, entry("web", p, "-delay", "800ms"))
	s.StartWait = 100 * time.Millisecond
	set, events := agentTools(s)
	text, err := call(t, set, "preview_start", map[string]string{"name": "web"})
	if err != nil || !strings.Contains(text, "hasn't answered yet") || len(events.shown()) != 0 {
		t.Fatalf("preview_start: %q, %v, shown %q", text, err, events.shown())
	}
	if !testcheck.Eventually(func() bool { return len(events.shown()) == 1 }) {
		t.Error("never shown")
	}
}

// The user's start shows nothing: the app opens the page it asked for.
func TestTheUsersStartShowsNothing(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t)))
	_, events := agentTools(s)
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	row(t, s, "web", Running)
	if got := events.shown(); len(got) != 0 {
		t.Errorf("shown %q", got)
	}
}

func TestQuote(t *testing.T) {
	for in, want := range map[string]string{
		"npm":         "npm",
		"--port=3000": "--port=3000",
		"":            "''",
		"a b":         "'a b'",
		"it's":        `'it'\''s'`,
		"a\nb":        `"a\nb"`,
		"ab\u202ec":   `"ab\u202ec"`,
		"naïve":       "'naïve'",
	} {
		if got := quote(in); got != want {
			t.Errorf("quote(%q) = %s, want %s", in, got, want)
		}
	}
}
