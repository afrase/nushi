package pig

import (
	"fmt"
	"net/url"
	"strings"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/toolcall"
)

// image is an image as pig's prompt takes it: base64, with its type.
type image struct {
	Type     string `json:"type"`
	Data     string `json:"data"`
	MimeType string `json:"mimeType"`
}

// flatten turns a prompt into pig's message and images: a file becomes an
// `@path` mention, as in PiG's own editor, which the model reads with its
// tools; an embedded text is quoted.
func flatten(blocks []acp.ContentBlock) (string, []image) {
	var b strings.Builder
	var images []image
	for _, block := range blocks {
		switch {
		case block.Text != nil:
			b.WriteString(block.Text.Text)
		case block.ResourceLink != nil:
			uri := block.ResourceLink.URI
			if u, err := url.Parse(uri); err == nil && u.Scheme == "file" && u.Path != "" {
				uri = "@" + u.Path
			}
			if b.Len() > 0 && !strings.HasSuffix(b.String(), " ") && !strings.HasSuffix(b.String(), "\n") {
				b.WriteByte(' ')
			}
			b.WriteString(uri)
		case block.Resource != nil && block.Resource.Resource.Text != "":
			r := block.Resource.Resource
			fmt.Fprintf(&b, "\n%s:\n%s\n", r.URI, toolcall.Fence(r.Text))
		case block.Image != nil:
			images = append(images, image{Type: "image", Data: block.Image.Data, MimeType: block.Image.MimeType})
		}
	}
	return b.String(), images
}
