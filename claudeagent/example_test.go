package claudeagent_test

import (
	"context"
	"fmt"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// fakeClaude is a scripted claude for the examples: it answers
// initialize and a prompt as the real one would, with no process and no
// login. Without Options.Spawner, the package runs the claude on PATH.
func fakeClaude() *claudetest.Fake {
	return claudetest.New(
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"initialize"}}`),
		claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`),
		claudetest.Expect(`{"type":"user"}`),
		claudetest.Send(`{"type":"assistant","message":{"id":"msg_1","role":"assistant","content":[{"type":"text","text":"Hello!"}]}}`),
		claudetest.Send(`{"type":"result","subtype":"success","result":"Hello!","num_turns":1,"total_cost_usd":0.0012}`),
	)
}

// Query sends one prompt and yields claude's messages up to its result.
func ExampleQuery() {
	fake := fakeClaude()
	o := claudeagent.Options{CLIPath: "/usr/local/bin/claude", Spawner: fake.Spawn}
	for m, err := range claudeagent.Query(context.Background(), "Say hello", o) {
		if err != nil {
			fmt.Println("error:", err)
			return
		}
		switch m := m.(type) {
		case *claudeagent.Assistant:
			for _, b := range m.Message.Content {
				if b.Type == "text" {
					fmt.Println("claude:", b.Text)
				}
			}
		case *claudeagent.Result:
			fmt.Printf("done in %d turn, $%.4f\n", m.NumTurns, m.TotalCostUSD)
		}
	}
	// Output:
	// claude: Hello!
	// done in 1 turn, $0.0012
}

// Start keeps claude running: Send prompts and read Messages until the
// turn's result, then Close.
func ExampleStart() {
	ctx := context.Background()
	fake := fakeClaude()
	s, err := claudeagent.Start(ctx, claudeagent.Options{CLIPath: "/usr/local/bin/claude", Spawner: fake.Spawn})
	if err != nil {
		fmt.Println("error:", err)
		return
	}
	defer func() { _ = s.Close() }()
	if _, err := s.Send(ctx, claudeagent.UserInput{Text: "Say hello"}); err != nil {
		fmt.Println("error:", err)
		return
	}
	for m := range s.Messages() {
		if r, ok := m.(*claudeagent.Result); ok {
			fmt.Println("result:", r.Result)
			break
		}
	}
	// Output:
	// result: Hello!
}
