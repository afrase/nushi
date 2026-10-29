package claudeacp

import (
	"encoding/json"
	"reflect"
	"testing"

	acp "github.com/afrase/acp-go/unstable"
)

// A prompt's blocks as claude's: text, links for files, embedded text
// after everything else, images by data or URL; the rest dropped.
func TestToClaude(t *testing.T) {
	for _, tc := range []struct {
		name   string
		prompt []acp.ContentBlock
		want   string
	}{
		{"text", []acp.ContentBlock{{Text: &acp.TextContent{Text: "hi"}}, {Text: &acp.TextContent{}}},
			`[{"type":"text","text":"hi"}]`},
		{"links", []acp.ContentBlock{
			{ResourceLink: &acp.ResourceLink{Name: "x", URI: "file:///repo/a%20b.go"}},
			{ResourceLink: &acp.ResourceLink{Name: "y", URI: "https://example.com/p"}}},
			`[{"type":"text","text":"[@a b.go](file:///repo/a%20b.go)"},{"type":"text","text":"https://example.com/p"}]`},
		{"embedded", []acp.ContentBlock{
			{Resource: &acp.EmbeddedResource{Resource: acp.EmbeddedResourceResource{TextResourceContents: &acp.TextResourceContents{URI: "file:///r/n.md", Text: "notes"}}}},
			{Text: &acp.TextContent{Text: "see"}}},
			`[{"type":"text","text":"[@n.md](file:///r/n.md)"},{"type":"text","text":"see"},{"type":"text","text":"\n<context ref=\"file:///r/n.md\">\nnotes\n</context>"}]`},
		{"images", []acp.ContentBlock{
			{Image: &acp.ImageContent{Data: "AAA", MimeType: "image/png"}},
			{Image: &acp.ImageContent{URI: "https://example.com/i.png", MimeType: "image/png"}},
			{Image: &acp.ImageContent{URI: "file:///i.png", MimeType: "image/png"}}},
			`[{"type":"image","source":{"data":"AAA","media_type":"image/png","type":"base64"}},{"type":"image","source":{"type":"url","url":"https://example.com/i.png"}}]`},
		{"dropped", []acp.ContentBlock{
			{Audio: &acp.AudioContent{Data: "x", MimeType: "audio/wav"}},
			{Resource: &acp.EmbeddedResource{Resource: acp.EmbeddedResourceResource{BlobResourceContents: &acp.BlobResourceContents{URI: "file:///b", Blob: "AA=="}}}},
			{Text: &acp.TextContent{Text: "kept"}}},
			`[{"type":"text","text":"kept"}]`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			got, err := toClaude(tc.prompt)
			if err != nil {
				t.Fatal(err)
			}
			b, _ := json.Marshal(got)
			var g, w any
			_, _ = json.Unmarshal(b, &g), json.Unmarshal([]byte(tc.want), &w)
			if !reflect.DeepEqual(g, w) {
				t.Errorf("%s\nwant %s", b, tc.want)
			}
		})
	}
	if _, err := toClaude([]acp.ContentBlock{{Audio: &acp.AudioContent{}}}); err == nil {
		t.Error("a prompt claude takes nothing of")
	}
}
