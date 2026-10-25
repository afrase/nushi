package jira

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/model"
)

func TestTools(t *testing.T) {
	s, _, opened := newService(t)
	if _, err := s.AddSite(t.Context(), "https://acme.atlassian.net", "me@acme.com", "good", time.Time{}); err != nil {
		t.Fatal(err)
	}
	c := (*opened)[0]
	set := s.Tools()
	if len(set.Tools(tools.Grant{Chat: "c0"})) != 0 || set.Instructions(tools.Grant{Chat: "c0"}) != "" {
		t.Error("tools for a chat without an issue")
	}
	g := tools.Grant{Chat: "c1", Agent: "claude", Issue: &model.ChatIssue{Site: "acme.atlassian.net", Key: "ACME-12",
		Summary: "Log in with\na \"passkey\""}}
	// The agent knows its issue from the tools alone: nothing in the box.
	want := `This chat works on Jira issue ACME-12 ("Log in with a \"passkey\""), https://acme.atlassian.net/browse/ACME-12. `
	if got := set.Instructions(g); !strings.HasPrefix(got, want) || !strings.HasSuffix(got, "These tools reach ACME-12 only.") {
		t.Errorf("instructions %q", got)
	}
	old := tools.Grant{Issue: &model.ChatIssue{Site: "acme.atlassian.net", Key: "ACME-12"}} // a chat from before summaries
	if got := set.Instructions(old); !strings.HasPrefix(got, "This chat works on Jira issue ACME-12, https://") {
		t.Errorf("instructions %q", got)
	}
	var names []string
	for _, tl := range set.Tools(g) {
		names = append(names, tl.Name)
		var schema map[string]any
		if err := json.Unmarshal(tl.InputSchema, &schema); err != nil || !strings.Contains(tl.Description, `ACME-12 ("Log in with a \"passkey\""), the Jira issue this chat works on`) {
			t.Errorf("%s: %v, %q", tl.Name, err, tl.Description)
		}
	}
	if strings.Join(names, " ") != "jira_issue jira_comment jira_transitions jira_transition" {
		t.Errorf("tools %v", names)
	}
	call := func(tool, args string) (string, error) { return set.Call(t.Context(), g, tool, json.RawMessage(args)) }

	// Another issue is refused, whatever the tool.
	for _, tool := range names {
		if _, err := call(tool, `{"key":"ACME-9","body":"x","transition":"41"}`); err == nil || !strings.Contains(err.Error(), "ACME-12 only") {
			t.Errorf("%s on another issue: %v", tool, err)
		}
	}
	if _, err := call("jira_comment", `{"key":"acme-12","body":"Done: **tests** pass"}`); err != nil || c.comment != "Done: **tests** pass" {
		t.Errorf("comment: %v, %q", err, c.comment)
	}
	list, err := call("jira_transitions", `{}`)
	if err != nil || !strings.Contains(list, `- 41: Done (to `) || !strings.Contains(list, `field resolution "Resolution"`) {
		t.Errorf("transitions %q, %v", list, err)
	}
	if _, err := call("jira_transition", `{"transition":"Done","fields":{"resolution":"1"}}`); err != nil || len(c.moves) != 1 {
		t.Errorf("move: %v, %v", err, c.moves)
	}
	writes := s.Writes("acme.atlassian.net", "ACME-12")
	if len(writes) != 2 || writes[0].Kind != "comment" || writes[0].Comment != "1" || writes[1].Kind != "move" || writes[1].Chat != "c1" || writes[1].Agent != "claude" {
		t.Errorf("writes %+v", writes)
	}
	if md, err := call("jira_issue", ``); err != nil || !strings.HasPrefix(md, "# ACME-12") {
		t.Errorf("issue %q, %v", md, err)
	}
}
