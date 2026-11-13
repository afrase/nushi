package e2e

import (
	"bytes"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// The Mac's sidebar gets a project's own icon from the daemon: the
// repository's logo, of a folder with a chat or of one just added with
// none; nothing for a folder without one, nor through a link that leads
// out of the folder. A phone's channel can't ask.
func TestAProjectsIcon(t *testing.T) {
	ctx := t.Context()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	mac, phone := open(t, d), openAt(t, d.devices)
	var logo bytes.Buffer
	testcheck.NoErr(t, png.Encode(&logo, image.NewRGBA(image.Rect(0, 0, 128, 128))))
	icon := func(a *app, folder string) (*nushiv1.GetProjectIconResponse, error) {
		r, err := a.c.GetProjectIcon(ctx, connect.NewRequest(&nushiv1.GetProjectIconRequest{Folder: folder}))
		if err != nil {
			return nil, err
		}
		return r.Msg, nil
	}

	with, added, without, linked := t.TempDir(), t.TempDir(), t.TempDir(), t.TempDir()
	testcheck.Write(t, filepath.Join(with, ".github", "logo.png"), logo.String())
	testcheck.Write(t, filepath.Join(added, "icon.png"), logo.String())
	testcheck.NoErr(t, os.Symlink(filepath.Join(with, ".github", "logo.png"), filepath.Join(linked, "logo.png")))
	mac.start(&nushiv1.StartChatRequest{Folder: with})
	for name, folder := range map[string]string{"a chat's folder": with, "a folder with no chat": added} {
		if r, err := icon(mac, folder); err != nil || r.MimeType != "image/png" || !bytes.Equal(r.Data, logo.Bytes()) {
			t.Errorf("%s: %q, %d bytes, %v", name, r.GetMimeType(), len(r.GetData()), err)
		}
	}
	for name, folder := range map[string]string{"no icon": without, "a link out of the folder": linked} {
		if r, err := icon(mac, folder); err != nil || r.MimeType != "" || len(r.Data) != 0 {
			t.Errorf("%s: %q, %d bytes, %v", name, r.GetMimeType(), len(r.GetData()), err)
		}
	}
	if _, err := icon(phone, with); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("the phone's ask: %v", err)
	}
}
