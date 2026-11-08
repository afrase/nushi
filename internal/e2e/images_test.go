package e2e

import (
	"bytes"
	"context"
	"image"
	"image/color"
	"image/png"
	"math/rand/v2"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// noisePNG is a w×h PNG of noise, which doesn't compress: about 4·w·h
// bytes.
func noisePNG(t *testing.T, w, h int) []byte {
	t.Helper()
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	r := rand.New(rand.NewPCG(1, 2)) //nolint:gosec // test pixels
	for i := range img.Pix {
		img.Pix[i] = uint8(r.UintN(256)) //nolint:gosec // below 256
	}
	img.Set(0, 0, color.Black)
	var b bytes.Buffer
	if err := png.Encode(&b, img); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

// A phone takes a chat's larger images as references and each on its own
// (ADR 0099); the Mac, which doesn't ask, gets them inline as before.
func TestImagesAsReferences(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	mac := open(t, d)
	phone := openAt(t, d.devices)
	big, small := noisePNG(t, 200, 150), noisePNG(t, 4, 4)
	if len(big) <= 64<<10 || len(small) > 64<<10 {
		t.Fatalf("sizes: %d, %d", len(big), len(small))
	}
	start := func() string {
		return must(phone.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "codex", Folder: t.TempDir()}))).ChatId
	}
	id, other := start(), start()

	// The phone's events, with references.
	evCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	stream, err := phone.c.Events(evCtx, connect.NewRequest(&nushiv1.EventsRequest{ImageRefs: true}))
	if err != nil || !stream.Receive() {
		t.Fatalf("events: %v", err)
	}
	must(phone.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "look",
		Images: []*nushiv1.ImageData{{MimeType: "image/png", Data: big}, {MimeType: "image/png", Data: small}}})))
	mac.waitFor("the reply", turnEnded(id))
	for stream.Receive() {
		if it := stream.Msg().GetItem().GetItem(); it != nil && len(it.Images) == 2 {
			checkRefs(t, "an event", it.Images, big, small)
			break
		}
	}

	// Without the flag: as before, every image whole.
	plain := mac.get(id)
	user := plain.Items[0]
	if len(user.Images) != 2 || !bytes.Equal(user.Images[0].Data, big) || !bytes.Equal(user.Images[1].Data, small) ||
		user.Images[0].Sha256 != "" || user.Images[0].Size != 0 || user.Images[0].Width != 0 {
		t.Fatalf("without image_refs: %v", user.Images)
	}

	// With it: the big one a reference, the small one inline.
	snap := must(phone.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id, Recent: 80, ImageRefs: true})))
	checkRefs(t, "GetChat", snap.Items[0].Images, big, small)
	phone.say(id, "and again")
	last := must(phone.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id, Recent: 1})))
	page := must(phone.c.GetChatItems(ctx, connect.NewRequest(&nushiv1.GetChatItemsRequest{ChatId: id, Before: last.Items[0].Id, ImageRefs: true})))
	checkRefs(t, "GetChatItems", page.Items[0].Images, big, small)

	// The reference brings the bytes, over the device's API (not macOnly),
	// from that chat only.
	ref := snap.Items[0].Images[0].Sha256
	got := must(phone.c.GetChatImage(ctx, connect.NewRequest(&nushiv1.GetChatImageRequest{ChatId: id, Sha256: ref})))
	if !bytes.Equal(got.Data, big) || got.MimeType != "image/png" {
		t.Errorf("GetChatImage: %d bytes, %q", len(got.Data), got.MimeType)
	}
	refused := func(chat, hash string, code connect.Code) {
		t.Helper()
		_, err := phone.c.GetChatImage(ctx, connect.NewRequest(&nushiv1.GetChatImageRequest{ChatId: chat, Sha256: hash}))
		if connect.CodeOf(err) != code {
			t.Errorf("GetChatImage(%s, %.12s): %v, want %v", chat, hash, err, code)
		}
	}
	refused(other, ref, connect.CodeNotFound)                               // another chat's
	refused(id, chats.ImageHash([]byte("made up")), connect.CodeNotFound)   // none of its own
	refused(id, "../../settings.json", connect.CodeInvalidArgument)         // not a hash
	refused("no-such-chat", ref, connect.CodeNotFound)                      // no chat
	refused(id, chats.ImageHash(nil)[:63]+"G", connect.CodeInvalidArgument) // not lowercase hex

	// A tool call's image (a browser's screenshot, say) is a reference too,
	// on the fake agent shaped like Claude's.
	id = must(phone.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	phone.send(id, "take a screenshot")
	phone.waitFor("the screenshot", turnEnded(id))
	shot := acptest.Screenshot()
	var call *nushiv1.Item
	for _, it := range must(phone.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id, Recent: 80, ImageRefs: true}))).Items {
		if it.Kind == nushiv1.ItemKind_ITEM_KIND_TOOL_CALL && len(it.Images) > 0 {
			call = it
		}
	}
	if call == nil || len(call.Images) != 1 {
		t.Fatalf("no tool call with an image: %v", call)
	}
	if img := call.Images[0]; len(img.Data) != 0 || img.Sha256 != chats.ImageHash(shot) || img.Size != int64(len(shot)) || img.Width != 200 || img.Height != 150 {
		t.Fatalf("the tool call's image: %d bytes, %q, size %d, %dx%d", len(img.Data), img.Sha256, img.Size, img.Width, img.Height)
	}
	got = must(phone.c.GetChatImage(ctx, connect.NewRequest(&nushiv1.GetChatImageRequest{ChatId: id, Sha256: call.Images[0].Sha256})))
	if !bytes.Equal(got.Data, shot) {
		t.Errorf("GetChatImage of the tool call's: %d bytes", len(got.Data))
	}
}

// checkRefs checks images are big as a reference and small inline.
func checkRefs(t *testing.T, where string, images []*nushiv1.ImageData, big, small []byte) {
	t.Helper()
	if len(images) != 2 {
		t.Fatalf("%s: %d images", where, len(images))
	}
	b, s := images[0], images[1]
	if len(b.Data) != 0 || b.Sha256 != chats.ImageHash(big) || b.Size != int64(len(big)) || b.Width != 200 || b.Height != 150 || b.MimeType != "image/png" {
		t.Errorf("%s: the big image: %d bytes, %q, size %d, %dx%d", where, len(b.Data), b.Sha256, b.Size, b.Width, b.Height)
	}
	if !bytes.Equal(s.Data, small) || s.Sha256 != "" {
		t.Errorf("%s: the small image: %d bytes, %q", where, len(s.Data), s.Sha256)
	}
}
