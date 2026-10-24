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

	"github.com/afrase/nushi/acp"
)

// flatten turns a prompt into the text Ante takes as input: files become
// `@path` mentions, which Ante reads itself; an image goes to a file in
// Ante's paste folder and is mentioned the same way; an embedded text is
// quoted.
func flatten(blocks []acp.ContentBlock) (string, error) {
	var b strings.Builder
	token := func(t string) {
		if b.Len() > 0 && !strings.HasSuffix(b.String(), " ") && !strings.HasSuffix(b.String(), "\n") {
			b.WriteByte(' ')
		}
		b.WriteString(t + " ")
	}
	for _, block := range blocks {
		switch {
		case block.Text != nil:
			b.WriteString(block.Text.Text)
		case block.ResourceLink != nil:
			if path, ok := filePath(block.ResourceLink.URI); ok {
				token(mention(path))
			} else {
				token(block.ResourceLink.URI)
			}
		case block.Resource != nil && block.Resource.Resource.Text != "":
			r := block.Resource.Resource
			fmt.Fprintf(&b, "\n%s:\n%s\n", r.URI, fence(r.Text))
		case block.Image != nil:
			path, err := saveImage(block.Image)
			if err != nil {
				return "", err
			}
			token(mention(path))
		}
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

// saveImage writes an image where Ante's own TUI puts pasted ones.
func saveImage(img *acp.ImageContent) (string, error) {
	data, err := base64.StdEncoding.DecodeString(img.Data)
	if err != nil {
		return "", fmt.Errorf("the image isn't base64: %w", err)
	}
	ext := map[string]string{"image/png": ".png", "image/jpeg": ".jpg", "image/gif": ".gif", "image/webp": ".webp"}[img.MimeType]
	if ext == "" {
		return "", fmt.Errorf("Ante takes no %s images", img.MimeType)
	}
	dir := filepath.Join(os.TempDir(), "ante-paste-cache")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	name := make([]byte, 8)
	rand.Read(name)
	path := filepath.Join(dir, "nushi-"+hex.EncodeToString(name)+ext)
	return path, os.WriteFile(path, data, 0o600)
}
