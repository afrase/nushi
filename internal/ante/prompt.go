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

	"github.com/afrase/nushi/internal/toolcall"
)

// flatten turns a prompt into the text Ante takes as input: files become
// `@path` mentions, which Ante reads itself; an image goes to a new file in
// dir() (a folder of the bridge's own) and is mentioned the same way; an
// embedded text is quoted.
func flatten(blocks []acp.ContentBlock, dir func() (string, error)) (string, error) {
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
			path, err := saveImage(dir, block.Image)
			if err != nil {
				return "", err
			}
			token(mention(path))
		}
		prevText = block.Text != nil
	}
	return strings.TrimRight(b.String(), " "), nil
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

// saveImage writes an image to a new file in dir(). Ante reads an
// `@path` anywhere, so the folder is the bridge's own (os.MkdirTemp: 0700,
// a fresh name), not the shared one its TUI pastes into.
func saveImage(dir func() (string, error), img *acp.ImageContent) (string, error) {
	data, err := base64.StdEncoding.DecodeString(img.Data)
	if err != nil {
		return "", fmt.Errorf("the image isn't base64: %w", err)
	}
	ext := map[string]string{"image/png": ".png", "image/jpeg": ".jpg", "image/gif": ".gif", "image/webp": ".webp"}[img.MimeType]
	if ext == "" {
		return "", fmt.Errorf("Ante takes no %s images", img.MimeType)
	}
	d, err := dir()
	if err != nil {
		return "", err
	}
	name := make([]byte, 8)
	rand.Read(name)
	path := filepath.Join(d, hex.EncodeToString(name)+ext)
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL|syscall.O_NOFOLLOW, 0o600) //nolint:gosec // a new file in the bridge's private temp folder, links not followed
	if err != nil {
		return "", err
	}
	if _, err := f.Write(data); err != nil {
		_ = f.Close() // the write failed; that error is the one to return
		return "", err
	}
	return path, f.Close()
}
