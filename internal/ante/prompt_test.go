package ante

import (
	"bytes"
	"context"
	"encoding/base64"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/ante/antetest"
)

// The room an image has follows Ante's budget (docs/facts/ante.md's
// Images): half of 0.9 × the limit less what's used, its text and a
// margin, in file bytes (3 a token), shared, 400 KB at most.
func TestImageRoom(t *testing.T) {
	for _, c := range []struct {
		name     string
		fill     contextUse
		chars, n int
		want     int
	}{
		{"no limit known yet", contextUse{}, 0, 1, 400_000},
		{"a fresh 1M chat", contextUse{9_600, 1_048_576}, 0, 1, 400_000},
		{"a fresh 128K chat", contextUse{9_600, 131_072}, 0, 1, (117_964 - 32_000) * 3 / 2},
		{"two images share it", contextUse{0, 131_072}, 0, 2, (117_964 - 32_000) * 3 / 2 / 2},
		{"a long text takes its part", contextUse{0, 131_072}, 40_000, 1, (117_964 - 32_000 - 10_000) * 3 / 2},
		{"after a big turn", contextUse{59_795, 131_072}, 0, 1, (117_964 - 59_795 - 16_000) * 3 / 2},
		{"a full context leaves none", contextUse{120_000, 131_072}, 0, 1, 0},
	} {
		if got := imageRoom(c.fill, c.chars, c.n); got != c.want {
			t.Errorf("%s: %d, want %d", c.name, got, c.want)
		}
	}
}

// An image that can't fit what's left of the context (the fake's limit is
// 1000 tokens) is still sent, with a note saying Ante may leave it out.
func TestImageTooBigNoted(t *testing.T) {
	store := &antetest.Store{Home: t.TempDir(), Waiting: make(chan string)}
	c := start(t, store)
	s, err := c.NewSession(t.Context(), &acp.NewSessionRequest{Cwd: "/work"})
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
	defer cancel()
	img := base64.StdEncoding.EncodeToString(screenshot(t, 300, 200, 255))
	if _, err := c.Prompt(ctx, &acp.PromptRequest{SessionID: s.SessionID, Prompt: []acp.ContentBlock{
		{Type: "text", Text: &acp.TextContent{Text: "look"}}, {Type: "image", Image: &acp.ImageContent{Data: img, MimeType: "image/png"}}}}); err != nil {
		t.Fatal(err)
	}
	texts := c.texts(s.SessionID)
	if len(texts) == 0 || !strings.HasPrefix(texts[0], "agent:images-") || !strings.Contains(texts[0], "An image is too big") {
		t.Errorf("texts %q", texts)
	}
}

// A model change asks for the context's fill again, so an image's room
// follows the new model's limit: from the fake's 1M "big" to its 1000-token
// m1, through the config option and through /model, the same image goes
// from fitting to too big.
func TestImageRoomFollowsTheModel(t *testing.T) {
	c := start(t, &antetest.Store{Home: t.TempDir()})
	s, err := c.NewSession(t.Context(), &acp.NewSessionRequest{Cwd: "/work"})
	if err != nil {
		t.Fatal(err)
	}
	sid := s.SessionID
	img := base64.StdEncoding.EncodeToString(screenshot(t, 300, 200, 255))
	notes := func(after string) int {
		t.Helper()
		ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
		defer cancel()
		if _, err := c.Prompt(ctx, &acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{
			{Type: "image", Image: &acp.ImageContent{Data: img, MimeType: "image/png"}}}}); err != nil {
			t.Fatalf("%s: %v", after, err)
		}
		n := 0
		for _, m := range c.texts(sid) {
			if strings.HasPrefix(m, "agent:images-") {
				n++
			}
		}
		return n
	}
	prompt(t, c, sid, "/model big")
	if n := notes("/model big"); n != 0 {
		t.Fatalf("on big: %d notes", n)
	}
	if _, err := c.SetSessionConfigOption(t.Context(), &acp.SetSessionConfigOptionRequest{SessionID: sid, ConfigID: "model",
		ValueID: &acp.SetSessionConfigOptionRequestValueID{Value: "m1"}}); err != nil {
		t.Fatal(err)
	}
	if n := notes("the option m1"); n != 1 {
		t.Errorf("after the option: %d notes, want 1", n)
	}
	prompt(t, c, sid, "/model big")
	prompt(t, c, sid, "a turn on big")
	if n := notes("big again"); n != 1 {
		t.Fatalf("on big again: %d notes, want still 1", n)
	}
	prompt(t, c, sid, "/model m1")
	if n := notes("/model m1"); n != 2 {
		t.Errorf("after /model: %d notes, want 2", n)
	}
}

// screenshot is a w×h PNG with enough detail not to compress away;
// alpha < 255 makes its top see-through.
func screenshot(t *testing.T, w, h int, alpha uint8) []byte {
	t.Helper()
	m := image.NewNRGBA(image.Rect(0, 0, w, h))
	seed := uint32(1)
	for y := range h {
		for x := range w {
			seed = seed*1664525 + 1013904223
			c := color.NRGBA{uint8(x / 7), uint8(y / 5), 0, 255}
			if (x/16+y/16)%4 == 0 {
				c.B = uint8(seed >> 24)
			}
			if y < h/4 {
				c.A = alpha
			}
			m.SetNRGBA(x, y, c)
		}
	}
	var b bytes.Buffer
	if err := png.Encode(&b, m); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

// A pasted image is written as Ante can take it: a big one scaled down
// under its room with its aspect kept, as JPEG, unless it has
// transparency; a small one byte for byte; one that can't fit still
// written, and counted.
func TestImagesScaledToFit(t *testing.T) {
	big, seeThrough, small := screenshot(t, 1800, 900, 255), screenshot(t, 1800, 1200, 100), screenshot(t, 300, 200, 255)
	fresh128K := contextUse{9_600, 131_072}
	room := imageRoom(fresh128K, 0, 1)
	if len(big) <= room || len(small) > room {
		t.Fatalf("the fixtures: %d and %d bytes, room %d", len(big), len(small), room)
	}
	for _, c := range []struct {
		name   string
		data   []byte
		fill   contextUse
		ext    string
		same   bool
		over   int
		long   int // the longest edge it may come out with
		aspect float64
	}{
		{"big", big, fresh128K, ".jpg", false, 0, 1568, 2},
		{"transparent", seeThrough, contextUse{9_600, 1_048_576}, ".png", false, 0, 1568, 1.5},
		{"small", small, fresh128K, ".png", true, 0, 300, 1.5},
		{"no room left", big, contextUse{120_000, 131_072}, ".jpg", false, 1, 768, 2},
	} {
		t.Run(c.name, func(t *testing.T) {
			b := &bridge{}
			t.Cleanup(func() { _ = os.RemoveAll(b.imgDir) })
			block := acp.ContentBlock{Type: "image", Image: &acp.ImageContent{Data: base64.StdEncoding.EncodeToString(c.data), MimeType: "image/png"}}
			text, over, err := flatten([]acp.ContentBlock{block}, b.images, c.fill)
			if err != nil || over != c.over {
				t.Fatalf("over %d (want %d), %v", over, c.over, err)
			}
			path := strings.TrimPrefix(text, "@")
			if filepath.Ext(path) != c.ext {
				t.Errorf("written as %s, want %s", path, c.ext)
			}
			got, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if bytes.Equal(got, c.data) != c.same {
				t.Errorf("byte for byte: %v, want %v", !c.same, c.same)
			}
			if c.over == 0 && len(got) > imageRoom(c.fill, 0, 1) {
				t.Errorf("%d bytes, over its room", len(got))
			}
			m, _, err := image.Decode(bytes.NewReader(got))
			if err != nil {
				t.Fatal(err)
			}
			w, h := m.Bounds().Dx(), m.Bounds().Dy()
			if max(w, h) > c.long || float64(w)/float64(h) < c.aspect*0.995 || float64(w)/float64(h) > c.aspect*1.005 {
				t.Errorf("%d×%d, want a long edge of %d at most and an aspect of %.2f", w, h, c.long, c.aspect)
			}
		})
	}
}
