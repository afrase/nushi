// Package imagefit makes an image's file small enough to send: scaled down
// and re-encoded until it fits a number of bytes, for an agent that counts
// an image by its bytes and leaves out one that doesn't fit (Ante:
// docs/facts/ante.md's Images). It reads PNG, JPEG, GIF (the first frame)
// and WebP.
package imagefit

import (
	"bytes"
	"errors"
	"image"
	"image/gif"
	"image/jpeg"
	"image/png"
	"io"

	"golang.org/x/image/draw"
	"golang.org/x/image/webp"
)

// edges are the long edges Fit scales to, in turn: 1568 px is the most
// Anthropic's vision docs suggest, the others smaller steps.
var edges = []int{1568, 1024, 768}

// qualities are the JPEG qualities it tries, the lower ones only at the
// smallest edge.
var qualities = []int{80, 60, 40}

// maxPixels is the largest image it decodes (144 MB as 8-bit RGBA, twice
// that for a 16-bit PNG); a bigger one stays as it is.
const maxPixels = 6000 * 6000

// Fit returns data, an image of type mimeType, as a file of at most
// maxBytes whose long edge is at most maxEdge. One that is both already
// comes back as it is, byte for byte. Any other is scaled down (never up)
// and re-encoded, JPEG when it's opaque and PNG when it has transparency,
// in smaller steps until it fits. ok is false when nothing fits: out is
// then the smallest it made. An image it can't decode comes back as it is.
func Fit(data []byte, mimeType string, maxBytes, maxEdge int) (out []byte, outType string, ok bool) {
	small := len(data) <= maxBytes
	c, err := config(data, mimeType)
	if err != nil {
		return data, mimeType, small
	}
	long := max(c.Width, c.Height)
	if small && long <= maxEdge {
		return data, mimeType, true
	}
	src, err := decode(data, mimeType)
	if err != nil {
		return data, mimeType, small
	}
	if long <= maxEdge {
		out, outType = data, mimeType
	}
	opaque := isOpaque(src)
	for _, s := range steps(long, maxEdge, opaque) {
		b, typ, err := encode(scale(src, s.edge), opaque, s.quality)
		if err != nil {
			continue
		}
		if len(b) <= maxBytes {
			return b, typ, true
		}
		if out == nil || len(b) < len(out) {
			out, outType = b, typ
		}
	}
	if out == nil {
		return data, mimeType, false
	}
	return out, outType, false
}

// step is one try: a long edge and, for a JPEG, its quality.
type step struct{ edge, quality int }

// steps are the tries for an image whose long edge is long: the largest
// edge allowed, then the smaller ones, then (for a JPEG) lower qualities.
func steps(long, maxEdge int, opaque bool) []step {
	first := min(long, maxEdge, edges[0])
	out := []step{{first, qualities[0]}}
	for _, e := range edges[1:] {
		if e < first {
			out = append(out, step{e, qualities[0]})
		}
	}
	if opaque {
		last := out[len(out)-1].edge
		for _, q := range qualities[1:] {
			out = append(out, step{last, q})
		}
	}
	return out
}

// codec is a format's two decoders, by the image's type.
func codec(mimeType string) (func(io.Reader) (image.Config, error), func(io.Reader) (image.Image, error), error) {
	switch mimeType {
	case "image/png":
		return png.DecodeConfig, png.Decode, nil
	case "image/jpeg":
		return jpeg.DecodeConfig, jpeg.Decode, nil
	case "image/gif":
		return gif.DecodeConfig, gif.Decode, nil
	case "image/webp":
		return webp.DecodeConfig, webp.Decode, nil
	}
	return nil, nil, errors.ErrUnsupported
}

// config is the image's header: its size, refused past maxPixels.
func config(data []byte, mimeType string) (image.Config, error) {
	cfg, _, err := codec(mimeType)
	if err != nil {
		return image.Config{}, err
	}
	c, err := cfg(bytes.NewReader(data))
	if err != nil {
		return c, err
	}
	if c.Width <= 0 || c.Height <= 0 || c.Width > maxPixels/c.Height {
		return c, errors.New("the image is too big to decode")
	}
	return c, nil
}

func decode(data []byte, mimeType string) (image.Image, error) {
	_, dec, err := codec(mimeType)
	if err != nil {
		return nil, err
	}
	return dec(bytes.NewReader(data))
}

// isOpaque says whether every pixel of m is: the standard library's images
// say so themselves.
func isOpaque(m image.Image) bool {
	o, ok := m.(interface{ Opaque() bool })
	return ok && o.Opaque()
}

// scale is src with its long edge at edge, its aspect kept.
func scale(src image.Image, edge int) image.Image {
	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	if max(w, h) == edge {
		return src
	}
	if w >= h {
		w, h = edge, max(1, (h*edge+w/2)/w)
	} else {
		w, h = max(1, (w*edge+h/2)/h), edge
	}
	dst := image.NewRGBA(image.Rect(0, 0, w, h))
	draw.CatmullRom.Scale(dst, dst.Bounds(), src, b, draw.Src, nil)
	return dst
}

func encode(m image.Image, opaque bool, quality int) ([]byte, string, error) {
	var b bytes.Buffer
	if opaque {
		err := jpeg.Encode(&b, m, &jpeg.Options{Quality: quality})
		return b.Bytes(), "image/jpeg", err
	}
	err := (&png.Encoder{}).Encode(&b, m)
	return b.Bytes(), "image/png", err
}
