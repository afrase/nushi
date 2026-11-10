package opencode

import (
	"errors"
	"fmt"
	"reflect"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

func TestInfo(t *testing.T) {
	want := model.HarnessInfo{
		Name: "opencode", Title: "OpenCode", Resume: "opencode --session",
		InitMeta: map[string]any{"opencode/child-session-updates": true},
	}
	if got := harness.Info(); !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v", got)
	}
}

// The free-text field of a question is the one named for the choices
// before it.
func TestOther(t *testing.T) {
	q0 := model.Field{ID: "q0", Options: []model.Option{{ID: "red", Name: "Red"}}}
	for _, c := range []struct {
		field, before model.Field
		want          bool
	}{
		{model.Field{ID: "q0_custom"}, q0, true},
		{model.Field{ID: "q1"}, q0, false},
		{model.Field{ID: "q1_custom"}, q0, false},
		{model.Field{ID: "q0_custom", Options: q0.Options}, q0, false},
	} {
		if got := harness.Other(c.field, c.before); got != c.want {
			t.Errorf("Other(%s after %s) = %v", c.field.ID, c.before.ID, got)
		}
	}
}

// The errors are opencode 2.2.6's own, from session/load.
func TestGone(t *testing.T) {
	invalid := func(message string) error {
		return fmt.Errorf("session/load: %w", &acp.Error{Code: acp.ErrorCodeInvalidParams, Message: message})
	}
	for _, c := range []struct {
		err  error
		want bool
	}{
		{invalid("Invalid params: session not found: ses_doesnotexist00000000000000"), true},
		{invalid("Invalid params: session ses_0a1b2c3d4e5f does not belong to cwd: /tmp/elsewhere"), false},
		{invalid("Invalid params: Invalid session ID"), false},
		{&acp.Error{Code: acp.ErrorCodeResourceNotFound, Message: "session not found"}, false},
		{errors.New("session not found"), false},
		{nil, false},
	} {
		if got := harness.Gone(c.err); got != c.want {
			t.Errorf("Gone(%v) = %v", c.err, got)
		}
	}
}

func TestHidesCommand(t *testing.T) {
	if harness.HidesCommand("compact") {
		t.Error("compact is hidden")
	}
	for _, name := range []string{"init", "review", "goal", "my-own", ""} {
		if !harness.HidesCommand(name) {
			t.Errorf("%q isn't hidden", name)
		}
	}
}

var harness Harness
