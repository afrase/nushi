package acptest

import (
	"bytes"
	"image"
	"image/png"
	"math/rand/v2"
	"sync"
)

// Screenshot is the PNG the "screenshot" script's tool call returns: 200×150
// of noise, which doesn't compress, so it's over the 64 KB past which a
// client that asks for references gets one (ADR 0099).
var Screenshot = sync.OnceValue(func() []byte {
	img := image.NewNRGBA(image.Rect(0, 0, 200, 150))
	r := rand.New(rand.NewPCG(3, 4)) //nolint:gosec // test pixels
	for i := range img.Pix {
		img.Pix[i] = uint8(r.UintN(256)) //nolint:gosec // below 256
	}
	var b bytes.Buffer
	if err := png.Encode(&b, img); err != nil {
		panic(err) // an in-memory image always encodes
	}
	return b.Bytes()
})
