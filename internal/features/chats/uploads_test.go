package chats

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// sent is the prompt the agent got last, once the chat's turn has ended.
func sent(t *testing.T, c *chat, agent *fakeAgent) []acp.ContentBlock {
	t.Helper()
	eventually(t, c, func() bool { return !c.busy })
	agent.mu.Lock()
	defer agent.mu.Unlock()
	return agent.prompt
}

// A file inside the chat's folder goes by its path there, one outside it
// by its absolute path, as its URI and as its name: omp reads only the
// name (ADR 0091).
func TestAttachedFilesAreLinks(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	outside := filepath.Join(t.TempDir(), "spec sheet.pdf")
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "read these", Files: []string{"docs/a.md", outside}}, SendIdle))
	p := sent(t, c, agent)
	if len(p) != 3 {
		t.Fatalf("prompt %+v", p)
	}
	in, out := p[1].ResourceLink, p[2].ResourceLink
	if in.Name != "docs/a.md" || in.URI != "file://"+c.record.Folder+"/docs/a.md" {
		t.Errorf("inside: %+v", in)
	}
	if out.Name != outside || out.URI != "file://"+strings.ReplaceAll(outside, " ", "%20") {
		t.Errorf("outside: %+v", out)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if it := c.items[len(c.items)-1]; it.Kind != model.UserMessage || len(it.Files) != 2 {
		t.Errorf("the transcript's message: %+v", it)
	}
}

// A device's file is saved in the chat's uploads folder and goes as a link
// to the saved copy, with its name; the chat's deletion takes the folder.
func TestUploadsAreSavedAndLinked(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	svc.uploads = t.TempDir()
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "this one", Uploads: []model.Upload{{Name: "../notes.txt", Data: []byte("hello")}}}, SendIdle))
	p := sent(t, c, agent)
	if len(p) != 2 || p[1].ResourceLink == nil || filepath.Base(p[1].ResourceLink.Name) != "notes.txt" {
		t.Fatalf("prompt %+v", p)
	}
	path := strings.TrimPrefix(p[1].ResourceLink.URI, "file://")
	if p[1].ResourceLink.Name != path {
		t.Errorf("named %q, not by its path %q", p[1].ResourceLink.Name, path)
	}
	if filepath.Dir(filepath.Dir(path)) != filepath.Join(svc.uploads, c.id) {
		t.Errorf("saved at %s, not in the chat's uploads", path)
	}
	if b, err := os.ReadFile(path); err != nil || string(b) != "hello" {
		t.Errorf("saved %q, %v", b, err)
	}
	if fi, err := os.Stat(path); err != nil || fi.Mode().Perm() != 0o600 {
		t.Errorf("mode %v, %v", fi, err)
	}
	testcheck.NoErr(t, svc.Delete(context.Background(), c.id, nil))
	if _, err := os.Stat(filepath.Join(svc.uploads, c.id)); !os.IsNotExist(err) {
		t.Errorf("the uploads stayed: %v", err)
	}
}

// Too large a file, or too many, refuses the message, saving nothing; a
// daemon without an uploads folder takes none.
func TestUploadsAreCapped(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	big := model.Message{Text: "x", Uploads: []model.Upload{{Name: "a.txt", Data: []byte("a")}, {Name: "big.bin", Data: make([]byte, MaxUpload+1)}}}
	if err := svc.Prompt(t.Context(), c.id, big, SendIdle); err == nil || !strings.Contains(err.Error(), "big.bin is too large") {
		t.Errorf("a large file: %v", err)
	} else if up, ok := errors.AsType[*UploadError](err); !ok || !up.Large {
		t.Errorf("a large file's refusal isn't an UploadError (the log names no file by it): %v", err)
	}
	svc.uploads = t.TempDir()
	many := model.Message{Text: "x", Uploads: make([]model.Upload, MaxUploads+1)}
	if err := svc.Prompt(t.Context(), c.id, many, SendIdle); err == nil {
		t.Error("too many files went")
	}
	if err := svc.Prompt(t.Context(), c.id, big, SendIdle); err == nil {
		t.Error("a large file went")
	}
	if entries, _ := os.ReadDir(svc.uploads); len(entries) != 0 {
		t.Errorf("saved %d", len(entries))
	}
}

// A chat's uploads keep the newest within the bound.
func TestUploadsKeepTheNewest(t *testing.T) {
	dir := t.TempDir()
	for i, name := range []string{"old", "mid", "new"} {
		testcheck.Write(t, filepath.Join(dir, name, name+".bin"), string(bytes.Repeat([]byte{'x'}, 10)))
		at := time.Now().Add(time.Duration(i-3) * time.Hour)
		testcheck.NoErr(t, os.Chtimes(filepath.Join(dir, name, name+".bin"), at, at))
	}
	pruneUploads(dir, 20, nil)
	entries, _ := os.ReadDir(dir)
	var left []string
	for _, e := range entries {
		left = append(left, e.Name())
	}
	if strings.Join(left, ",") != "mid,new" {
		t.Errorf("left %v", left)
	}
}

func TestUploadName(t *testing.T) {
	long := strings.Repeat("é", 100) + ".pdf"
	for in, want := range map[string]string{
		"report.pdf":                     "report.pdf",
		"../../etc/passwd":               "passwd",
		`C:\Users\me\a.txt`:              "a.txt",
		"a\x00b\nc.txt":                  "abc.txt",
		"":                               "file",
		"..":                             "file",
		"dir/":                           "file",
		"  spaced name.md  ":             "spaced name.md",
		"report\u202efdp.sh":             "reportfdp.sh",
		"a\u2066b\u2069\u200f\u061c.txt": "ab.txt",
	} {
		if got := uploadName(in); got != want {
			t.Errorf("uploadName(%q) = %q, want %q", in, got, want)
		}
	}
	if got := uploadName(long); len(got) > 120 || !strings.HasSuffix(got, ".pdf") || !strings.HasPrefix(got, "é") {
		t.Errorf("a long name: %q (%d bytes)", got, len(got))
	}
}

// A message the chat refuses saves none of its uploads: the agent is busy
// and it isn't queued, or the chat is archived.
func TestARefusedMessageSavesNoUploads(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	svc.uploads = t.TempDir()
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.started.IsZero() })
	up := model.Message{Text: "two", Uploads: []model.Upload{{Name: "a.txt", Data: []byte("secret")}}}
	if svc.Prompt(t.Context(), c.id, up, SendIdle) == nil {
		t.Fatal("a busy chat took a message without queueing it")
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
	c.mu.Lock()
	c.record.Archived = true
	c.mu.Unlock()
	if svc.Prompt(t.Context(), c.id, up, SendQueue) == nil {
		t.Fatal("an archived chat took a message")
	}
	if entries, _ := os.ReadDir(filepath.Join(svc.uploads, c.id)); len(entries) != 0 {
		t.Errorf("refused messages left %d uploads", len(entries))
	}
}

// Pruning a chat's uploads leaves those of the messages in its queue: the
// agent hasn't had them yet.
func TestPruningLeavesTheQueuesUploads(t *testing.T) {
	was := maxChatUploads
	maxChatUploads = 10
	t.Cleanup(func() { maxChatUploads = was })
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	svc.uploads = t.TempDir()
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.started.IsZero() })
	for _, name := range []string{"first.txt", "second.txt"} {
		up := model.Message{Text: name, Uploads: []model.Upload{{Name: name, Data: []byte("8 bytes!")}}}
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, up, SendQueue))
	}
	c.mu.Lock()
	queued := c.queuedUploadsLocked()
	c.mu.Unlock()
	for _, f := range queued {
		if _, err := os.Stat(f); err != nil {
			t.Errorf("a queued message's file went: %v", err)
		}
	}
	if len(queued) != 2 {
		t.Errorf("queued files %q", queued)
	}
	for n := 2; n <= 3; n++ {
		agent.release()
		eventually(t, c, func() bool { prompts, _ := agent.texts(); return len(prompts) == n })
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
}

// A terminal command's uploads go with the prompt after it, and none is
// left behind when the command's message is refused.
func TestACommandsUploads(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	svc.uploads = t.TempDir()
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.started.IsZero() })
	up := func(text string) model.Message {
		return model.Message{Text: text, Uploads: []model.Upload{{Name: "a.txt", Data: []byte("hi")}}}
	}
	if svc.Prompt(t.Context(), c.id, up("/plan now"), SendIdle) == nil {
		t.Fatal("a busy chat took the command's prompt")
	}
	if entries, _ := os.ReadDir(filepath.Join(svc.uploads, c.id)); len(entries) != 0 {
		t.Errorf("a refused command left %d uploads", len(entries))
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, up("/plan"), SendIdle))
	eventually(t, c, func() bool { prompts, _ := agent.texts(); return len(prompts) == 2 })
	agent.release()
	if p := sent(t, c, agent); len(p) != 2 || p[1].ResourceLink == nil || !strings.HasSuffix(p[1].ResourceLink.URI, "/a.txt") {
		t.Errorf("prompt %+v", p)
	}
}
