// Package launchfile reads a folder's dev servers from its launch files,
// .agents/launch.json and .claude/launch.json, in Claude desktop's format
// (ADR 0095; docs/facts/claude.md says what Claude does with them): JSON
// with comments, merged by name, each entry resolved in the folder and
// checked. It only reads; nothing here runs a server.
package launchfile
