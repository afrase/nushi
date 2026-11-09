// Package imagesize reads an image's size in pixels from its header, as
// a client draws its box before the bytes come (ADR 0099): PNG, JPEG and
// GIF. Anything else (a WebP, bytes that aren't an image) has none.
package imagesize

import (
	"bytes"
	"image"
	_ "image/gif"  // DecodeConfig reads a GIF's size
	_ "image/jpeg" // and a JPEG's
	_ "image/png"  // and a PNG's
	"io"
)

// most is the largest side it says: past it, a header lies.
const most = 1 << 30

// Of is the size r's header says, 0×0 when it says none. Only the header
// is read.
func Of(r io.Reader) (width, height int) {
	c, _, err := image.DecodeConfig(r)
	if err != nil || c.Width <= 0 || c.Height <= 0 {
		return 0, 0
	}
	return min(c.Width, most), min(c.Height, most)
}

// OfBytes is Of of an image's bytes.
func OfBytes(data []byte) (width, height int) { return Of(bytes.NewReader(data)) }
