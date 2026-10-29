// Package claudeagent is a Go client for the claude CLI's stream-JSON
// protocol: it runs the user's own claude as a child process, writes JSON
// lines to its stdin and reads the messages it writes on stdout.
//
// It is unofficial and not affiliated with Anthropic. It spawns the
// unmodified claude found on PATH (or the one Options names) and contains
// no authentication code: claude signs in as it always does.
//
// The protocol has no published specification, so the package is lenient
// where the official SDKs are: every message keeps its raw JSON, a type or
// subtype it doesn't know arrives as Unknown, and nothing claude writes
// ends the stream except the end of its stdout. Features are detected from
// what claude says it supports, never from its version.
//
// Start runs a session: claude stays up, takes user messages (Send) and
// requests (SetModel, Interrupt…) and writes its messages (Messages)
// until Close. Query is the one-shot form: one prompt, its messages up to
// the result. claude's own requests (permissions and the like) go to the
// callbacks in Options; it never gets credentials from the package.
package claudeagent

// Version is this package's version, sent as the client app's when
// Options.ClientApp is empty.
const Version = "0.1.0"
