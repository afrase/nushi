package api

import (
	"context"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/store"
)

// Only the local socket writes a file: a device's channel is refused by
// the guard (macOnly).
func TestOnlyTheMacWritesFiles(t *testing.T) {
	st := store.New(t.TempDir())
	svc := chats.New(t.Context(), nil, chats.Options{Remembered: st, Sessions: st, Scratch: t.TempDir()})
	t.Cleanup(svc.Close)
	req := connect.NewRequest(&nushiv1.WriteChatFileRequest{ChatId: "nope", Path: "a.go", Data: []byte("x")})
	for name, tc := range map[string]struct {
		c    nushiv1connect.NushiServiceClient
		code connect.Code
		says string
	}{
		"the Mac":  {client(t, New(Services{Chats: svc})), connect.CodeNotFound, ""},
		"a device": {client(t, ForDevices(Services{Chats: svc})), connect.CodePermissionDenied, "only this computer's app can do this"},
	} {
		_, err := tc.c.WriteChatFile(context.Background(), req)
		if connect.CodeOf(err) != tc.code || !strings.Contains(err.Error(), tc.says) {
			t.Errorf("%s: %v, want %v", name, err, tc.code)
		}
	}
}
