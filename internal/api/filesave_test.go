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

// Only the Mac's socket writes a file: a device's channel is refused by
// its guard (macOnly), and, past it, by the handler's own check, so a way
// in that forgets the guard still can't write.
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
		"the Mac":             {client(t, New(Services{Chats: svc})), connect.CodeNotFound, ""},
		"a device":            {client(t, ForDevices(Services{Chats: svc})), connect.CodePermissionDenied, "only the Mac can do this"},
		"a device, unguarded": {client(t, serve(Services{Chats: svc}, "device")), connect.CodePermissionDenied, "only the Mac can edit files"},
	} {
		_, err := tc.c.WriteChatFile(context.Background(), req)
		if connect.CodeOf(err) != tc.code || !strings.Contains(err.Error(), tc.says) {
			t.Errorf("%s: %v, want %v", name, err, tc.code)
		}
	}
}
