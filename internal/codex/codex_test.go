package codex

import (
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// A command's output comes in pieces in _meta, then how it ended; a
// failed one says so first. As codex-acp 2.2.2 sent them.
func TestCommandOutput(t *testing.T) {
	it := model.Item{}
	if ToolCall(&it, map[string]any{"terminal_info": map[string]any{"cwd": "/r"}}, nil) {
		t.Error("a call without output took its text")
	}
	ToolCall(&it, map[string]any{"terminal_output_delta": map[string]any{"data": "a ``` b\n", "terminal_id": "c1"}}, nil)
	ToolCall(&it, map[string]any{"terminal_output_delta": map[string]any{"data": "c\n"}}, nil)
	if want := "````\na ``` b\nc\n````"; it.Text != want {
		t.Errorf("text = %q, want %q", it.Text, want)
	}
	if !ToolCall(&it, map[string]any{"terminal_exit": map[string]any{"exit_code": 2.0, "signal": nil}}, nil) {
		t.Fatal("the exit didn't take the call's text")
	}
	if want := "Exit code 2\n\n````\na ``` b\nc\n````"; it.Text != want {
		t.Errorf("text = %q, want %q", it.Text, want)
	}
	quiet := model.Item{}
	ToolCall(&quiet, map[string]any{"terminal_exit": map[string]any{"exit_code": 0.0}}, nil)
	if quiet.Text != "" {
		t.Errorf("a command that printed nothing reads %q", quiet.Text)
	}
}

func TestOther(t *testing.T) {
	q := model.Field{ID: "color", Options: []model.Option{{ID: "red"}}}
	if !Other(model.Field{ID: "color_note"}, q) || Other(model.Field{ID: "size_note"}, q) {
		t.Error("only color_note is color's note")
	}
}
