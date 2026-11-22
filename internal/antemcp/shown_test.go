package antemcp

import (
	"context"
	"encoding/json"
	"reflect"
	"testing"

	"github.com/afrase/nushi/internal/features/mcp"
)

// Servers come in the shape Nushi's form writes: Ante's "transport" goes,
// a URL's server says "type" "http"; the rest is kept as stored.
func TestServersInTheFormsShape(t *testing.T) {
	home(t, `{"mcp_servers": {
		"api": {"url": "https://api.example.com/mcp", "transport": "streamable-http", "headers": {"Authorization": "Bearer s3cret"}, "enabled_tools": ["a"]},
		"bare": {"url": "https://bare.example.com/mcp", "args": [], "env": {}, "enabled_tools": []},
		"fs": {"command": "fs-mcp", "transport": "stdio"},
		"old": {"url": "https://old.example.com/sse", "transport": "sse"}
	}}`)
	got, err := Ante{}.Servers("/any")
	if err != nil {
		t.Fatal(err)
	}
	want := map[string]map[string]any{
		"api":  {"type": "http", "url": "https://api.example.com/mcp", "headers": map[string]any{"Authorization": "Bearer s3cret"}, "enabled_tools": []any{"a"}},
		"bare": {"type": "http", "url": "https://bare.example.com/mcp", "enabled_tools": []any{}},
		"fs":   {"command": "fs-mcp"},
		"old":  {"type": "sse", "url": "https://old.example.com/sse"},
	}
	for _, sv := range got {
		var c map[string]any
		if err := json.Unmarshal([]byte(sv.Config), &c); err != nil || !reflect.DeepEqual(c, want[sv.Name]) {
			t.Errorf("%s = %s, want %v", sv.Name, sv.Config, want[sv.Name])
		}
	}
}

// An Ante server edited as the app sends it back (its secret masked, the
// rest as shown) keeps its secret and goes back in Ante's shape; one
// whose other parts changed has to have its secret typed again.
func TestEditingAnAnteServerRoundTrips(t *testing.T) {
	path := home(t, `{"mcp_servers": {
		"api": {"url": "https://api.example.com/mcp", "transport": "streamable-http", "headers": {"Authorization": "Bearer s3cret"}, "args": [], "env": {}, "enabled_tools": ["a"]}
	}}`)
	ctx := context.Background()
	svc := mcp.New("ante", Ante{}, nil)
	list, _, err := svc.List(ctx, "/f", false)
	if err != nil || len(list) != 1 {
		t.Fatalf("list = %+v, %v", list, err)
	}
	if err := svc.Edit(ctx, "/f", "user", "api", list[0].Config); err != nil {
		t.Fatalf("sent back as shown: %v", err)
	}
	want := map[string]any{"url": "https://api.example.com/mcp", "headers": map[string]any{"Authorization": "Bearer s3cret"}, "enabled_tools": []any{"a"}}
	if got := servers(t, path)["api"]; !reflect.DeepEqual(got, want) {
		t.Errorf("api = %v, want %v", got, want)
	}
	var changed map[string]any
	if err := json.Unmarshal([]byte(list[0].Config), &changed); err != nil {
		t.Fatal(err)
	}
	changed["url"] = "https://other.example.com/mcp"
	b, _ := json.Marshal(changed) // decoded from JSON, so it encodes
	if err := svc.Edit(ctx, "/f", "user", "api", string(b)); err == nil {
		t.Error("a changed server kept its masked secret")
	}
	if got := servers(t, path)["api"]; !reflect.DeepEqual(got, want) {
		t.Errorf("after a refused edit: api = %v, want %v", got, want)
	}
}
