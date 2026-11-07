// Command fakeagent runs the fake ACP agent on stdin and stdout, slowed
// down so its scripts can be watched in the app. It reopens any session
// (replaying nothing), FAKEAGENT_LOAD_DELAY (a duration) after it's asked,
// and takes images (the phone's end-to-end test sends one).
package main

import (
	"os"
	"time"

	"github.com/afrase/nushi/internal/acptest"
)

func main() {
	delay, _ := time.ParseDuration(os.Getenv("FAKEAGENT_LOAD_DELAY"))
	a := &acptest.Agent{History: &acptest.History{}, Pause: 700 * time.Millisecond, Stderr: os.Stderr, LoadAny: true, LoadDelay: delay, Images: true}
	a.Serve(os.Stdin, os.Stdout)
}
