package api

import (
	"bytes"
	"testing"

	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/model"
)

// A reference names the image by the hash taken as it came in: its bytes
// aren't read again for each snapshot, page and event.
func TestAReferenceUsesTheImagesHash(t *testing.T) {
	data := bytes.Repeat([]byte{1}, refAbove+1)
	if got := imageProto(model.Image{MimeType: "image/png", Data: data, Hash: "taken"}, true); got.Sha256 != "taken" || len(got.Data) != 0 {
		t.Errorf("reference = %q, %d bytes; want the image's own hash and no bytes", got.Sha256, len(got.Data))
	}
	if got := imageProto(model.Image{MimeType: "image/png", Data: data}, true); got.Sha256 != chats.ImageHash(data) {
		t.Errorf("an image made without its hash: %q, want its bytes' hash", got.Sha256)
	}
}

// An image the chat holds as a reference (ADR 0105) names its size from
// what the chat holds, and goes without bytes even to a client without
// refs, whose bytes couldn't be read back: never as empty bytes.
func TestAHeldImageGoesAsAReference(t *testing.T) {
	held := model.Image{MimeType: "image/png", Hash: "h", Size: refAbove + 1, Width: 640, Height: 400}
	for _, refs := range []bool{true, false} {
		got := imageProto(held, refs)
		if got.Sha256 != "h" || got.Size != refAbove+1 || got.Width != 640 || got.Height != 400 || got.Data != nil {
			t.Errorf("refs %v: %+v", refs, got)
		}
	}
}
