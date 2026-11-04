// Package claudeagent drives the claude CLI (Claude Code) from Go, over
// the stream-JSON control protocol that Anthropic's own Agent SDKs use: it
// runs the user's claude as a child process, writes JSON lines to its
// stdin and reads the messages it writes on stdout.
//
// It is unofficial and not affiliated with Anthropic. It runs the
// unmodified claude found on PATH (or the one Options.CLIPath names) and
// contains no authentication code: claude signs in as it always does, with
// whatever login or API key the user gave it, and requests from claude for
// credentials are refused, never answered. Using it is using Claude Code,
// under the terms that cover the user's account.
//
// # Sessions
//
// Start runs a session: claude stays up, takes user messages (Send) and
// requests (SetModel, SetPermissionMode, Interrupt…) and writes its
// messages, which Messages delivers in order, until Close. Query is the
// one-shot form: one prompt, its messages up to the result.
//
// claude's own requests go to the callbacks in Options: CanUseTool for
// permissions, Hooks for hook events, OnElicitation for an MCP server's
// questions. Without a callback, claude decides by its settings or the
// request is declined.
//
// # The protocol
//
// The protocol has no published specification, so the package is lenient
// where the official SDKs are: every message keeps its raw JSON (Frame), a
// type or subtype it doesn't know arrives as Unknown, and nothing claude
// writes ends the stream except the end of its stdout. Features are
// detected from what claude says it supports (its answer to initialize),
// never from its version.
//
// # Processes
//
// Each session is one claude process, started in a process group of its
// own (or this one's, with Options.SharedGroup), and Close ends it: its
// stdin first, then SIGTERM and SIGKILL if it lingers. Options.Spawner
// replaces the process for tests; claudetest has a scripted fake claude.
//
// The subpackage sessions reads and changes the transcripts claude keeps
// on disk.
package claudeagent

// Version is this module's version. It names the client app in claude's
// User-Agent when Options.ClientApp is empty, and claudeacp's agent in
// its initialize answer.
const Version = "0.1.0"
