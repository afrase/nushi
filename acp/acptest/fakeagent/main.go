// Command fakeagent runs the fake ACP agent on stdin and stdout, slowed
// down so its scripts can be watched in the app.
package main

import (
	"os"
	"time"

	"github.com/afrase/nushi/acp/acptest"
)

func main() {
	a := &acptest.Agent{History: &acptest.History{}, Pause: 700 * time.Millisecond}
	a.Serve(os.Stdin, os.Stdout)
}
