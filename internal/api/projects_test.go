package api

import (
	"bytes"
	"image"
	"image/png"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/testcheck"
)

// The Mac gets a folder's icon, or an empty answer for a folder without
// one; a path that isn't absolute is refused. A device's channel is
// refused by its guard (macOnly) and, past it, by the handler's own
// check.
func TestGetProjectIcon(t *testing.T) {
	ctx := t.Context()
	var b bytes.Buffer
	testcheck.NoErr(t, png.Encode(&b, image.NewRGBA(image.Rect(0, 0, 64, 64))))
	with, without := t.TempDir(), t.TempDir()
	testcheck.Write(t, filepath.Join(with, "logo.png"), b.String())
	get := func(c nushiv1connect.NushiServiceClient, folder string) (*nushiv1.GetProjectIconResponse, error) {
		r, err := c.GetProjectIcon(ctx, connect.NewRequest(&nushiv1.GetProjectIconRequest{Folder: folder}))
		if err != nil {
			return nil, err
		}
		return r.Msg, nil
	}
	mac := client(t, New(Services{}))
	if r, err := get(mac, with); err != nil || r.MimeType != "image/png" || !bytes.Equal(r.Data, b.Bytes()) {
		t.Errorf("a folder with a logo: %v, %v", r, err)
	}
	if r, err := get(mac, without); err != nil || r.MimeType != "" || len(r.Data) != 0 {
		t.Errorf("a folder without: %v, %v", r, err)
	}
	if _, err := get(mac, "logo"); connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Errorf("a relative path: %v", err)
	}
	for name, tc := range map[string]struct {
		c    nushiv1connect.NushiServiceClient
		says string
	}{
		"a device":            {client(t, ForDevices(Services{})), "only the Mac can do this"},
		"a device, unguarded": {client(t, serve(Services{}, "device")), "only the Mac shows project icons"},
	} {
		if _, err := get(tc.c, with); connect.CodeOf(err) != connect.CodePermissionDenied || !strings.Contains(err.Error(), tc.says) {
			t.Errorf("%s: %v", name, err)
		}
	}
}
