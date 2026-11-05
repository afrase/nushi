package chats

import (
	"context"
	"encoding/json"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// The app hears of a side chat from Fork's answer, then loads it: nothing
// of it is published before (putting its chat's mode and picks on it),
// which the app, not knowing the id yet, would take for a chat of the
// sidebar's. What it says afterwards is published as for any chat.
func TestASideChatIsUnheardOfUntilForkAnswers(t *testing.T) {
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	var mu sync.Mutex
	var heard []model.Event
	heardOf := func() int {
		mu.Lock()
		defer mu.Unlock()
		return len(heard)
	}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Publish: func(e model.Event) {
		mu.Lock()
		defer mu.Unlock()
		if e.ChatID == "fork1" {
			heard = append(heard, e)
		}
	}})
	t.Cleanup(svc.Close)
	ctx := context.Background()
	id, err := svc.Start(ctx, "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, svc.SetConfig(ctx, id, "mode", "plan"))
	testcheck.NoErr(t, svc.SetConfig(ctx, id, "model", "sonnet"))
	side, err := svc.Fork(ctx, id)
	testcheck.NoErr(t, err)
	if n := heardOf(); n != 0 {
		t.Errorf("%d events of the side chat before Fork answered", n)
	}
	testcheck.NoErr(t, svc.SetConfig(ctx, side, "mode", "default"))
	if heardOf() == 0 {
		t.Error("the side chat's change reached nobody")
	}
}
