package api

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"image"
	_ "image/gif"  // DecodeConfig reads a GIF's size
	_ "image/jpeg" // and a JPEG's
	_ "image/png"  // and a PNG's
	"regexp"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

// refAbove is the size past which an image goes as a reference to a
// client that asked for them (image_refs): smaller ones cost less inline
// than a call of their own (ADR 0099).
const refAbove = 64 << 10

// maxChatImage is the largest image GetChatImage sends: more than any an
// agent takes (agentproc.MaxMessage), so it only stops a runaway.
const maxChatImage = 32 << 20

// imageProto is an image for the API: inline, or with refs and past
// refAbove, its hash, length and size in pixels without its bytes.
func imageProto(img model.Image, refs bool) *nushiv1.ImageData {
	if !refs || len(img.Data) <= refAbove {
		return &nushiv1.ImageData{MimeType: img.MimeType, Data: img.Data}
	}
	out := &nushiv1.ImageData{MimeType: img.MimeType, Sha256: chats.HashOf(img), Size: int64(len(img.Data))}
	// Only the header is read; a WebP, or bytes that aren't an image, have
	// no size and the client shows a square until they come.
	if c, _, err := image.DecodeConfig(bytes.NewReader(img.Data)); err == nil {
		out.Width, out.Height = int32(min(c.Width, 1<<30)), int32(min(c.Height, 1<<30))
	}
	return out
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
