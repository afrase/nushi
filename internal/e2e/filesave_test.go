package e2e

import (
	"os"
	"path/filepath"
	"slices"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/filesave"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// The Mac's preview edits a file of the chat's: the watch gives its sum
// and says it's editable, a save over that sum writes it (the next watch
// message has the new sum) and the agent hears of it with its next
// prompt; a save over an old sum is stale, with the file as it is. A
// phone's channel can't write, nor can the Mac outside the chat's folder.
func TestTheMacEditsAFile(t *testing.T) {
	ctx := t.Context()
	history := &acptest.History{}
	d := startDaemon(t, t.TempDir(), history)
	folder := t.TempDir()
	mac, phone := open(t, d), openAt(t, d.devices)
	id := mac.start(&nushiv1.StartChatRequest{Folder: folder})
	path := filepath.Join(folder, "main.go")
	testcheck.Write(t, path, "package main\n")

	stream, err := mac.c.WatchChatFile(ctx, connect.NewRequest(&nushiv1.WatchChatFileRequest{ChatId: id, Path: "main.go"}))
	testcheck.NoErr(t, err)
	defer func() { _ = stream.Close() }()
	if !stream.Receive() {
		t.Fatal(stream.Err())
	}
	first := stream.Msg()
	if first.Sha256 != filesave.Sum([]byte("package main\n")) || !first.Editable {
		t.Fatalf("watched %+v", first)
	}

	write := func(a *app, data, base string) (*nushiv1.WriteChatFileResponse, error) {
		r, err := a.c.WriteChatFile(ctx, connect.NewRequest(&nushiv1.WriteChatFileRequest{ChatId: id, Path: "main.go", Data: []byte(data), BaseSha256: base}))
		if err != nil {
			return nil, err
		}
		return r.Msg, nil
	}
	if _, err := write(phone, "package phone\n", first.Sha256); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("the phone's write: %v", err)
	}
	r, err := write(mac, "package mine\n", first.Sha256)
	testcheck.NoErr(t, err)
	if r.GetSaved().GetSha256() != filesave.Sum([]byte("package mine\n")) {
		t.Fatalf("saved %+v", r)
	}
	if !stream.Receive() || string(stream.Msg().Data) != "package mine\n" || stream.Msg().Sha256 != r.GetSaved().GetSha256() {
		t.Errorf("the watch after the save: %+v, %v", stream.Msg(), stream.Err())
	}
	r, err = write(mac, "package late\n", first.Sha256)
	testcheck.NoErr(t, err)
	if s := r.GetStale(); s == nil || string(s.Data) != "package mine\n" {
		t.Errorf("over an old sum: %+v", r)
	}
	if b, _ := os.ReadFile(path); string(b) != "package mine\n" {
		t.Errorf("the file is %q", b)
	}
	outside := filepath.Join(t.TempDir(), "x.go")
	testcheck.Write(t, outside, "x")
	if _, err := mac.c.WriteChatFile(ctx, connect.NewRequest(&nushiv1.WriteChatFileRequest{ChatId: id, Path: outside, Data: []byte("y"), BaseSha256: filesave.Sum([]byte("x"))})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("outside the folder: %v", err)
	}

	mac.send(id, "carry on")
	mac.settled(id)
	p := history.Prompts(mac.get(id).Chat.SessionId)
	want := "[Nushi] The user edited `main.go` in Nushi since your last turn; re-read it before changing it."
	if len(p) == 0 || !slices.Contains(p[len(p)-1], want) {
		t.Errorf("prompts %q", p)
	}
}
