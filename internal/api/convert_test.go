package api

import (
	"bytes"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// A chat's archive time goes out in Unix milliseconds; one archived
// before the daemon kept the time, or not archived, says 0.
func TestChatProtoArchivedAt(t *testing.T) {
	at := time.UnixMilli(1_700_000_000_123)
	for _, tc := range []struct {
		name string
		rec  model.ChatRecord
		want int64
	}{
		{"archived", model.ChatRecord{Archived: true, ArchivedAt: at}, at.UnixMilli()},
		{"archived before the time was kept", model.ChatRecord{Archived: true}, 0},
		{"not archived", model.ChatRecord{}, 0},
	} {
		if got := chatProto(tc.rec).GetArchivedUnixMs(); got != tc.want {
			t.Errorf("%s: %d, want %d", tc.name, got, tc.want)
		}
	}
}

// A queue event to a client that takes references names each large
// queued image by its hash, as items do, instead of sending its bytes
// with every change of the queue; a client without refs, and a small
// image, still get the bytes, and so does a message handed back to send
// again (Unqueue).
func TestQueueEventImagesGoAsReferences(t *testing.T) {
	large := model.Image{MimeType: "image/png", Data: bytes.Repeat([]byte{1}, refAbove+1), Hash: "h"}
	small := model.Image{MimeType: "image/png", Data: []byte{2}, Hash: "s"}
	queue := []model.Message{{ID: "m", Images: []model.Image{large, small}}}
	event := model.Event{ChatID: "c", Queue: &queue}

	got := toProto(event, true).GetQueue().GetMessages()[0].GetImages()
	if got[0].GetSha256() != "h" || got[0].GetData() != nil || got[0].GetSize() != refAbove+1 {
		t.Errorf("large image with refs: %q, %d bytes, size %d; want its hash and no bytes",
			got[0].GetSha256(), len(got[0].GetData()), got[0].GetSize())
	}
	if !bytes.Equal(got[1].GetData(), small.Data) {
		t.Error("small image with refs came without its bytes")
	}
	inline := toProto(event, false).GetQueue().GetMessages()[0].GetImages()
	if !bytes.Equal(inline[0].GetData(), large.Data) {
		t.Errorf("large image without refs: %d bytes, want %d", len(inline[0].GetData()), len(large.Data))
	}
	if back := messageProto(queue[0]).GetImages()[0]; !bytes.Equal(back.GetData(), large.Data) {
		t.Errorf("a message handed back to send again: %d bytes, want %d", len(back.GetData()), len(large.Data))
	}
}
