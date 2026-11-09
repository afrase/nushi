package imagesize

import (
	"bytes"
	"image"
	"image/gif"
	"image/jpeg"
	"image/png"
	"io"
	"testing"
)

func TestOf(t *testing.T) {
	m := image.NewNRGBA(image.Rect(0, 0, 7, 5))
	for name, enc := range map[string]func(io.Writer) error{
		"png":  func(w io.Writer) error { return png.Encode(w, m) },
		"jpeg": func(w io.Writer) error { return jpeg.Encode(w, m, nil) },
		"gif":  func(w io.Writer) error { return gif.Encode(w, m, nil) },
	} {
		var b bytes.Buffer
		if err := enc(&b); err != nil {
			t.Fatal(err)
		}
		if w, h := OfBytes(b.Bytes()); w != 7 || h != 5 {
			t.Errorf("%s: %d×%d", name, w, h)
		}
	}
	if w, h := OfBytes([]byte("RIFF....WEBPVP8 not one it knows")); w != 0 || h != 0 {
		t.Errorf("a WebP: %d×%d, want none", w, h)
	}
}
