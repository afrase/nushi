package githubapi

import (
	"encoding/json"
	"net/http"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// unseen is what a fork's workflow could put in a check's or an
// annotation's text to hide words from the reader that an agent still
// reads: a bidi override and a Unicode tag character.
const unseen = "‮\U000E0041"

// TestTextDecodesPlain: every field of a check, a commit status, an
// annotation, an issue's labels and a row's title loses what could hide
// or reorder text, as it's decoded, while line breaks stay.
func TestTextDecodesPlain(t *testing.T) {
	q := func(s string) string { return strings.ReplaceAll(s, "H", `‮󠁁`) }
	var run checkNode
	testcheck.NoErr(t, json.Unmarshal([]byte(q(`{"__typename":"CheckRun","name":"tHest","title":"tiHtle",
		"checkSuite":{"app":{"name":"apHp"},"workflowRun":{"workflow":{"name":"wHf"}}},
		"annotations":{"nodes":[{"path":"a/Hb.go","title":"Hti","message":"line H1\nline 2"}]}}`)), &run))
	c := run.check()
	a := c.Annotations[0]
	for _, s := range []string{c.Name, c.Title, c.App, c.Workflow, a.Path, a.Title, a.Message} {
		if strings.ContainsAny(s, unseen) {
			t.Fatalf("hidden text kept: %+v", c)
		}
	}
	if a.Message != "line 1\nline 2" {
		t.Fatalf("message: %q", a.Message)
	}
	var status checkNode
	testcheck.NoErr(t, json.Unmarshal([]byte(q(`{"__typename":"StatusContext","context":"ciH","description":"Hok"}`)), &status))
	if s := status.check(); s.Name != "ci" || s.Summary != "ok" {
		t.Fatalf("status: %+v", s)
	}
	f := newFake(t)
	f.route("graphql Issue", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(q(`{"data":{"repository":{"issue":{"__typename":"Issue","id":"I_1","number":2,
			"title":"a Htitle","labels":{"nodes":[{"name":"bHug"}]}}}}}`)))
	})
	is, err := f.client().Issue(t.Context(), "acme/lumen", 2)
	testcheck.NoErr(t, err)
	if is.Title != "a title" || !slices.Equal(is.Labels, []string{"bug"}) {
		t.Fatalf("issue: %q %q", is.Title, is.Labels)
	}
}
