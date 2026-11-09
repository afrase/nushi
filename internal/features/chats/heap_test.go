package chats

import (
	"crypto/rand"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"hash/crc32"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// pngOf is n bytes that are a PNG as far as its header goes (w×h), the
// rest random, as a screenshot's compressed pixels are.
func pngOf(n, w, h int) []byte {
	ihdr := make([]byte, 13)
	binary.BigEndian.PutUint32(ihdr, uint32(w)) //nolint:gosec // a test's small sizes
	binary.BigEndian.PutUint32(ihdr[4:], uint32(h))
	ihdr[8], ihdr[9] = 8, 6 // 8 bits, RGBA
	out := []byte("\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR")
	out = append(out, ihdr...)
	out = binary.BigEndian.AppendUint32(out, crc32.ChecksumIEEE(append([]byte("IHDR"), ihdr...)))
	rest := make([]byte, n-len(out))
	_, _ = rand.Read(rest)
	return append(out, rest...)
}

// liveHeap is the heap's live bytes after a collection.
func liveHeap() uint64 {
	runtime.GC() //nolint:revive // the live heap is what a collection leaves
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	return m.HeapAlloc
}

// TestAwakeChatHeap measures what an awake chat holds (ADR 0105): ADR
// 0103's synthetic chat of 5,600 items (about 20 MB of text) with 200
// screenshots of 270 KB, every item written to its copy as a turn's end
// writes it, then let go and read back as waking does. It runs only with
// NUSHI_MEASURE_HEAP set (`NUSHI_MEASURE_HEAP=1 go test -run
// TestAwakeChatHeap -v ./internal/features/chats`).
func TestAwakeChatHeap(t *testing.T) {
	if os.Getenv("NUSHI_MEASURE_HEAP") == "" {
		t.Skip("NUSHI_MEASURE_HEAP not set")
	}
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}},
		Options{Scratch: t.TempDir(), Copies: store})
	t.Cleanup(svc.Close)
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	before := liveHeap()

	const items, images, imageSize = 5600, 200, 270 << 10
	text := strings.Repeat("a line of the agent's answer, as long as most. ", 75) // ~3.6 KB
	c.mu.Lock()
	for i := range items {
		it := model.Item{ID: fmt.Sprintf("m%d", i), Kind: model.AgentMessage, Text: fmt.Sprintf("%d %s", i, text)}
		if i%(items/images) == 0 {
			png := pngOf(imageSize, 1600, 1000)
			it.Kind, it.Status, it.Title = model.ToolCall, "completed", "screenshot"
			it.Images = []model.Image{{MimeType: "image/png", Data: png, Hash: ImageHash(png)}}
		}
		c.items = append(c.items, it)
		c.unsaved[it.ID] = true
	}
	c.copyLocked(true)
	c.mu.Unlock()

	held := liveHeap() - before
	t.Logf("awake chat of %d items, %d images of %d KB: %.1f MB live heap", items, images, imageSize>>10, float64(held)/(1<<20))

	// Woken: its items let go (ADR 0103), then read back from the copy.
	c.mu.Lock()
	c.items, c.inCopy = nil, true
	c.itemsBackLocked()
	n := len(c.items)
	c.mu.Unlock()
	woken := liveHeap() - before
	t.Logf("read back from its copy (%d items): %.1f MB live heap", n, float64(woken)/(1<<20))
	runtime.KeepAlive(c)
}
