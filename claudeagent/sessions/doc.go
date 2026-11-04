// Package sessions reads and changes the transcripts the claude CLI keeps
// on disk: listing a folder's sessions, one session's details and
// messages, its subagents' messages and queued prompts, forking a session
// (whole or up to a message) and deleting one. A Store holds them.
//
// claude keeps each session as <config>/projects/<folder>/<id>.jsonl, the
// folder named after the session's working directory, and its subagents'
// transcripts under <folder>/<id>/subagents/. The layout is claude's own
// and undocumented; Anthropic's Agent SDKs read and write it the same way,
// and this package is a port of the Python SDK's helpers (see NOTICE).
//
// Session ids must be UUIDs (ErrInvalidID otherwise), so an id can never
// name a path outside the config folder. Reading is lenient: a line that
// isn't JSON is skipped, as claude skips it.
package sessions
