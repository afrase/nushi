package transcripts

import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// noise is a w×h PNG of random pixels: past model.SmallImage at 200×100.
func noise(t *testing.T, w, h int) model.Image {
	t.Helper()
	m := image.NewNRGBA(image.Rect(0, 0, w, h))
	_, _ = rand.Read(m.Pix)
	var b bytes.Buffer
	testcheck.NoErr(t, png.Encode(&b, m))
	sum := sha256.Sum256(b.Bytes())
	return model.Image{MimeType: "image/png", Data: b.Bytes(), Hash: hex.EncodeToString(sum[:])}
}

func TestALargeImageReadsBackAsAReference(t *testing.T) {
	s, dir := open(t)
	big, small := noise(t, 200, 100), model.Image{MimeType: "image/png", Data: []byte("small")}
	if len(big.Data) <= model.SmallImage {
		t.Fatalf("the large image is %d bytes", len(big.Data))
	}
	add(t, s, "CHAT", "", model.Item{ID: "t1", Kind: model.ToolCall, Images: []model.Image{big, small}})

	check := func(how string, it model.Item) {
		t.Helper()
		if len(it.Images) != 2 {
			t.Fatalf("%s: images %+v", how, it.Images)
		}
		ref, inline := it.Images[0], it.Images[1]
		if !ref.Ref() || ref.Hash != big.Hash || ref.Size != int64(len(big.Data)) || ref.Width != 200 || ref.Height != 100 {
			t.Errorf("%s: the large image = %+v, want a reference of 200×100", how, ref)
		}
		if inline.Ref() || string(inline.Data) != "small" || inline.Size != 5 {
			t.Errorf("%s: the small image = %+v, want its bytes", how, inline)
		}
	}
	check("Read", read(t, s, "CHAT")[0])
	picked, err := s.Pick("CHAT", []string{"t1"})
	testcheck.NoErr(t, err)
	check("Pick", picked[0])
	found, _, err := s.Find("CHAT", func(model.Item) bool { return true })
	testcheck.NoErr(t, err)
	check("Find", found[0])

	data, err := s.ImageData("CHAT", big.Hash, int64(len(big.Data)))
	if err != nil || !bytes.Equal(data, big.Data) {
		t.Fatalf("ImageData = %d bytes, %v", len(data), err)
	}
	// Written again as a reference: the file stays what it was.
	add(t, s, "CHAT", "", model.Item{ID: "t1", Kind: model.ToolCall, Images: read(t, s, "CHAT")[0].Images})
	check("written again", read(t, s, "CHAT")[0])

	// A file cut short, or gone, is an error, never other bytes.
	file := filepath.Join(dir, "CHAT", imagesDir, big.Hash)
	testcheck.NoErr(t, os.WriteFile(file, big.Data[:100], 0o600))
	if _, err := s.ImageData("CHAT", big.Hash, int64(len(big.Data))); err == nil {
		t.Error("a file cut short read back")
	}
	testcheck.NoErr(t, os.Remove(file))
	if _, err := s.ImageData("CHAT", big.Hash, int64(len(big.Data))); err == nil {
		t.Error("a gone file read back")
	}
	if _, err := s.ImageData("CHAT", "../x", 0); err == nil {
		t.Error("ImageData took a path")
	}
}

func TestAReferenceTheCopyLacksIsntWritten(t *testing.T) {
	s, dir := open(t)
	big := noise(t, 200, 100)
	add(t, s, "A", "", model.Item{ID: "t1", Kind: model.ToolCall, Images: []model.Image{big}})
	ref := read(t, s, "A")[0].Images[0]
	// Another chat's copy (a fork's) hasn't the file: the write fails,
	// and no empty file stands for it.
	err := s.Append("B", []model.Item{{ID: "t1", Kind: model.ToolCall, Images: []model.Image{ref}}}, []string{""})
	if err == nil || !strings.Contains(err.Error(), "isn't in the transcript copy") {
		t.Fatalf("Append = %v", err)
	}
	if err := s.Replace("B", []model.Item{{ID: "t1", Images: []model.Image{ref}}}); err == nil {
		t.Fatal("Replace wrote a reference the copy lacks")
	}
	if _, err := os.Stat(filepath.Join(dir, "B", imagesDir, big.Hash)); err == nil {
		t.Error("an image file was written for a reference")
	}
}

func TestAnOlderRecordsImageTakesItsSizeFromItsFile(t *testing.T) {
	s, dir := open(t)
	big, small := noise(t, 200, 100), noise(t, 4, 3)
	// As an older daemon wrote them: no size, no pixels.
	for _, img := range []model.Image{big, small} {
		testcheck.Write(t, filepath.Join(dir, "OLD", imagesDir, img.Hash), string(img.Data))
	}
	testcheck.Write(t, filepath.Join(dir, "OLD", itemsFile),
		`{"item":{"ID":"t1","Kind":3,"pictures":[{"mime":"image/png","hash":"`+big.Hash+`"},{"mime":"image/png","hash":"`+small.Hash+`"},{"mime":"image/png","hash":"`+strings.Repeat("0", 64)+`"}]}}`+"\n")
	it := read(t, s, "OLD")[0]
	if len(it.Images) != 2 { // the third's file is gone: left out, with a warning
		t.Fatalf("images %+v", it.Images)
	}
	if ref := it.Images[0]; !ref.Ref() || ref.Size != int64(len(big.Data)) || ref.Width != 200 || ref.Height != 100 {
		t.Errorf("the large image = %+v", ref)
	}
	if in := it.Images[1]; !bytes.Equal(in.Data, small.Data) || in.Width != 4 || in.Height != 3 || in.Size != int64(len(small.Data)) {
		t.Errorf("the small image = %+v", in)
	}
}
