package api

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/afrase/nushi/internal/features/tools"
)

// Tools serves a chat's tools to its `nushid tools-mcp` (ADR 0043), on the
// socket beside the API: /tools/list and /tools/call, the chat's key as
// the bearer token. A key grants that chat's tools and nothing else; the
// client token isn't asked for, nor accepted in its place.
func Tools(t *tools.Service) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if r.Method != http.MethodPost {
			http.Error(w, "POST only", http.StatusMethodNotAllowed)
			return
		}
		var out any
		switch r.URL.Path {
		case "/tools/list":
			list, err := t.List(key)
			if err != nil {
				http.Error(w, err.Error(), http.StatusUnauthorized)
				return
			}
			if list == nil {
				list = []tools.Tool{}
			}
			out = map[string]any{"tools": list}
		case "/tools/call":
			var req struct {
				Name      string          `json:"name"`
				Arguments json.RawMessage `json:"arguments"`
			}
			if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&req); err != nil {
				http.Error(w, "a tool call's JSON", http.StatusBadRequest)
				return
			}
			text, err := t.Call(r.Context(), key, req.Name, req.Arguments)
			if errors.Is(err, tools.ErrKey) {
				http.Error(w, err.Error(), http.StatusUnauthorized)
				return
			}
			if err != nil {
				text = err.Error()
			}
			out = map[string]any{"text": text, "isError": err != nil}
		default:
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(out) // a failed write is the client gone
	})
}
