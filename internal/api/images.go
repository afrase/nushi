package api

import (
	"context"
	"errors"
	"fmt"
	"regexp"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/imagesize"
	"github.com/afrase/nushi/internal/model"
)

// refAbove is the size past which an image goes as a reference to a
// client that asked for them (image_refs): smaller ones cost less inline
// than a call of their own (ADR 0099), and the daemon holds them so.
const refAbove = model.SmallImage

// maxChatImage is the largest image GetChatImage sends: more than any an
// agent takes (agentproc.MaxMessage), so it only stops a runaway.
const maxChatImage = 32 << 20

// imageProto is an image for the API: inline, or with refs and past
// refAbove, its hash, length and size in pixels without its bytes. One
// the chat holds as a reference (ADR 0105) goes so either way: a client
// without refs had its bytes read back first (inline), and one that
// couldn't be read comes without them, which the client shows as failed.
func imageProto(img model.Image, refs bool) *nushiv1.ImageData {
	size := img.Size
	if img.Data != nil {
		size = int64(len(img.Data))
	}
	if img.Data != nil && (!refs || size <= refAbove) {
		return &nushiv1.ImageData{MimeType: img.MimeType, Data: img.Data}
	}
	w, h := img.Width, img.Height
	if w == 0 && img.Data != nil { // made without its size taken: only the header is read
		w, h = imagesize.OfBytes(img.Data)
	}
	// A WebP, or bytes that aren't an image, have no size, and the client
	// shows a square until they come.
	return &nushiv1.ImageData{MimeType: img.MimeType, Sha256: chats.HashOf(img), Size: size,
		Width: int32(w), Height: int32(h)} // imagesize keeps a side under 1<<30
}

// inline gives items, the caller's copies of chatID's, the bytes of the
// images the chat holds as references, unless the client takes
// references (refs).
func (s *server) inline(chatID string, items []model.Item, refs bool) {
	if !refs {
		s.Chats.Inline(chatID, items)
	}
}

var sha256Hex = regexp.MustCompile(`^[0-9a-f]{64}$`)

func (s *server) GetChatImage(_ context.Context, req *connect.Request[nushiv1.GetChatImageRequest]) (*connect.Response[nushiv1.GetChatImageResponse], error) {
	if !sha256Hex.MatchString(req.Msg.Sha256) {
		return nil, invalid(errors.New("not an image's hash"))
	}
	img, err := s.Chats.Image(req.Msg.ChatId, req.Msg.Sha256)
	if err != nil {
		return nil, notFound(err)
	}
	if len(img.Data) > maxChatImage {
		return nil, connect.NewError(connect.CodeResourceExhausted, fmt.Errorf("the image is %d bytes, more than %d", len(img.Data), maxChatImage))
	}
	return connect.NewResponse(&nushiv1.GetChatImageResponse{MimeType: img.MimeType, Data: img.Data}), nil
}
