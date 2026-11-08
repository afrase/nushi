package preview

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// fakeChats is one chat, "c", with these folders and written files.
type fakeChats struct {
	roots []string
	wrote map[string]bool
}

func (f fakeChats) Roots(chat string) ([]string, error) {
	if chat != "c" {
		return nil, errors.New("no chat")
	}
	return f.roots, nil
}

func (f fakeChats) Wrote(_, path string) bool { return f.wrote[path] }

// shown is the set for f and the events it publishes.
func shown(f fakeChats) (*Set, *[]model.Event) {
	var got []model.Event
	s := New(func(e model.Event) { got = append(got, e) })
	s.UseChats(f)
	return s, &got
}

func args(path string) json.RawMessage {
	b, _ := json.Marshal(map[string]string{"path": path}) // a string
	return b
}

func TestShowsWhatThePreviewCouldOpen(t *testing.T) {
	dir := t.TempDir()
	folder, wt, notes := filepath.Join(dir, "app"), filepath.Join(dir, "wt"), filepath.Join(dir, "notes")
	testcheck.Write(t, filepath.Join(folder, "docs", "report.html"), "<h1>secret words</h1>")
	testcheck.Write(t, filepath.Join(wt, "chart.PNG"), "png")
	testcheck.Write(t, filepath.Join(notes, "plan.md"), "# plan")
	testcheck.Write(t, filepath.Join(folder, "real.svg"), "<svg/>")
	if err := os.Symlink("real.svg", filepath.Join(folder, "inside.svg")); err != nil {
		t.Fatal(err)
	}
	plan := filepath.Join(notes, "plan.md")
	s, got := shown(fakeChats{roots: []string{folder, wt}, wrote: map[string]bool{plan: true}})
	for _, path := range []string{"docs/report.html", filepath.Join(wt, "chart.PNG"), plan, "inside.svg"} {
		*got = nil
		text, err := s.Call(t.Context(), tools.Grant{Chat: "c"}, "show", args(path))
		if err != nil {
			t.Errorf("%s: %v", path, err)
			continue
		}
		if strings.Contains(text, "secret") || strings.Contains(text, filepath.Base(path)) {
			t.Errorf("%s: the answer %q carries the file", path, text)
		}
		if len(*got) != 1 || (*got)[0].ChatID != "c" || (*got)[0].Show != path || (*got)[0].Seq != 0 {
			t.Errorf("%s: events %+v", path, *got)
		}
	}
}

func TestRefusesAndSaysWhy(t *testing.T) {
	dir := t.TempDir()
	folder, secret := filepath.Join(dir, "app"), filepath.Join(dir, "secret.html")
	testcheck.Write(t, filepath.Join(folder, "main.go"), "package main")
	testcheck.Write(t, filepath.Join(folder, "program"), "binary")
	testcheck.Write(t, secret, "<h1>outside</h1>")
	if err := os.Symlink(secret, filepath.Join(folder, "out.html")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(dir, filepath.Join(folder, "up")); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(folder, "folder.md"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := syscall.Mkfifo(filepath.Join(folder, "pipe.md"), 0o600); err != nil {
		t.Fatal(err)
	}
	// A link in the agent's own folder, leaving it, however it was written.
	notes := filepath.Join(dir, "notes")
	testcheck.Write(t, filepath.Join(notes, "x.txt"), "")
	wroteLink := filepath.Join(notes, "plan.html")
	if err := os.Symlink(secret, wroteLink); err != nil {
		t.Fatal(err)
	}
	s, got := shown(fakeChats{roots: []string{folder}, wrote: map[string]bool{wroteLink: true}})
	for _, c := range []struct {
		name, path string
		want       error
	}{
		{"nothing", "", errPath},
		{"too long", strings.Repeat("a/", maxPath) + "x.md", errPath},
		{"a NUL", "a\x00.md", errPath},
		{"outside", secret, errOutside},
		{"up and out", "../secret.html", errOutside},
		{"the folder itself", folder, errOutside},
		{"code", "main.go", errType},
		{"no extension", "program", errType},
		{"a trailing slash", "plan.md/", errType},
		{"missing", "gone.md", errMissing},
		{"a folder", "folder.md", errRegular},
		{"a fifo", "pipe.md", errRegular},
		{"a link out", "out.html", errLinksOut},
		{"through a link out", "up/secret.html", errLinksOut},
		{"a written link out", wroteLink, errLinksOut},
	} {
		if _, err := s.Call(t.Context(), tools.Grant{Chat: "c"}, "show", args(c.path)); !errors.Is(err, c.want) {
			t.Errorf("%s: %v, want %v", c.name, err, c.want)
		}
	}
	for _, raw := range []string{"", "null x", `{"path":5}`, `[]`} {
		if _, err := s.Call(t.Context(), tools.Grant{Chat: "c"}, "show", json.RawMessage(raw)); !errors.Is(err, errArgs) {
			t.Errorf("arguments %q: %v", raw, err)
		}
	}
	if _, err := s.Call(t.Context(), tools.Grant{Chat: "gone"}, "show", args("a.md")); !errors.Is(err, errChat) {
		t.Errorf("a gone chat: %v", err)
	}
	if len(*got) != 0 {
		t.Errorf("a refused call told the clients: %+v", *got)
	}
}

// What the agent names reaches neither the log nor, past the check, the
// agent's answer, through the tools' service as the daemon runs it.
func TestTheLogNeverSeesThePath(t *testing.T) {
	var log bytes.Buffer
	was := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&log, nil)))
	t.Cleanup(func() { slog.SetDefault(was) })
	folder := t.TempDir()
	testcheck.Write(t, filepath.Join(folder, "name-of-a-report.md"), "# x")
	set, _ := shown(fakeChats{roots: []string{folder}})
	svc := tools.New(set)
	key := svc.Key(tools.Grant{Chat: "c", Agent: "claude"})
	if _, err := svc.Call(context.Background(), key, "show", args("name-of-a-report.md")); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{"/name-of-a-secret.md", "name-of-a-secret.exe", "name-of-a-secret.md"} {
		if _, err := svc.Call(context.Background(), key, "show", args(path)); err == nil {
			t.Fatalf("%s wasn't refused", path)
		}
	}
	if s := log.String(); strings.Contains(s, "name-of-a") || !strings.Contains(s, "tool=show") {
		t.Errorf("the log:\n%s", s)
	}
}

// Nothing in what's listed tells a harness it needn't ask.
func TestListsNoHintThatSkipsTheAsk(t *testing.T) {
	set, _ := shown(fakeChats{})
	svc := tools.New(set)
	g := tools.Grant{Chat: "c", Agent: "claude"}
	if !svc.HasTools(g) {
		t.Fatal("no tools for a chat without an issue")
	}
	list, said, err := svc.List(svc.Key(g))
	if err != nil || len(list) != 1 || list[0].Name != "show" || !strings.Contains(said, "not for routine edits") {
		t.Fatalf("%+v, %q, %v", list, said, err)
	}
	b, err := json.Marshal(list[0])
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), "finished page") || strings.Contains(strings.ToLower(string(b)), "hint") || strings.Contains(string(b), "annotations") {
		t.Errorf("listed: %s", b)
	}
}

// A url opens a browser tab for a page on this Mac's loopback, as a
// browser reads it; anything else, or a url beside a path, is refused,
// and none of it tells the clients.
func TestShowsAPageOnThisMac(t *testing.T) {
	s, got := shown(fakeChats{roots: []string{t.TempDir()}})
	call := func(raw string) (string, error) {
		return s.Call(t.Context(), tools.Grant{Chat: "c"}, "show", json.RawMessage(raw))
	}
	text, err := call(`{"url":"HTTP://LocalHost:5173/docs?q=1"}`)
	if err != nil || strings.Contains(text, "5173") {
		t.Errorf("a page: %q, %v", text, err)
	}
	if len(*got) != 1 || (*got)[0].ChatID != "c" || (*got)[0].ShowURL != "http://localhost:5173/docs?q=1" || (*got)[0].Show != "" {
		t.Errorf("events %+v", *got)
	}
	*got = nil
	for _, u := range []string{"https://example.com", "http://192.168.1.4:3000", "file:///etc/passwd", "javascript:alert(1)",
		"http://me@localhost:3000", "http://localhost.:3000", "http://127.0.0.1.nip.io", "http://local\x00host", ""} {
		raw, _ := json.Marshal(map[string]string{"url": u}) // a string
		if _, err := call(string(raw)); !errors.Is(err, errURL) {
			t.Errorf("%q: %v", u, err)
		}
	}
	for _, raw := range []string{`{}`, `{"url":"http://localhost:3000","path":"a.md"}`, `{"url":5}`} {
		if _, err := call(raw); !errors.Is(err, errArgs) {
			t.Errorf("arguments %s: %v", raw, err)
		}
	}
	if len(*got) != 0 {
		t.Errorf("a refused call told the clients: %+v", *got)
	}
}
