package claudeagent_test

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// Query yields the turn's messages up to its result, then closes the
// session; claude ending first is an error, with how it ended.
func TestQuery(t *testing.T) {
	user := claudetest.Expect(`{"type":"user","message":{"role":"user","content":"hi"}}`)
	for _, tc := range []struct {
		name  string
		steps []claudetest.Step
		types []string
		err   string
	}{
		{"result", []claudetest.Step{user, claudetest.Send(`{"type":"assistant","message":{"id":"m1"}}`), claudetest.Send(`{"type":"result","subtype":"success","result":"hello"}`)},
			[]string{"assistant", "result"}, ""},
		{"exit", []claudetest.Step{user, claudetest.Send(`{"type":"assistant","message":{"id":"m1"}}`), claudetest.Exit(2, "boom\n")},
			[]string{"assistant"}, "claude exited with code 2: boom"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := claudetest.New(append([]claudetest.Step{claudetest.Expect(initRequest), answer(`{}`)}, tc.steps...)...)
			var types []string
			var gotErr error
			for m, err := range claudeagent.Query(context.Background(), "hi", claudeagent.Options{CLIPath: "/claude", Env: []string{}, Spawner: f.Spawn}) {
				if err != nil {
					gotErr = err
					continue
				}
				types = append(types, m.Frame().Type)
			}
			if strings.Join(types, ",") != strings.Join(tc.types, ",") {
				t.Errorf("%v", types)
			}
			if (gotErr == nil) != (tc.err == "") || gotErr != nil && gotErr.Error() != tc.err {
				t.Errorf("%v", gotErr)
			}
			<-f.Exited()
			if tc.err == "" && f.Err() != nil {
				t.Error(f.Err())
			}
		})
	}
}

// Stopping a Query early closes the session.
func TestQueryStopped(t *testing.T) {
	f := claudetest.New(claudetest.Expect(initRequest), answer(`{}`),
		claudetest.Expect(`{"type":"user"}`),
		claudetest.Send(`{"type":"assistant","message":{"id":"m1"}}`),
	)
	for m, err := range claudeagent.Query(context.Background(), "hi", claudeagent.Options{CLIPath: "/claude", Env: []string{}, Spawner: f.Spawn}) {
		if _, ok := m.(*claudeagent.Assistant); !ok || err != nil {
			t.Errorf("%+v %v", m, err)
		}
		break
	}
	<-f.Exited()
	if f.Err() != nil {
		t.Error(f.Err())
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	for _, err := range claudeagent.Query(ctx, "hi", claudeagent.Options{CLIPath: "/claude", Env: []string{}, Spawner: claudetest.New().Spawn}) {
		if !errors.Is(err, context.Canceled) {
			t.Errorf("%v", err)
		}
	}
}
