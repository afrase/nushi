package ante

import (
	"bytes"
	"context"
	"slices"
	"strings"
	"sync"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/ante/antetest"
	"github.com/afrase/nushi/internal/testcheck"
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
	if !testcheck.Eventually(func() bool { return slices.Equal(c.commands(sid), want) }) {
		t.Fatalf("commands %v, want %v", c.commands(sid), want)
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
	all := testcheck.JSON(t, c.updates)
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

// wire keeps what the bridge wrote the client, line by line.
type wire struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (w *wire) Write(p []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.b.Write(p)
}

// first is the first line that has s.
func (w *wire) first(s string) string {
	w.mu.Lock()
	defer w.mu.Unlock()
	for line := range strings.Lines(w.b.String()) {
		if strings.Contains(line, s) {
			return line
		}
	}
	return ""
}

// A new session's commands go out after the answer that names it, which
// the client needs to route them: acp.AfterResponse orders them, where a
// 200 ms sleep guessed.
func TestNewSessionsCommandsFollowItsAnswer(t *testing.T) {
	w := &wire{}
	c, _ := startOn(t, &antetest.Store{Home: t.TempDir()}, w)
	for range 3 {
		s, err := c.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: "/work"})
		if err != nil {
			t.Fatal(err)
		}
		c.waitCommands(t, s.SessionID, []string{"model:model id", "effort:level", "compact:what to keep", "review:<path>"})
		if line := w.first(string(s.SessionID)); !strings.Contains(line, `"result"`) {
			t.Errorf("the first line naming the session isn't the answer: %s", line)
		}
	}
}
