package chats

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// An awake chat holds an image its copy has as a reference (ADR 0105);
// each way an item leaves the chat must still bring its bytes, or the
// client shows a blank image and the agent gets nothing.

// refChat is a chat that keeps copies in dir.
func refChat(t *testing.T) (*Service, *fakeAgent, *chat, string) {
	t.Helper()
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	dir := filepath.Join(t.TempDir(), "transcripts")
	store, err := transcripts.Open(dir)
	testcheck.NoErr(t, err)
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}, Options{Scratch: t.TempDir(), Copies: store})
	t.Cleanup(svc.Close)
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	return svc, agent, svc.chats[id], dir
}

// imageOf is the chat's image whose bytes are data, as it holds it.
func imageOf(t *testing.T, c *chat, data []byte) model.Image {
	t.Helper()
	c.mu.Lock()
	defer c.mu.Unlock()
	hash := ImageHash(data)
	for _, it := range c.items {
		for _, img := range it.Images {
			if img.Hash == hash {
				return img
			}
		}
	}
	t.Fatalf("no image %.12s in the chat", hash)
	return model.Image{}
}

// hasBytes fails unless images are want's, each with its bytes.
func hasBytes(t *testing.T, where string, images []model.Image, want ...[]byte) {
	t.Helper()
	if len(images) != len(want) {
		t.Fatalf("%s: %d images, want %d", where, len(images), len(want))
	}
	for i := range want {
		if !bytes.Equal(images[i].Data, want[i]) {
			t.Errorf("%s: image %d is %d bytes, want its %d", where, i, len(images[i].Data), len(want[i]))
		}
	}
}

// sentImages is the images of the agent's last prompt, decoded.
func sentImages(t *testing.T, a *fakeAgent) [][]byte {
	t.Helper()
	a.mu.Lock()
	defer a.mu.Unlock()
	var out [][]byte
	for _, b := range a.prompt {
		if b.Image != nil {
			data, err := base64.StdEncoding.DecodeString(b.Image.Data)
			testcheck.NoErr(t, err)
			out = append(out, data)
		}
	}
	return out
}

// itemWith is the first of items with an image whose bytes are data.
func itemWith(t *testing.T, items []model.Item, data []byte) model.Item {
	t.Helper()
	for _, it := range items {
		for _, img := range it.Images {
			if img.Hash == ImageHash(data) {
				return it
			}
		}
	}
	t.Fatalf("no item with image %.12s", ImageHash(data))
	return model.Item{}
}

// imageTurn sends "look" with images and waits for the agent's answer.
func imageTurn(t *testing.T, svc *Service, c *chat, images ...[]byte) {
	t.Helper()
	m := model.Message{Text: "look"}
	for _, d := range images {
		m.Images = append(m.Images, model.Image{MimeType: "image/png", Data: d})
	}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, m, SendIdle))
	eventually(t, c, func() bool { return !c.busy && len(c.queue) == 0 })
}

func TestAnImageIsHeldAsAReferenceOnceItsCopyHasIt(t *testing.T) {
	svc, agent, c, _ := refChat(t)
	pasted, small, shot := pngOf(100<<10, 640, 400), []byte("a small png"), pngOf(90<<10, 320, 200)
	// The screenshot's tool call runs until the turn ends: not in the copy.
	agent.updates, agent.gate = shotUpdates("m1", "t1", shot), make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "look", Images: []model.Image{
		{MimeType: "image/png", Data: pasted}, {MimeType: "image/png", Data: small}}}, SendIdle))
	eventually(t, c, func() bool { return len(c.items) >= 3 })
	if img := imageOf(t, c, shot); !bytes.Equal(img.Data, shot) {
		t.Fatal("an image the copy hasn't yet let go of its bytes")
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
	agent.mu.Lock()
	agent.gate = nil
	agent.mu.Unlock()

	held := func(when string) {
		t.Helper()
		if img := imageOf(t, c, pasted); !img.Ref() || img.Size != int64(len(pasted)) || img.Width != 640 || img.Height != 400 {
			t.Errorf("%s: the pasted image = %v %d %dx%d, want a reference", when, img.Ref(), img.Size, img.Width, img.Height)
		}
		if img := imageOf(t, c, shot); !img.Ref() {
			t.Errorf("%s: the screenshot holds its bytes", when)
		}
		if img := imageOf(t, c, small); !bytes.Equal(img.Data, small) {
			t.Errorf("%s: the small image let go of its bytes", when)
		}
	}
	held("in the copy")

	// What a client that takes images inline gets: each read back.
	whole := func(when string) {
		t.Helper()
		snap, err := svc.Get(c.id)
		testcheck.NoErr(t, err)
		if !itemWith(t, snap.Items, pasted).Images[0].Ref() {
			t.Fatalf("%s: the snapshot's image has its bytes: the test shows nothing", when)
		}
		svc.Inline(c.id, snap.Items)
		hasBytes(t, when+": a snapshot", itemWith(t, snap.Items, pasted).Images, pasted, small)
		hasBytes(t, when+": a snapshot", itemWith(t, snap.Items, shot).Images, shot)
		part, err := svc.Recent(c.id, 1)
		testcheck.NoErr(t, err)
		page, _, err := svc.Items(c.id, part.Chat.Items[0].ID, 10)
		testcheck.NoErr(t, err)
		svc.Inline(c.id, page)
		hasBytes(t, when+": a page", itemWith(t, page, pasted).Images, pasted, small)
		for _, want := range [][]byte{pasted, shot, small} {
			img, err := svc.Image(c.id, ImageHash(want))
			if err != nil || !bytes.Equal(img.Data, want) {
				t.Errorf("%s: Image = %d bytes, %v", when, len(img.Data), err)
			}
		}
	}
	whole("awake")

	// Asleep (ADR 0103), then woken: read back from the copy, and the
	// reopen's merge with the agent's replay, as references still.
	testcheck.NoErr(t, svc.Sleep(c.id))
	whole("asleep")
	agent.updates = []acp.SessionUpdate{chunk("m2", "two")}
	turn(t, svc, c, "two")
	held("woken")
	whole("woken")
}

// A message sent again (a rewind's, a stopped turn's taken back) has its
// images' bytes, and the agent gets them.
func TestAMessageSentAgainHasItsImages(t *testing.T) {
	svc, agent, c, _ := refChat(t)
	first, second := pngOf(80<<10, 100, 100), pngOf(70<<10, 50, 50)
	agent.updates = []acp.SessionUpdate{chunk("m1", "one")}
	turn(t, svc, c, "one")
	agent.updates = []acp.SessionUpdate{chunk("m2", "ok")}
	imageTurn(t, svc, c, first)
	if !imageOf(t, c, first).Ref() {
		t.Fatal("the message's image has its bytes: the test shows nothing")
	}
	snap, err := svc.Get(c.id)
	testcheck.NoErr(t, err)
	msg, err := svc.Rewind(t.Context(), c.id, itemWith(t, snap.Items, first).ID)
	testcheck.NoErr(t, err)
	hasBytes(t, "the rewound message", msg.Images, first)
	agent.updates = []acp.SessionUpdate{chunk("m3", "ok")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, msg, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	if got := sentImages(t, agent); len(got) != 1 || !bytes.Equal(got[0], first) {
		t.Errorf("the agent got %d images again", len(got))
	}

	// Taken back from a stopped turn, once the copy has it.
	agent.updates, agent.gate = nil, make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "and this", Images: []model.Image{{MimeType: "image/png", Data: second}}}, SendIdle))
	eventually(t, c, func() bool { return c.busy })
	c.mu.Lock()
	c.copyLocked(true)
	c.mu.Unlock()
	if !imageOf(t, c, second).Ref() {
		t.Fatal("the stopped turn's image has its bytes: the test shows nothing")
	}
	m, err := svc.Stop(t.Context(), c.id, true)
	if err != nil || m == nil {
		t.Fatalf("Stop = %v, %v", m, err)
	}
	hasBytes(t, "the message taken back", m.Images, second)
}

// A fork's copy is in its own folder, so it carries its images' bytes, as
// a side chat kept as a chat does its base's.
func TestAForkCarriesItsImages(t *testing.T) {
	svc, agent, c, dir := refChat(t)
	shot := pngOf(80<<10, 100, 100)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	imageTurn(t, svc, c, shot)
	if !imageOf(t, c, shot).Ref() {
		t.Fatal("the image has its bytes: the test shows nothing")
	}
	check := func(what, id string) {
		t.Helper()
		if img := imageOf(t, svc.chats[id], shot); !img.Ref() {
			t.Errorf("%s: its image isn't held as a reference to its own copy", what)
		}
		if _, err := os.Stat(filepath.Join(dir, id, "images", ImageHash(shot))); err != nil {
			t.Errorf("%s: its copy hasn't the image: %v", what, err)
		}
		if img, err := svc.Image(id, ImageHash(shot)); err != nil || !bytes.Equal(img.Data, shot) {
			t.Errorf("%s: Image = %d bytes, %v", what, len(img.Data), err)
		}
	}
	fork, err := svc.ForkAsChat(t.Context(), c.id, "")
	testcheck.NoErr(t, err)
	check("the fork", fork)
	side, err := svc.Fork(t.Context(), c.id)
	testcheck.NoErr(t, err)
	kept, err := svc.KeepSide(t.Context(), side)
	testcheck.NoErr(t, err)
	check("the kept side chat", kept)
}

// A queued message keeps its images' bytes (it isn't in the transcript),
// and the agent gets them when it goes.
func TestAQueuedMessageKeepsItsImages(t *testing.T) {
	svc, agent, c, _ := refChat(t)
	shot := pngOf(80<<10, 100, 100)
	agent.updates, agent.gate = []acp.SessionUpdate{chunk("m1", "ok")}, make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two", Images: []model.Image{{MimeType: "image/png", Data: shot}}}, SendQueue))
	snap, err := svc.Get(c.id)
	testcheck.NoErr(t, err)
	hasBytes(t, "the queue", snap.Queue[0].Images, shot)
	agent.release()
	eventually(t, c, func() bool { return len(c.queue) == 0 }) // its turn runs
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
	if got := sentImages(t, agent); len(got) != 1 || !bytes.Equal(got[0], shot) {
		t.Errorf("the agent got %d images from the queue", len(got))
	}
}

// An image whose file in the copy is gone fails where it's needed, never
// as an image without bytes.
func TestAnImageItsCopyLostFailsVisibly(t *testing.T) {
	svc, agent, c, dir := refChat(t)
	shot := pngOf(80<<10, 100, 100)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	imageTurn(t, svc, c, shot)
	file := filepath.Join(dir, c.id, "images", ImageHash(shot))
	testcheck.NoErr(t, os.Remove(file))

	if img, err := svc.Image(c.id, ImageHash(shot)); err == nil {
		t.Errorf("Image = %d bytes, no error", len(img.Data))
	}
	snap, err := svc.Get(c.id)
	testcheck.NoErr(t, err)
	svc.Inline(c.id, snap.Items)
	msg := itemWith(t, snap.Items, shot)
	if img := msg.Images[0]; !img.Ref() {
		t.Errorf("an image not read back went as %d bytes", len(img.Data))
	}
	if _, err := svc.ForkAsChat(t.Context(), c.id, ""); err == nil {
		t.Error("forked without the image")
	}
	if _, err := svc.Rewind(t.Context(), c.id, msg.ID); err == nil || !strings.Contains(err.Error(), "images") {
		t.Errorf("Rewind = %v", err)
	}
	// Written again with an item beside it, the copy leaves the image out:
	// no empty file stands for it, and the other item is written.
	c.mu.Lock()
	reply := slices.IndexFunc(c.items, func(it model.Item) bool { return it.Kind == model.AgentMessage })
	c.items[reply].Text = "changed"
	replyID := c.items[reply].ID
	c.unsaved[msg.ID], c.unsaved[replyID] = true, true
	c.copyLocked(true)
	c.mu.Unlock()
	if _, err := os.Stat(file); err == nil {
		t.Error("written again: an image file stands for it")
	}
	items, err := c.copies.Read(c.id)
	testcheck.NoErr(t, err)
	if i := slices.IndexFunc(items, func(it model.Item) bool { return it.ID == replyID }); i < 0 || items[i].Text != "changed" {
		t.Errorf("the item beside it wasn't written: %+v", items)
	}
}

// Clearing a chat's copy reads back the images it held first, each it
// can: one whose file went costs only itself.
func TestClearingACopyKeepsTheImagesItHeld(t *testing.T) {
	svc, agent, c, dir := refChat(t)
	shot, lost := pngOf(80<<10, 100, 100), pngOf(90<<10, 100, 100)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	imageTurn(t, svc, c, lost, shot)
	testcheck.NoErr(t, os.Remove(filepath.Join(dir, c.id, "images", ImageHash(lost))))
	if n, _, err := svc.ClearCopies(t.Context(), []string{c.id}); err != nil || n != 1 {
		t.Fatalf("ClearCopies = %d, %v", n, err)
	}
	if img, err := svc.Image(c.id, ImageHash(shot)); err != nil || !bytes.Equal(img.Data, shot) {
		t.Errorf("Image after the copy went = %d bytes, %v", len(img.Data), err)
	}
}

// A side chat opened before its chat's copy was cleared is kept with its
// base's images: they were read back before the copy went.
func TestASideChatIsKeptAfterItsChatsCopyWasCleared(t *testing.T) {
	svc, agent, c, _ := refChat(t)
	shot := pngOf(80<<10, 100, 100)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	imageTurn(t, svc, c, shot)
	side, err := svc.Fork(t.Context(), c.id)
	testcheck.NoErr(t, err)
	if _, _, err := svc.ClearCopies(t.Context(), []string{c.id}); err != nil {
		t.Fatal(err)
	}
	kept, err := svc.KeepSide(t.Context(), side)
	testcheck.NoErr(t, err)
	if img, err := svc.Image(kept, ImageHash(shot)); err != nil || !bytes.Equal(img.Data, shot) {
		t.Errorf("the kept side chat's image = %d bytes, %v", len(img.Data), err)
	}
}

// A chat whose deletion failed still has its copy, and the images it
// holds by reference with it.
func TestAFailedDeleteKeepsTheImages(t *testing.T) {
	svc, agent, c, _ := refChat(t)
	shot := pngOf(80<<10, 100, 100)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	imageTurn(t, svc, c, shot)
	sessions := svc.sessions.(*memSessions)
	sessions.mu.Lock()
	sessions.deleteErr = errors.New("read-only")
	sessions.mu.Unlock()
	if err := svc.Delete(t.Context(), c.id, nil); err == nil {
		t.Fatal("deleted")
	}
	if img, err := svc.Image(c.id, ImageHash(shot)); err != nil || !bytes.Equal(img.Data, shot) {
		t.Errorf("Image after a failed delete = %d bytes, %v", len(img.Data), err)
	}
}
