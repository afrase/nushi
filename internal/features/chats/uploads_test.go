package chats

import (
	"bytes"
	"context"
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
// by its absolute path and its own name (ADR 0089).
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
	if out.Name != "spec sheet.pdf" || out.URI != "file://"+strings.ReplaceAll(outside, " ", "%20") {
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
	if len(p) != 2 || p[1].ResourceLink == nil || p[1].ResourceLink.Name != "notes.txt" {
		t.Fatalf("prompt %+v", p)
	}
	path := strings.TrimPrefix(p[1].ResourceLink.URI, "file://")
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
	pruneUploads(dir, 20)
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
		"report.pdf":         "report.pdf",
		"../../etc/passwd":   "passwd",
		`C:\Users\me\a.txt`:  "a.txt",
		"a\x00b\nc.txt":      "abc.txt",
		"":                   "file",
		"..":                 "file",
		"dir/":               "file",
		"  spaced name.md  ": "spaced name.md",
	} {
		if got := uploadName(in); got != want {
			t.Errorf("uploadName(%q) = %q, want %q", in, got, want)
		}
	}
	if got := uploadName(long); len(got) > 120 || !strings.HasSuffix(got, ".pdf") || !strings.HasPrefix(got, "é") {
		t.Errorf("a long name: %q (%d bytes)", got, len(got))
	}
}
