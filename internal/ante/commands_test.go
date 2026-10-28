package ante

import (
	"context"
	"slices"
	"strings"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/ante/antetest"
)

// commands is the session's last commands list, as name:hint.
func (c *client) commands(sid acp.SessionID) []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []string
	for _, n := range c.updates {
		if u := n.Update.AvailableCommandsUpdate; n.SessionID == sid && u != nil {
			out = []string{}
			for _, cmd := range u.AvailableCommands {
				h := ""
				if cmd.Input != nil && cmd.Input.Unstructured != nil {
					h = cmd.Input.Unstructured.Hint
				}
				out = append(out, cmd.Name+":"+h)
			}
		}
	}
	return out
}

func (c *client) waitCommands(t *testing.T, sid acp.SessionID, want []string) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for !slices.Equal(c.commands(sid), want) {
		if time.Now().After(deadline) {
			t.Fatalf("commands %v, want %v", c.commands(sid), want)
		}
		time.Sleep(10 * time.Millisecond)
	}
}

// Ante's skills are slash commands beside the bridge's own: a skill runs
// with SlashCommand, /model and /effort through UpdateSession and
// /compact through Compact, none of them sent to the model as input.
func TestSlashCommands(t *testing.T) {
	ctx := context.Background()
	c := start(t, &antetest.Store{Home: t.TempDir()})
	s, err := c.NewSession(ctx, &acp.NewSessionRequest{Cwd: "/work"})
	if err != nil {
		t.Fatal(err)
	}
	sid := s.SessionID
	c.waitCommands(t, sid, []string{"model:model id", "effort:level", "compact:what to keep", "review:<path>"})
	prompt(t, c, sid, "an mcp server comes online") // an ExtensionRefreshed with one more skill
	c.waitCommands(t, sid, []string{"model:model id", "effort:level", "compact:what to keep", "review:<path>", "late:"})

	prompt(t, c, sid, "/review src/a.go")
	prompt(t, c, sid, "/nosuch x")
	for _, p := range []string{"/model m2", "/model", "/model m1", "/effort high", "/effort"} {
		if r := prompt(t, c, sid, p); r.StopReason != "end_turn" {
			t.Errorf("%s: %+v", p, r)
		}
	}
	if _, err := c.Prompt(ctx, &acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "/effort bogus"}}}}); err == nil {
		t.Error("/effort bogus: no error")
	}
	if r := prompt(t, c, sid, "/compact keep dates"); r.StopReason != "end_turn" {
		t.Errorf("compact: %+v", r)
	}

	var got []string
	for _, m := range c.texts(sid) {
		got = append(got, strings.SplitN(m, ":", 3)[2])
	}
	want := []string{"You said: an mcp server comes online", "You said: <skill>\n<name>review</name>\n\nReview src/a.go\n</skill>",
		"You said: /nosuch x", "Model: m2", "Model: m2", "Model: m1", "Effort: high", "Effort: high"}
	if !slices.Equal(got, want) {
		t.Errorf("messages:\n%q\nwant\n%q", got, want)
	}
	c.mu.Lock()
	all := mustJSON(t, c.updates)
	c.mu.Unlock()
	if !strings.Contains(c.kinds(sid), "tool_call tool_call_update") || !strings.Contains(all, `"title":"Compact conversation"`) || !strings.Contains(all, `"text":"the summary"`) {
		t.Errorf("no compaction shown: %s", c.kinds(sid))
	}
	if opts := c.lastOptions(sid); len(opts) < 2 || opts[0].Select.CurrentValue != "m1" || opts[1].Select.CurrentValue != "high" {
		t.Errorf("options %+v", opts)
	}
}

func (c *client) lastOptions(sid acp.SessionID) []acp.SessionConfigOption {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []acp.SessionConfigOption
	for _, n := range c.updates {
		if u := n.Update.ConfigOptionUpdate; n.SessionID == sid && u != nil {
			out = u.ConfigOptions
		}
	}
	return out
}

func TestSkillRunTitle(t *testing.T) {
	for in, want := range map[string]string{
		"<skill>\n<name>greet</name>\n<path>/x/SKILL.md</path>\n\nSay hello": "/greet",
		"hello":                      "hello",
		"<skill>\n<name>a\nb</name>": "<skill>\n<name>a\nb</name>",
	} {
		if got := skillRun(in); got != want {
			t.Errorf("skillRun(%q) = %q, want %q", in, got, want)
		}
	}
}
