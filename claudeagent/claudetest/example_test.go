package claudetest_test

import (
	"context"
	"fmt"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// A Fake plays a script in claude's place: each Expect waits for a line
// like the one given (fields given must match), each Send writes a line,
// "$req" standing for the last request's id. Its Spawn is a
// claudeagent.Spawner.
func ExampleNew() {
	fake := claudetest.New(
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"initialize"}}`),
		claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`),
		claudetest.ExpectEOF(),
	)
	s, err := claudeagent.Start(context.Background(), claudeagent.Options{CLIPath: "/usr/local/bin/claude", Spawner: fake.Spawn})
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println("closed:", s.Close())
	fmt.Println("script:", fake.Err())
	// Output:
	// closed: <nil>
	// script: <nil>
}
