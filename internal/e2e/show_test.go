package e2e

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/features/tools"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// show calls the show tool as `nushid tools-mcp` does.
func show(t *testing.T, d *daemon, key, path string) (text string, failed bool) {
	t.Helper()
	return callTool(t, d, key, "show", map[string]string{"path": path})
}

// callTool calls a chat's tool as `nushid tools-mcp` does.
func callTool(t *testing.T, d *daemon, key, tool string, args any) (text string, failed bool) {
	t.Helper()
	body, err := json.Marshal(map[string]any{"name": tool, "arguments": args})
	testcheck.NoErr(t, err)
	req, err := http.NewRequestWithContext(t.Context(), http.MethodPost, d.toolAPI+"/tools/call", bytes.NewReader(body))
	testcheck.NoErr(t, err)
	req.Header.Set("Authorization", "Bearer "+key)
	resp, err := http.DefaultClient.Do(req)
	testcheck.NoErr(t, err)
	defer func() { _ = resp.Body.Close() }()
	var r struct {
		Text    string `json:"text"`
		IsError bool   `json:"isError"`
	}
	testcheck.NoErr(t, json.NewDecoder(resp.Body).Decode(&r))
	return r.Text, r.IsError
}

// The agent's show: the clients hear of a file the preview opens, which
// the preview then reads; the Mac and a phone alike (the phone's app
// ignores it). A refused file reaches neither, and the agent learns why.
func TestAgentShowsAFile(t *testing.T) {
	ctx := context.Background()
	dataDir, folder := t.TempDir(), t.TempDir()
	d := startDaemon(t, dataDir, &acptest.History{})
	mac, phone := open(t, d), openAt(t, d.devices)
	id := mac.start(&nushiv1.StartChatRequest{Folder: folder})
	testcheck.Write(t, filepath.Join(folder, "report.html"), "<h1>the report</h1>")
	testcheck.Write(t, filepath.Join(folder, "main.go"), "package main")
	key := d.tools.Key(tools.Grant{Chat: id, Agent: "fake"})

	text, failed := show(t, d, key, filepath.Join(dataDir, "token"))
	if !failed || !strings.Contains(text, "outside") {
		t.Errorf("outside the folder: %q, failed %v", text, failed)
	}
	if text, failed = show(t, d, key, "main.go"); !failed || !strings.Contains(text, "type of file") {
		t.Errorf("code: %q, failed %v", text, failed)
	}
	text, failed = show(t, d, key, "report.html")
	if failed || strings.Contains(text, "the report") {
		t.Errorf("the report: %q, failed %v", text, failed)
	}
	for _, a := range []*app{mac, phone} {
		e := a.waitFor("the show event", func(e *nushiv1.EventsResponse) bool { return e.GetShow() != "" })
		if e.ChatId != id || e.GetShow() != "report.html" || e.Seq != 0 {
			t.Errorf("event %+v", e)
		}
	}
	stream, err := mac.c.WatchChatFile(ctx, connect.NewRequest(&nushiv1.WatchChatFileRequest{ChatId: id, Path: "report.html"}))
	testcheck.NoErr(t, err)
	defer func() { _ = stream.Close() }()
	if !stream.Receive() || string(stream.Msg().Data) != "<h1>the report</h1>" {
		t.Errorf("the preview read %q, %v", stream.Msg().GetData(), stream.Err())
	}
}

// The Files pane's listing, on the Mac and through a phone's link alike:
// what's inside the chat's folder, never what a path leads to outside it.
func TestWatchChatFolder(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	folder := t.TempDir()
	mac, phone := open(t, d), openAt(t, d.devices)
	id := mac.start(&nushiv1.StartChatRequest{Folder: folder})
	testcheck.Write(t, filepath.Join(folder, "docs", "a.md"), "a")
	testcheck.Write(t, filepath.Join(folder, "b.txt"), "b")
	for _, a := range []*app{mac, phone} {
		stream, err := a.c.WatchChatFolder(ctx, connect.NewRequest(&nushiv1.WatchChatFolderRequest{ChatId: id, Depth: 2}))
		testcheck.NoErr(t, err)
		if !stream.Receive() {
			t.Fatalf("no listing: %v", stream.Err())
		}
		fs := stream.Msg().Folders
		if len(fs) != 2 || len(fs[0].Entries) != 2 || fs[0].Entries[0].Name != "docs" || fs[0].Entries[0].Kind != "folder" ||
			fs[1].Path != "docs" || fs[1].Entries[0].Name != "a.md" || fs[1].Entries[0].Size != 1 {
			t.Errorf("listing %v", fs)
		}
		_ = stream.Close()
		for _, p := range []string{"..", "../", "/etc", "docs/../..", ".git"} {
			stream, err := a.c.WatchChatFolder(ctx, connect.NewRequest(&nushiv1.WatchChatFolderRequest{ChatId: id, Path: p}))
			testcheck.NoErr(t, err)
			if stream.Receive() || connect.CodeOf(stream.Err()) != connect.CodeInvalidArgument {
				t.Errorf("%q: %v, %v", p, stream.Msg(), stream.Err())
			}
			_ = stream.Close()
		}
	}
}

// The agent's show of a page on this Mac: the clients hear its url, as a
// browser reads it; another machine's page reaches neither (ADR 0100).
func TestAgentShowsAPage(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	mac := open(t, d)
	id := mac.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	key := d.tools.Key(tools.Grant{Chat: id, Agent: "fake"})
	if text, failed := callTool(t, d, key, "show", map[string]string{"url": "https://example.com/"}); !failed || !strings.Contains(text, "this Mac") {
		t.Errorf("another machine's page: %q, failed %v", text, failed)
	}
	if text, failed := callTool(t, d, key, "show", map[string]string{"url": "http://LOCALHOST:5173/app"}); failed {
		t.Fatalf("a page: %q", text)
	}
	e := mac.waitFor("the show_url event", func(e *nushiv1.EventsResponse) bool { return e.GetShowUrl() != "" })
	if e.ChatId != id || e.GetShowUrl() != "http://localhost:5173/app" || e.Seq != 0 {
		t.Errorf("event %+v", e)
	}
}
