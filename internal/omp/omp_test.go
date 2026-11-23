package omp

import (
	"testing"

	"github.com/afrase/nushi/internal/model"
)

func TestACommandsTitle(t *testing.T) {
	it := model.Item{ToolKind: "execute", Title: "$ echo hi"}
	if harness.ToolCall(&it, nil, nil) || it.Title != "echo hi" {
		t.Errorf("title %q", it.Title)
	}
	other := model.Item{ToolKind: "read", Title: "$ x"}
	harness.ToolCall(&other, nil, nil)
	if other.Title != "$ x" {
		t.Errorf("a read's title changed: %q", other.Title)
	}
}

var harness Harness
