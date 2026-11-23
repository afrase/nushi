package agentproc

import (
	"io"
	"os/exec"
	"strings"
	"testing"
)

// The line that says why: the last error-like one among the last lines,
// else the last; never a key's lines or a DEBUG line, masked and cut.
func TestTail(t *testing.T) {
	for _, tc := range []struct{ name, in, want string }{
		{"node", "/app/x.js:1\nError: Cannot find module 'x'\n    at Module._resolveFilename (node:internal/modules:1)\n\nNode.js v22.1.0\n", "Error: Cannot find module 'x'"},
		{"bun", "error: Could not resolve \"y\"\n    at /app/y.ts:3\n\nBun v1.2.0 (macOS arm64)\n", `error: Could not resolve "y"`},
		{"hint", "Error: no\nHint: try\n", "Error: no"},
		{"go panic", "panic: boom\n\ngoroutine 1 [running]:\nmain.main()\n", "panic: boom"},
		{"plain", "starting\nlistening\n", "listening"},
		{"unterminated", "starting\nError: half", "Error: half"},
		{"old error", "Error: early\n" + strings.Repeat("fine\n", whyWindow) + "last\n", "last"},
		{"key", "Error: before\n-----BEGIN OPENSSH PRIVATE KEY-----\nerrorb3BlbnNzaC1rZXk\n-----END OPENSSH PRIVATE KEY-----\n", "Error: before"},
		{"debug", "Error: real\n" + DebugPrefix + "pig-acp: rpc prompt error\n", "Error: real"},
		{"secret", "Error: bad key sk-ant-abcdefghijklmnopqrstuvwxyz\n", "Error: bad key [redacted]"},
		{"long", "Error: " + strings.Repeat("é", 400) + "\n", "Error: " + strings.Repeat("é", (maxWhy-7)/2) + "…"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var tl tail
			if _, err := io.WriteString(&tl, tc.in); err != nil {
				t.Fatal(err)
			}
			if got := tl.String(); got != tc.want {
				t.Errorf("got %q, want %q", got, tc.want)
			}
		})
	}
}

// Why says how the agent ended and its line that says why, once it has;
// one Connect made says nothing.
func TestWhy(t *testing.T) {
	a, err := Start(exec.Command("sh", "-c", `echo "Error: boom" >&2; echo "Node.js v22" >&2; exit 1`), quiet{}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if got := a.Why(); got != "exit 1: Error: boom" {
		t.Errorf("why %q", got)
	}

	a, err = Start(exec.Command("sh", "-c", "exit 2"), quiet{}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if got := a.Why(); got != "exit 2" {
		t.Errorf("why %q", got)
	}

	if got := Connect(nil, nil).Why(); got != "" {
		t.Errorf("a connected agent's why %q", got)
	}
}
