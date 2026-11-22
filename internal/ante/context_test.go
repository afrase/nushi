package ante

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// Ante's context report names the conversation and the buffer as parts,
// so the app needn't know the names it gives them.
func TestContextParts(t *testing.T) {
	call := func(_ context.Context, method string, _, result any) error {
		if method != ContextMethod {
			t.Errorf("method = %q", method)
		}
		return json.Unmarshal([]byte(`{"system_prompt_tokens":1000,"messages_tokens":4000,
			"used_tokens":5000,"limit_tokens":100000,"compact_buffer_tokens":20000}`), result)
	}
	u, err := Harness{}.Context(t.Context(), call, "s1")
	if err != nil {
		t.Fatal(err)
	}
	parts := map[string]string{}
	for _, c := range u.Categories {
		if c.Part != "" {
			parts[c.Part] = c.Name
		}
	}
	if parts[model.PartMessages] != "Messages" || parts[model.PartBuffer] != "Autocompact buffer" || len(parts) != 2 {
		t.Errorf("parts = %v", parts)
	}
}
