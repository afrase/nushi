package chats

import (
	"bytes"
	"context"
	"encoding/base64"
	"errors"
	"sync/atomic"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// countHashes counts the images hashed from now until the test ends.
func countHashes(t *testing.T) *atomic.Int32 {
	t.Helper()
	var n atomic.Int32
	sum := imageSum
	imageSum = func(b []byte) [32]byte { n.Add(1); return sum(b) }
	t.Cleanup(func() { imageSum = sum })
	return &n
}

// shotUpdates is a turn whose tool call's image comes in a later update,
// as a screenshot's does, then the agent's message (where a rewind forks,
// so the screenshot before it stays).
func shotUpdates(msg, call string, png []byte) []acp.SessionUpdate {
	img := acp.ContentBlock{Type: "image", Image: &acp.ImageContent{MimeType: "image/png", Data: base64.StdEncoding.EncodeToString(png)}}
	id := acp.ToolCallID(call)
	return []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: id, Title: "screenshot"}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: id,
			Content: []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: img}}}}},
		chunk(msg, "ok"),
	}
}

func TestAnImageIsHashedOnceAsItComesIn(t *testing.T) {
	pasted, first, second, other := []byte("pasted"), []byte("first shot"), []byte("second shot"), []byte("another chat's")
	pastedHash, firstHash, secondHash, otherHash := ImageHash(pasted), ImageHash(first), ImageHash(second), ImageHash(other)
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	hashes := countHashes(t)
	turn := func(text string, updates []acp.SessionUpdate, images ...model.Image) {
		t.Helper()
		agent.updates = updates
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: text, Images: images}, SendIdle))
		idle(t, c)
	}
	has := func(hash string, want []byte) {
		t.Helper()
		img, err := svc.Image(c.id, hash)
		if err != nil || !bytes.Equal(img.Data, want) {
			t.Errorf("Image(%.8s) = %q, %v; want %q", hash, img.Data, err, want)
		}
	}
	hasNot := func(chatID, hash string) {
		t.Helper()
		if img, err := svc.Image(chatID, hash); !errors.Is(err, ErrNoImage) {
			t.Errorf("Image(%.8s) = %q, %v; want ErrNoImage", hash, img.Data, err)
		}
	}

	turn("look", shotUpdates("m1", "t1", first), model.Image{MimeType: "image/png", Data: pasted})
	if n := hashes.Load(); n != 2 {
		t.Fatalf("%d hashes for the pasted image and the screenshot, want 2", n)
	}
	for range 3 {
		has(pastedHash, pasted)
		has(firstHash, first)
	}
	hasNot(c.id, secondHash)
	if n := hashes.Load(); n != 2 {
		t.Errorf("%d hashes after fetching them, want still 2", n)
	}

	// One that comes after the first fetch is found; rewinding forgets it.
	turn("again", shotUpdates("m2", "t2", second))
	has(secondHash, second)
	if n := hashes.Load(); n != 3 {
		t.Errorf("%d hashes after the second screenshot, want 3", n)
	}
	var again string
	for _, it := range c.items {
		if it.Kind == model.UserMessage && it.Text == "again" {
			again = it.ID
		}
	}
	if _, err := svc.Rewind(context.Background(), c.id, again); err != nil {
		t.Fatal(err)
	}
	hasNot(c.id, secondHash)
	has(firstHash, first)

	// Another chat's image isn't this one's (started last: the fake agent
	// sends its updates to the chat it launched last).
	c2 := startChat(t, svc, t.TempDir())
	c2.mu.Lock()
	c2.items = append(c2.items, model.Item{ID: "x", Kind: model.ToolCall, Images: []model.Image{{MimeType: "image/png", Data: other, Hash: otherHash}}})
	c2.mu.Unlock()
	hasNot(c.id, otherHash)
	if img, err := svc.Image(c2.id, otherHash); err != nil || !bytes.Equal(img.Data, other) {
		t.Errorf("the other chat's own image = %q, %v", img.Data, err)
	}
	hasNot(c2.id, firstHash)
}
