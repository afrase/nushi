// Package claudetest is a fake claude for testing code built on
// claudeagent: a Spawner that plays a script on pipes, so tests run with
// no process, no network and no login.
//
// A script is written by hand (New, with Expect, Send and the other
// steps), or replays a recorded run of the real claude (ReadCassette and
// Replay). Respond answers any line like a pattern whenever it comes, for
// requests whose timing a test doesn't fix.
//
// The commands under cmd record the real claude for such cassettes:
// claude-tee runs claude and writes its stdin and stdout as a cassette,
// fakeapi serves a scripted Messages API for it to talk to (package
// fakeapi), and mcp-echo is a stdio MCP server with one tool.
package claudetest
