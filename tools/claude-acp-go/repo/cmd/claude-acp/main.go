// Command claude-acp is an Agent Client Protocol agent for Claude Code: an
// ACP client (Zed, or any other) starts it and talks ACP on its stdin and
// stdout, and it runs each session on the claude CLI the user installed.
// It needs no Node.
//
//	claude-acp            serve one client on stdin and stdout
//	claude-acp -version   print the version
//
// The claude it runs is $CLAUDE_CODE_EXECUTABLE, else claude on PATH. It
// logs to stderr, never a prompt or a token. SIGTERM and SIGINT close
// every session, as the end of stdin does.
package main

import (
	"fmt"
	"os"

	"github.com/afrase/nushi/claudeacp"
)

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "-version", "--version":
			fmt.Println("claude-acp", claudeacp.Version) //nolint:forbidigo // -version's answer
			return
		default:
			fmt.Fprintln(os.Stderr, "usage: claude-acp [-version]\n\nAn ACP client starts claude-acp and talks to it on its stdin and stdout.")
			os.Exit(2)
		}
	}
	claudeacp.Main()
}
