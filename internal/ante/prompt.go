package ante

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/imagefit"
	"github.com/afrase/nushi/internal/toolcall"
)

// flatten turns a prompt into the text Ante takes as input: files become
// `@path` mentions, which Ante reads itself; an image goes to a new file in
// dir() (a folder of the bridge's own), made to fit what's left of the
// context (fill), and is mentioned the same way; an embedded text is
// quoted. over counts the images that couldn't be made to fit.
func flatten(blocks []acp.ContentBlock, dir func() (string, error), fill contextUse) (text string, over int, err error) {
	var images, chars int
	for _, block := range blocks {
		switch {
		case block.Image != nil:
			images++
		case block.Text != nil:
			chars += len(block.Text.Text)
		case block.Resource != nil && block.Resource.Resource.TextResourceContents != nil:
			chars += len(block.Resource.Resource.TextResourceContents.Text)
		}
	}
	room := imageRoom(fill, chars, images)
	var b strings.Builder
	token := func(t string) {
		if b.Len() > 0 && !strings.HasSuffix(b.String(), " ") && !strings.HasSuffix(b.String(), "\n") {
			b.WriteByte(' ')
		}
		b.WriteString(t + " ")
	}
	prevText := false
	for _, block := range blocks {
		switch {
		case block.Text != nil:
			if prevText {
				b.WriteString("\n\n") // a text of its own: Nushi's note of a branch renamed, before the user's
			}
			b.WriteString(block.Text.Text)
		case block.ResourceLink != nil:
			if path, ok := filePath(block.ResourceLink.URI); ok {
				token(mention(path))
			} else {
				token(block.ResourceLink.URI)
			}
		case block.Resource != nil && block.Resource.Resource.TextResourceContents != nil:
			r := block.Resource.Resource.TextResourceContents
			fmt.Fprintf(&b, "\n%s:\n%s\n", r.URI, toolcall.Fence(r.Text))
		case block.Image != nil:
			path, fits, err := saveImage(dir, block.Image, room)
			if err != nil {
				return "", 0, err
			}
			if !fits {
				over++
			}
			token(mention(path))
		}
		prevText = block.Text != nil
	}
	return strings.TrimRight(b.String(), " "), over, nil
}

func filePath(uri string) (string, bool) {
	u, err := url.Parse(uri)
	if err != nil || u.Scheme != "file" || u.Path == "" {
		return "", false
	}
	return u.Path, true
}

// mention is an `@path` Ante reads as one token: whitespace escaped.
func mention(path string) string {
	var b strings.Builder
	b.WriteByte('@')
	for _, r := range path {
		if r == ' ' || r == '\t' || r == '\n' {
			b.WriteByte('\\')
		}
		b.WriteRune(r)
	}
	return b.String()
}

// Ante leaves out every image of an input that doesn't fit its content
// budget, and its count makes a screenshot's PNG costly
// (docs/facts/ante.md's Images), so the bridge sends each image at most
// so big.
const (
	imageEdge   = 2000    // Ante makes an image with a longer edge a JPEG itself
	imageBytes  = 400_000 // an image counts as its bytes / 3 tokens: 133K at most
	imageMargin = 16_000  // tokens kept back for Ante's own text and what the last count missed
)

// imageRoom is the bytes each of an input's n images may have: imageBytes
// at most and, when the context's limit is known, half of what Ante's
// budget leaves them (0.9 × the limit, less the context in use, the input's
// chars of text and a margin), shared between them.
func imageRoom(fill contextUse, chars, n int) int {
	room := int64(imageBytes)
	if fill.limit > 0 && n > 0 {
		tokens := fill.limit*9/10 - max(fill.used, imageMargin) - imageMargin - int64(chars/4)
		room = min(room, max(tokens, 0)*3/2/int64(n))
	}
	return int(room)
}

// saveImage writes an image to a new file in dir(), scaled down and
// re-encoded when it's over room bytes (imagefit); fits is false when even
// that didn't fit, and it's written as small as it got. Ante reads an
// `@path` anywhere, so the folder is the bridge's own (os.MkdirTemp: 0700,
// a fresh name), not the shared one its TUI pastes into.
func saveImage(dir func() (string, error), img *acp.ImageContent, room int) (path string, fits bool, err error) {
	data, err := base64.StdEncoding.DecodeString(img.Data)
	if err != nil {
		return "", false, fmt.Errorf("the image isn't base64: %w", err)
	}
	if imageExt[img.MimeType] == "" {
		return "", false, fmt.Errorf("Ante takes no %s images", img.MimeType)
	}
	data, mimeType, fits := imagefit.Fit(data, img.MimeType, room, imageEdge)
	d, err := dir()
	if err != nil {
		return "", false, err
	}
	name := make([]byte, 8)
	rand.Read(name)
	path = filepath.Join(d, hex.EncodeToString(name)+imageExt[mimeType])
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL|syscall.O_NOFOLLOW, 0o600) //nolint:gosec // a new file in the bridge's private temp folder, links not followed
	if err != nil {
		return "", false, err
	}
	if _, err := f.Write(data); err != nil {
		_ = f.Close() // the write failed; that error is the one to return
		return "", false, err
	}
	return path, fits, f.Close()
}

// imageExt is each image type's file extension, which Ante goes by.
var imageExt = map[string]string{"image/png": ".png", "image/jpeg": ".jpg", "image/gif": ".gif", "image/webp": ".webp"}
