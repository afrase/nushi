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

func TestAReferenceTheCopyLacksIsLeftOut(t *testing.T) {
	s, dir := open(t)
	big := noise(t, 200, 100)
	add(t, s, "A", "", model.Item{ID: "t1", Kind: model.ToolCall, Images: []model.Image{big}})
	ref := read(t, s, "A")[0].Images[0]
	// Another chat's copy (a fork's) hasn't the file: the item is written
	// without it, beside the others, and no empty file stands for it.
	small := model.Image{MimeType: "image/png", Data: []byte("small")}
	testcheck.NoErr(t, s.Append("B", []model.Item{{ID: "t1", Kind: model.ToolCall, Images: []model.Image{ref, small}},
		{ID: "t2", Kind: model.ToolCall}}, []string{"", "t1"}))
	got := read(t, s, "B")
	if len(got) != 2 || len(got[0].Images) != 1 || string(got[0].Images[0].Data) != "small" {
		t.Fatalf("written with a reference the copy lacks: %+v", got)
	}
	testcheck.NoErr(t, s.Replace("B", []model.Item{{ID: "t1", Images: []model.Image{ref}}}))
	if got := read(t, s, "B"); len(got) != 1 || len(got[0].Images) != 0 {
		t.Fatalf("replaced with a reference the copy lacks: %+v", got)
	}
	if _, err := os.Stat(filepath.Join(dir, "B", imagesDir, big.Hash)); err == nil {
		t.Error("an image file was written for a reference")
	}
	notHash := model.Image{MimeType: "image/png", Hash: "../x", Size: model.SmallImage + 1}
	if err := s.Append("B", []model.Item{{ID: "t3", Images: []model.Image{notHash}}}, []string{""}); err == nil || !strings.Contains(err.Error(), "not a hash") {
		t.Errorf("a reference that isn't a hash: %v", err)
	}
}

// A large image whose file went is left out of what's read, as a small
// one always was, so the copy is still read and written again whole (a
// move's names, a reopen's write) and only that image is lost.
func TestALargeImageWhoseFileWentIsLeftOut(t *testing.T) {
	s, dir := open(t)
	gone, kept := noise(t, 200, 100), noise(t, 200, 100)
	add(t, s, "CHAT", "", model.Item{ID: "t1", Kind: model.ToolCall, Images: []model.Image{gone, kept}})
	add(t, s, "CHAT", "t1", model.Item{ID: "t2", Kind: model.ToolCall})
	testcheck.NoErr(t, os.Remove(filepath.Join(dir, "CHAT", imagesDir, gone.Hash)))
	items := read(t, s, "CHAT")
	if len(items) != 2 || len(items[0].Images) != 1 || items[0].Images[0].Hash != kept.Hash {
		t.Fatalf("read with a file gone: %+v", items)
	}
	items[1].Text = "renamed"
	testcheck.NoErr(t, s.Replace("CHAT", items))
	if got := read(t, s, "CHAT"); len(got) != 2 || got[1].Text != "renamed" || len(got[0].Images) != 1 || !got[0].Images[0].Ref() {
		t.Errorf("written again: %+v", got)
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
