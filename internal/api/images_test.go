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
