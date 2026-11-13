package codex

import (
	"encoding/json"
	"testing"

	acp "github.com/afrase/acp-go/unstable"
)

// Forking at a message goes to codex-acp as the vendor meta it honors,
// exactly: a wrong shape would make it fork the whole thread without a
// word. Another agent (or none named) gets no way to fork at a message.
func TestForkAt(t *testing.T) {
	fork := Harness{}.ForkAt(&acp.InitializeResponse{AgentInfo: &acp.Implementation{Name: "@agentclientprotocol/codex-acp"}})
	if fork == nil {
		t.Fatal("codex-acp can't fork at a message")
	}
	got, err := json.Marshal(fork("m-1"))
	if err != nil {
		t.Fatal(err)
	}
	if want := `{"jetbrains":{"air":{"fork":{"messageId":"m-1","version":1}}}}`; string(got) != want {
		t.Errorf("meta %s, want %s", got, want)
	}
	for _, init := range []*acp.InitializeResponse{{}, {AgentInfo: &acp.Implementation{Name: "codex-acp-fork"}}} {
		if (Harness{}).ForkAt(init) != nil {
			t.Errorf("%+v forks at a message", init.AgentInfo)
		}
	}
}
