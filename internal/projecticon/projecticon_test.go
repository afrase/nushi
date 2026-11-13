package projecticon

import (
	"bytes"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// pngOf is a PNG w by h; noisy, its pixels don't compress, so it's large.
func pngOf(t *testing.T, w, h int, noisy bool) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	if noisy {
		seed := uint32(1)
		for i := range img.Pix {
			seed = seed*1664525 + 1013904223
			img.Pix[i] = byte(seed >> 24)
		}
	} else {
		img.Set(0, 0, color.White)
	}
	var b bytes.Buffer
	testcheck.NoErr(t, png.Encode(&b, img))
	return b.Bytes()
}

func put(t *testing.T, dir, name string, data []byte) {
	t.Helper()
	testcheck.Write(t, filepath.Join(dir, name), string(data))
}

// A project's icon is the first of the list that's there, typed by its
// bytes; a folder with none, or one that isn't there, has none.
func TestFind(t *testing.T) {
	dir := t.TempDir()
	if _, ok := Find(dir); ok {
		t.Error("an empty folder has an icon")
	}
	if _, ok := Find(filepath.Join(dir, "none")); ok {
		t.Error("a missing folder has an icon")
	}
	favicon, logo := pngOf(t, 48, 48, false), pngOf(t, 64, 64, false)
	put(t, dir, "public/favicon.png", favicon)
	if got, ok := Find(dir); !ok || got.MimeType != "image/png" || !bytes.Equal(got.Data, favicon) {
		t.Errorf("the favicon: %q, %d bytes, %v", got.MimeType, len(got.Data), ok)
	}
	put(t, dir, ".github/logo.png", logo)
	if got, _ := Find(dir); !bytes.Equal(got.Data, logo) {
		t.Error("the repository's logo doesn't come before a site's favicon")
	}
	// A JPEG, whatever its name says.
	var b bytes.Buffer
	testcheck.NoErr(t, jpeg.Encode(&b, image.NewRGBA(image.Rect(0, 0, 40, 40)), nil))
	put(t, dir, "icon.png", b.Bytes())
	if got, ok := Find(dir); !ok || got.MimeType != "image/jpeg" {
		t.Errorf("a JPEG: %q, %v", got.MimeType, ok)
	}
}

// What isn't a small square image is passed over for the next path: a
// file too large, text, an SVG, an image too small, too big or too wide,
// one cut short.
func TestPassedOver(t *testing.T) {
	good := pngOf(t, 64, 64, false)
	large := pngOf(t, 512, 512, true)
	if len(large) <= MaxBytes {
		t.Fatalf("the large image is only %d bytes", len(large))
	}
	for name, bad := range map[string][]byte{
		"too large":  large,
		"text":       []byte("not an image"),
		"an SVG":     []byte(`<svg xmlns="http://www.w3.org/2000/svg"/>`),
		"too small":  pngOf(t, 16, 16, false),
		"too big":    pngOf(t, MaxSide+1, MaxSide+1, false),
		"a wordmark": pngOf(t, 400, 100, false),
		"cut short":  good[:20],
	} {
		dir := t.TempDir()
		put(t, dir, "icon.png", bad)
		if got, ok := Find(dir); ok {
			t.Errorf("%s: taken as an icon (%d bytes)", name, len(got.Data))
		}
		put(t, dir, "logo.png", good)
		if got, ok := Find(dir); !ok || !bytes.Equal(got.Data, good) {
			t.Errorf("%s: the next path isn't taken", name)
		}
	}
	dir := t.TempDir()
	testcheck.NoErr(t, os.MkdirAll(filepath.Join(dir, "icon.png"), 0o700))
	if _, ok := Find(dir); ok {
		t.Error("a folder is an icon")
	}
}

// A link is never followed: not one out of the folder, to a file or
// through a folder, nor one inside it.
func TestLinks(t *testing.T) {
	outside, dir := t.TempDir(), t.TempDir()
	put(t, outside, "secret.png", pngOf(t, 64, 64, false))
	put(t, outside, "assets/icon.png", pngOf(t, 64, 64, false))
	testcheck.NoErr(t, os.Symlink(filepath.Join(outside, "secret.png"), filepath.Join(dir, "icon.png")))
	testcheck.NoErr(t, os.Symlink(filepath.Join(outside, "assets"), filepath.Join(dir, "assets")))
	if got, ok := Find(dir); ok {
		t.Errorf("a link out of the folder was read: %d bytes", len(got.Data))
	}
	put(t, dir, "inside.png", pngOf(t, 64, 64, false))
	testcheck.NoErr(t, os.Symlink("inside.png", filepath.Join(dir, "logo.png")))
	if _, ok := Find(dir); ok {
		t.Error("a link inside the folder was followed")
	}
}

// An icon set gives its largest PNG that fits, after the repository's
// own mark and before a favicon.
func TestIconSet(t *testing.T) {
	dir := t.TempDir()
	set := "macos/Runner/Assets.xcassets/AppIcon.appiconset/"
	mid := pngOf(t, 256, 256, false)
	put(t, dir, set+"app_icon_64.png", pngOf(t, 64, 64, false))
	put(t, dir, set+"app_icon_256.png", mid)
	put(t, dir, set+"app_icon_2048.png", pngOf(t, 2048, 2048, false))
	put(t, dir, set+"Contents.json", []byte("{}"))
	put(t, dir, "web/favicon.png", pngOf(t, 48, 48, false))
	if got, ok := Find(dir); !ok || !bytes.Equal(got.Data, mid) {
		t.Errorf("the icon set's: %d bytes, %v; want the 256's %d", len(got.Data), ok, len(mid))
	}
	logo := pngOf(t, 40, 40, false)
	put(t, dir, "logo.png", logo)
	if got, _ := Find(dir); !bytes.Equal(got.Data, logo) {
		t.Error("the repository's logo doesn't come before its app's icon")
	}
}
