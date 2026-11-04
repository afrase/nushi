# claude-acp-go

An [Agent Client Protocol](https://agentclientprotocol.com) agent for Claude Code, written in Go, and the Go library it is built on.

`claude-acp` lets Zed and other ACP clients run Claude Code without Node: a single static binary that speaks ACP to the editor and runs your own `claude` CLI for each session. It behaves like [claude-agent-acp](https://github.com/agentclientprotocol/claude-agent-acp), the Node agent ACP clients run today, so a client written for one works with the other.

This project is unofficial and not affiliated with or endorsed by Anthropic. It contains no authentication code and never touches your credentials: it runs the unmodified `claude` you installed, which signs in as it always does.

## Why

- **No Node.** claude-agent-acp needs Node and an npm install, and runs a Node process beside each `claude`. `claude-acp` is one Go binary.
- **Your claude.** It runs the `claude` on your `PATH` (or `$CLAUDE_CODE_EXECUTABLE`), with your login, settings, `CLAUDE.md`, hooks, skills, plugins and MCP servers, as in the terminal. Sessions are claude's own: one started here resumes in the terminal with `claude --resume`, and the other way round.
- **Readable.** The protocol code is plain Go you can read and step through, with no bundled SDK in between.

## Install

You need [Claude Code](https://code.claude.com/docs/en/setup) installed and signed in (run `claude` once in a terminal), and Go 1.27.3 or later to build:

```sh
go install github.com/afrase/claude-acp-go/cmd/claude-acp@latest
```

The binary lands in `$(go env GOPATH)/bin`. `claude-acp -version` prints its version.

## Use it from Zed

Add the agent to Zed's `settings.json`, with the binary's full path (Zed doesn't start agents through your shell):

```json
{
  "agent_servers": {
    "Claude (claude-acp-go)": {
      "type": "custom",
      "command": "/Users/you/go/bin/claude-acp",
      "args": [],
      "env": {}
    }
  }
}
```

Then pick it in the Agent Panel's new-thread menu. If `claude` isn't on the `PATH` Zed gives agents, name it: `"env": {"CLAUDE_CODE_EXECUTABLE": "/opt/homebrew/bin/claude"}`.

Any other ACP client starts it the same way: run `claude-acp` and speak ACP on its stdin and stdout. It logs to stderr.

## Use it as a library

The module has four packages:

| Package | What it is |
|---|---|
| `claudeagent` | A client for the `claude` CLI's stream-JSON control protocol, the one Anthropic's Agent SDKs use: sessions, one-shot queries, typed messages, permission callbacks, hooks, MCP elicitations, control requests. Standard library only. |
| `claudeagent/sessions` | claude's transcripts on disk: list, read, fork and delete sessions. |
| `claudeagent/claudetest` | A scripted fake `claude` and recorded cassettes, to test code built on `claudeagent` with no process or login. |
| `claudeacp` | The ACP agent, on `claudeagent` and [acp-go](https://github.com/afrase/acp-go): `Serve` it on any streams, or `Main` on stdin and stdout. |

One prompt, its answer and its cost:

```go
package main

import (
	"context"
	"fmt"
	"log"

	"github.com/afrase/claude-acp-go/claudeagent"
)

func main() {
	ctx := context.Background()
	for m, err := range claudeagent.Query(ctx, "What does this repository do?", claudeagent.Options{}) {
		if err != nil {
			log.Fatal(err)
		}
		switch m := m.(type) {
		case *claudeagent.Assistant:
			for _, b := range m.Message.Content {
				if b.Type == "text" {
					fmt.Print(b.Text)
				}
			}
		case *claudeagent.Result:
			fmt.Printf("\n(%d turns, $%.4f)\n", m.NumTurns, m.TotalCostUSD)
		}
	}
}
```

`claudeagent.Start` keeps a session open for more prompts, steering, interrupts and model or mode changes; `Options.CanUseTool` answers claude's permission requests. Each package's documentation has runnable examples: `go doc github.com/afrase/claude-acp-go/claudeagent`.

## How it relates to the others

- **claude-agent-acp** (Zed Industries, Apache-2.0) is the Node ACP agent for Claude Code. `claudeacp` follows its behaviour and wire shape (session and message ids, `_meta.claudeCode`, `_claude/origin`, modes, config options, the JetBrains fork-at extension), so clients need no changes. It is written fresh in Go; where a file is translated from claude-agent-acp, it says so, and `claudeacp/NOTICE` carries the licence.
- **Anthropic's Agent SDKs** (Python, MIT; TypeScript) drive `claude` over the same stream-JSON protocol. `claudeagent` is a Go client for that protocol; `claudeagent/sessions` is ported from the Python SDK's session helpers (`claudeagent/NOTICE`). Nothing comes from the TypeScript SDK or from the `claude` binary.
- The protocol is undocumented. The package parses leniently (unknown messages arrive as `Unknown`, raw JSON is kept), detects features from what `claude` says it supports, and pins no `claude` version. A change in `claude` can still break it, as it can the official SDKs.

## What's supported

- Sessions: new, load (with the history replayed), resume, fork (whole, or up to a message), list, delete, close; additional directories; a system prompt to append or override.
- Prompts with text, images and embedded resources; prompts sent mid-turn are queued as `claude` queues them, or steer the running turn (`_session/steering`); cancel.
- Every permission `claude` asks for goes to the client, with "always allow" options worded per tool; the agent never allows anything itself. Modes: default, accept edits, plan, auto, bypass permissions (when allowed).
- Config options: model, effort, fast mode, agent. Plans from claude's to-do tools. AskUserQuestion as a form (when the client takes form elicitation). Slash commands. Usage, cost and the context window. Session titles.
- MCP servers from the client (stdio, HTTP, SSE); an MCP server's form or sign-in page passed to the client when it takes them.
- Subagents as sessions of their own (the ACP subagents RFD), each stoppable, for clients that take them; notices of claude's own.

Not supported: ACP's `authenticate` (there is nothing to authenticate: sign in with `claude` itself; when `claude` isn't signed in, prompts fail with its own message), MCP servers over ACP's own transport, and the client's file-system and terminal capabilities (claude's tools run on the machine, as in the terminal). Windows isn't tested.

## Development

```sh
go build ./... && go vet ./... && go test -race ./...
```

The tests run fake `claude`s and need no login. `claudeagent/claudetest/cmd` holds the tools that record the real `claude` against a fake Messages API (`fakeapi`), for new cassettes.

## Licence and credits

MIT: see [LICENSE](LICENSE). Parts are derived from:

- the [Claude Agent SDK for Python](https://github.com/anthropics/claude-agent-sdk-python), MIT, Copyright (c) 2025 Anthropic, PBC (`claudeagent/NOTICE`);
- [claude-agent-acp](https://github.com/agentclientprotocol/claude-agent-acp), Apache-2.0, Copyright 2025 Zed Industries, Inc. and contributors (`claudeacp/NOTICE`).

Claude and Claude Code are trademarks of Anthropic, PBC. Using this software is using Claude Code, under the terms that cover your Anthropic account.
