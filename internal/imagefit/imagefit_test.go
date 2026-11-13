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
	"os"
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
	// The images are as small as each case allows (under -race their
	// encoding is most of the test's time): big just over the 1568 px edge,
	// mid between the two smaller steps.
	big := pngOf(t, screen(1600, 800, 255))
	mid := pngOf(t, screen(1000, 500, 255))
	var flat bytes.Buffer
	if err := jpeg.Encode(&flat, screen(400, 300, 255), nil); err != nil {
		t.Fatal(err)
	}
	seeThrough := pngOf(t, screen(1100, 733, 128))
	var still bytes.Buffer
	if err := gif.Encode(&still, screen(450, 300, 255), nil); err != nil {
		t.Fatal(err)
	}
	webp, err := os.ReadFile("testdata/gradient.webp") // 400×200, cwebp -lossless
	if err != nil {
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
		{"a transparent one stays PNG", seeThrough, "image/png", len(seeThrough) * 4 / 5, 2000, "image/png", true, false, 768, 1.5},
		{"a GIF", still.Bytes(), "image/gif", still.Len() / 2, 2000, "image/jpeg", true, false, 450, 1.5},
		{"a WebP", webp, "image/webp", 20_000, 300, "image/jpeg", true, false, 300, 2},
		{"what can't fit comes out as small as it gets", mid, "image/png", 1000, 2000, "image/jpeg", false, false, 768, 2},
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

// An animated GIF comes out as its first frame.
func TestGIFFirstFrame(t *testing.T) {
	frame := func(c color.Color) *image.Paletted {
		return image.NewPaletted(image.Rect(0, 0, 300, 200), color.Palette{c})
	}
	var anim bytes.Buffer
	red, blue := color.RGBA{255, 0, 0, 255}, color.RGBA{0, 0, 255, 255}
	if err := gif.EncodeAll(&anim, &gif.GIF{Image: []*image.Paletted{frame(red), frame(blue)}, Delay: []int{10, 10}}); err != nil {
		t.Fatal(err)
	}
	out, typ, ok := Fit(anim.Bytes(), "image/gif", 400_000, 150)
	if typ != "image/jpeg" || !ok {
		t.Fatalf("Fit = %s, %v", typ, ok)
	}
	m, err := jpeg.Decode(bytes.NewReader(out))
	if err != nil {
		t.Fatal(err)
	}
	if r, _, b, _ := m.At(75, 50).RGBA(); r>>8 < 200 || b>>8 > 50 {
		t.Errorf("the middle is %v, want the first frame's red", m.At(75, 50))
	}
}

// pngSaying is a 1×1 PNG whose header says it's w×h.
func pngSaying(t *testing.T, w, h uint32) []byte {
	t.Helper()
	data := pngOf(t, image.NewGray(image.Rect(0, 0, 1, 1)))
	ihdr := data[12:29] // its type, then width, height and the rest
	binary.BigEndian.PutUint32(ihdr[4:], w)
	binary.BigEndian.PutUint32(ihdr[8:], h)
	binary.BigEndian.PutUint32(data[29:], crc32.ChecksumIEEE(ihdr))
	if c, err := png.DecodeConfig(bytes.NewReader(data)); err != nil || c.Width != int(w) || c.Height != int(h) {
		t.Fatalf("the header: %+v, %v", c, err)
	}
	return data
}

// An image of up to 36 megapixels is decoded; a header that says more
// is refused before any decoding, and Fit leaves that image as it is.
func TestTooManyPixels(t *testing.T) {
	if _, err := config(pngSaying(t, 6000, 6000), "image/png"); err != nil {
		t.Errorf("6000×6000: %v", err)
	}
	for _, size := range [][2]uint32{{6001, 6000}, {1, 6000*6000 + 1}} {
		data := pngSaying(t, size[0], size[1])
		if _, err := config(data, "image/png"); err == nil {
			t.Errorf("%d×%d: no error", size[0], size[1])
		}
		if out, typ, ok := Fit(data, "image/png", 1, 2000); !bytes.Equal(out, data) || typ != "image/png" || ok {
			t.Errorf("Fit = %d bytes, %s, %v", len(out), typ, ok)
		}
	}
}
