// Derived from claude-agent-acp (https://github.com/agentclientprotocol/claude-agent-acp),
// v0.94.0, its list of the markers a replayed user message is cleaned of
// and the commands it hides (dist/acp-agent.js, replaySessionHistory).
// Copyright 2025 Zed Industries, Inc. and contributors. Licensed under the
// Apache License, Version 2.0 (see NOTICE). Modified: rewritten in Go for
// claudeacp.

package claudeacp

import (
	"regexp"
	"slices"
	"strings"
)

// What claude writes into a user message besides what the user typed: a
// slash command it ran as tags naming it, the command's output, and
// context it adds (reminders, tasks' ends). A replay shows the user's
// words, and a command as the user typed it.

// injected are the tags whose text the user didn't write, removed whole.
var injected = regexp.MustCompile(`(?s)<(system-reminder|task-notification|local-command-stdout|local-command-stderr|local-command-caveat|command-message)>.*?</(?:system-reminder|task-notification|local-command-stdout|local-command-stderr|local-command-caveat|command-message)>`)

var (
	commandName = regexp.MustCompile(`(?s)<command-name>(.*?)</command-name>`)
	commandArgs = regexp.MustCompile(`(?s)<command-args>(.*?)</command-args>`)
)

// hiddenReplay are the commands a replay leaves out: what they printed
// isn't replayed, so the command alone would say nothing.
var hiddenReplay = []string{"context", "heapdump", "extra-usage", "compact", "model", "mcp", "status", "usage"}

// userText is a user message's text as the user wrote it; false when
// nothing of it is the user's, or it is a command a replay hides.
func userText(text string) (string, bool) {
	if m := commandName.FindStringSubmatch(text); m != nil {
		name := strings.TrimSpace(m[1])
		if slices.Contains(hiddenReplay, strings.TrimPrefix(name, "/")) {
			return "", false
		}
		if !strings.HasPrefix(name, "/") {
			name = "/" + name
		}
		if a := commandArgs.FindStringSubmatch(text); len(a) > 1 && strings.TrimSpace(a[1]) != "" {
			name += " " + strings.TrimSpace(a[1])
		}
		return name, true
	}
	text = strings.TrimSpace(injected.ReplaceAllString(text, ""))
	return text, text != ""
}

var (
	notification = regexp.MustCompile(`(?s)<task-notification>(.*?)</task-notification>`)
	taskID       = regexp.MustCompile(`(?s)<task-id>(.*?)</task-id>`)
	taskStatus   = regexp.MustCompile(`(?s)<status>(.*?)</status>`)
	taskSummary  = regexp.MustCompile(`(?s)<summary>(.*?)</summary>`)
)

// taskNote is what a task notification says of a task's end.
type taskNote struct{ id, status, summary string }

// taskEnds are the task notifications in a user message's text, in order.
func taskEnds(text string) []taskNote {
	var out []taskNote
	for _, n := range notification.FindAllStringSubmatch(text, -1) {
		field := func(re *regexp.Regexp) string {
			if m := re.FindStringSubmatch(n[1]); m != nil {
				return strings.TrimSpace(m[1])
			}
			return ""
		}
		if id := field(taskID); id != "" {
			out = append(out, taskNote{id: id, status: field(taskStatus), summary: field(taskSummary)})
		}
	}
	return out
}
