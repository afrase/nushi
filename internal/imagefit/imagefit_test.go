package imagefit

import (
	"bytes"
	"encoding/binary"
	"hash/crc32"
	"image"
	"image/color"
	"image/gif"
	"image/jpeg"
	"image/png"
	"testing"
)

// screen is a w×h image like a screenshot's: flat areas, edges and some
// noise, so that it doesn't compress to nothing. alpha < 255 makes a band
// of it see-through.
func screen(w, h int, alpha uint8) *image.NRGBA {
	m := image.NewNRGBA(image.Rect(0, 0, w, h))
	seed := uint32(1)
	for y := range h {
		for x := range w {
			c := color.NRGBA{uint8(x / 7), uint8(y / 5), uint8((x ^ y) & 0xf0), 255}
			if (x/40+y/24)%5 == 0 {
				seed = seed*1664525 + 1013904223 // a fixed noise
				c.R, c.G = uint8(seed>>24), uint8(seed>>16&0xff)
			}
			if y < h/4 {
				c.A = alpha
			}
			m.SetNRGBA(x, y, c)
		}
	}
	return m
}

func pngOf(t *testing.T, m image.Image) []byte {
	t.Helper()
	var b bytes.Buffer
	if err := png.Encode(&b, m); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

func TestFit(t *testing.T) {
	big := pngOf(t, screen(1800, 900, 255))
	var flat bytes.Buffer
	if err := jpeg.Encode(&flat, screen(400, 300, 255), nil); err != nil {
		t.Fatal(err)
	}
	seeThrough := pngOf(t, screen(1650, 1100, 128))
	var anim bytes.Buffer
	if err := gif.Encode(&anim, screen(900, 600, 255), nil); err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct {
		name     string
		data     []byte
		mimeType string
		maxBytes int
		maxEdge  int
		wantType string
		wantOK   bool
		same     bool // byte for byte
		long     int  // the longest edge it may come out with; 0 when not an image
		aspect   float64
	}{
		{"a big screenshot comes out under the limit, as JPEG", big, "image/png", 300_000, 2000, "image/jpeg", true, false, 1568, 2},
		{"over the long edge alone it's scaled too", big, "image/png", len(big), 1200, "image/jpeg", true, false, 1200, 2},
		{"a small one stays as it is", flat.Bytes(), "image/jpeg", 400_000, 2000, "image/jpeg", true, true, 400, 4.0 / 3},
		{"a transparent one stays PNG", seeThrough, "image/png", len(seeThrough) / 2, 2000, "image/png", true, false, 1568, 1.5},
		{"a GIF's first frame", anim.Bytes(), "image/gif", 60_000, 2000, "image/jpeg", true, false, 900, 1.5},
		{"what can't fit comes out as small as it gets", big, "image/png", 1000, 2000, "image/jpeg", false, false, 768, 2},
		{"bad bytes stay as they are", []byte("not a png"), "image/png", 400_000, 2000, "image/png", true, true, 0, 0},
		{"too big and bad: as they are, not ok", []byte("not a png"), "image/png", 3, 2000, "image/png", false, true, 0, 0},
		{"a type it doesn't read", []byte("BM...."), "image/bmp", 400_000, 2000, "image/bmp", true, true, 0, 0},
	} {
		t.Run(c.name, func(t *testing.T) {
			out, typ, ok := Fit(c.data, c.mimeType, c.maxBytes, c.maxEdge)
			if typ != c.wantType || ok != c.wantOK {
				t.Fatalf("Fit = %s, %v; want %s, %v", typ, ok, c.wantType, c.wantOK)
			}
			if ok && len(out) > c.maxBytes {
				t.Errorf("%d bytes, over %d", len(out), c.maxBytes)
			}
			if c.same != bytes.Equal(out, c.data) {
				t.Errorf("byte for byte: %v, want %v", !c.same, c.same)
			}
			if c.long == 0 {
				return
			}
			m, _, err := image.Decode(bytes.NewReader(out))
			if err != nil {
				t.Fatal(err)
			}
			w, h := m.Bounds().Dx(), m.Bounds().Dy()
			if max(w, h) > c.long {
				t.Errorf("%d×%d, want a long edge of %d at most", w, h, c.long)
			}
			if got := float64(w) / float64(h); got < c.aspect*0.995 || got > c.aspect*1.005 {
				t.Errorf("%d×%d: aspect %.3f, want %.3f", w, h, got, c.aspect)
			}
		})
	}
}

// A header that says more pixels than it decodes leaves the image as it
// is, decoding nothing.
func TestTooManyPixels(t *testing.T) {
	data := pngOf(t, image.NewGray(image.Rect(0, 0, 1, 1)))
	ihdr := data[12:29] // its type, then width, height and the rest
	binary.BigEndian.PutUint32(ihdr[4:], 6001)
	binary.BigEndian.PutUint32(ihdr[8:], 6000)
	binary.BigEndian.PutUint32(data[29:], crc32.ChecksumIEEE(ihdr))
	if c, err := png.DecodeConfig(bytes.NewReader(data)); err != nil || c.Width != 6001 {
		t.Fatalf("the header: %+v, %v", c, err)
	}
	if out, typ, ok := Fit(data, "image/png", 1, 2000); !bytes.Equal(out, data) || typ != "image/png" || ok {
		t.Errorf("Fit = %d bytes, %s, %v", len(out), typ, ok)
	}
}
