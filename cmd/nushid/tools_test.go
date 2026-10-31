package main

import (
	"os"
	"regexp"
	"testing"
)

// An agent can never merge through Nushi (ADR 0069): the only tool sets a
// chat's MCP server serves are Jira's and the preview's. A new set is a
// change to this test, and it must not reach a merge.
func TestAgentsGetNoGitHubTools(t *testing.T) {
	main, err := os.ReadFile("main.go")
	if err != nil {
		t.Fatal(err)
	}
	m := regexp.MustCompile(`tools\.New\((.*)\)`).FindAllSubmatch(main, -1)
	if len(m) != 1 || string(m[0][1]) != "jiraSvc.Tools(), shows" {
		t.Fatalf("the sets of a chat's tools changed: %q", m)
	}
}
