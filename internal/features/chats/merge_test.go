package chats

import (
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/model"
)

// items reads a transcript written short, items split by spaces:
// u:text a user message as Nushi has it (an id of Nushi's), U:id:text as a
// replay has it (the agent's id); m:id:text an agent message; t:id:status
// a tool call (t:id:status:compact for a compaction's); s:id:parent a
// subagent's step; n:status a notice; S the summary a replay after a
// compaction starts with. Underscores in a text are spaces.
func items(s string) []model.Item {
	var out []model.Item
	for i, w := range strings.Fields(s) {
		p := strings.Split(w, ":")
		text := func(n int) string { return strings.ReplaceAll(p[n], "_", " ") }
		var it model.Item
		switch p[0] {
		case "u":
			it = model.Item{ID: "item-" + string(rune('a'+i)), Kind: model.UserMessage, Text: text(1)}
		case "U":
			it = model.Item{ID: p[1], Kind: model.UserMessage, Text: text(2)}
		case "m":
			it = model.Item{ID: p[1], Kind: model.AgentMessage, Text: text(2)}
		case "t":
			it = model.Item{ID: p[1], Kind: model.ToolCall, Title: "ls", Status: p[2]}
			if len(p) > 3 {
				it.Tool = p[3]
			}
		case "s":
			it = model.Item{ID: p[1], Kind: model.ToolCall, Title: "grep", Status: "completed", Parent: p[2]}
		case "n":
			it = model.Item{ID: "item-n" + string(rune('a'+i)), Kind: model.Notice, Status: p[1]}
		case "S":
			it = model.Item{ID: "sum", Kind: model.UserMessage, Text: "This session is being continued from a previous conversation that ran out of context."}
		}
		out = append(out, it)
	}
	return out
}

// short writes a transcript as items reads it (user messages by text, a
// compaction's mark as C, a divider as D).
func short(items []model.Item) string {
	var out []string
	for _, it := range items {
		switch {
		case it.Kind == model.UserMessage:
			out = append(out, "u:"+strings.ReplaceAll(it.Text, " ", "_"))
		case it.Kind == model.Notice && it.Status == compactedNotice:
			out = append(out, "C")
		case it.Kind == model.Notice && it.Status == differsNotice:
			out = append(out, "D")
		case it.Kind == model.Notice:
			out = append(out, "n:"+it.Status)
		case it.Kind == model.ToolCall:
			out = append(out, "t:"+it.ID+":"+it.Status)
		default:
			out = append(out, "m:"+it.ID)
		}
	}
	return strings.Join(out, " ")
}

func TestMerge(t *testing.T) {
	for name, tc := range map[string]struct{ copied, replay, want string }{
		// The copy has what the replay doesn't (a notice, a subagent's
		// steps); the agent went on in a terminal: its turn follows.
		"no compaction": {
			"u:one m:m1:hi t:t1:completed s:x1:t1 n:cancelled u:two m:m2:ok",
			"U:r1:one m:m1:hi t:t1:completed U:r2:two m:m2:ok U:r3:three m:m3:sure",
			"u:one m:m1 t:t1:completed t:x1:completed n:cancelled u:two m:m2 u:three m:m3",
		},
		"the same": {"u:one m:m1:hi", "U:r1:one m:m1:hi", "u:one m:m1"},
		// As Claude replays after /compact: the summary, the last messages
		// before it kept as they were, then what came after; never the
		// command or its call.
		"after a compaction": {
			"u:one t:t1:completed m:m1:a u:two m:m2:b u:/compact t:c1:completed:compact u:three m:m3:c",
			"S m:m2:b U:r3:three m:m3:c",
			"u:one t:t1:completed m:m1 u:two C m:m2 u:/compact t:c1:completed u:three m:m3",
		},
		"compacted, then on in a terminal": {
			"u:one m:m1:a u:/compact t:c1:completed:compact",
			"S m:m1:a U:r5:four m:m4:d",
			"u:one C m:m1 u:/compact t:c1:completed u:four m:m4",
		},
		"compacted in a terminal, the copy older": {
			"u:one m:m1:a",
			"S U:r5:four m:m4:d",
			"u:one m:m1 C u:four m:m4",
		},
		"no copy, compacted": {"", "S U:r5:four m:m4:d", "C u:four m:m4"},
		"no copy":            {"", "U:r1:one m:m1:a", "u:one m:m1"},
		"no replay":          {"u:one m:m1:a", "", "u:one m:m1"},
		// Rewound in a terminal and gone on: the agent's from where it
		// differs, after a divider.
		"a rewind elsewhere": {
			"u:one m:m1:a u:two m:m2:b u:three m:m3:c",
			"U:r1:one m:m1:a U:r2:two m:m2:b U:rx:other m:mx:x",
			"u:one m:m1 u:two m:m2 D u:other m:mx",
		},
		"a rewind elsewhere, after a compaction": {
			"u:one m:m1:a u:two m:m2:b u:three m:m3:c",
			"S m:m1:a U:rx:other m:mx:x",
			"u:one C m:m1 D u:other m:mx",
		},
		// A rewind in Nushi cut the copy as the agent forked: they agree.
		"a rewind here": {"u:one m:m1:a u:again m:m4:d", "U:r1:one m:m1:a U:r4:again m:m4:d", "u:one m:m1 u:again m:m4"},
		// The agent ends before the copy does: the copy stands.
		"the agent behind":  {"u:one m:m1:a u:two m:m2:b", "U:r1:one m:m1:a", "u:one m:m1 u:two m:m2"},
		"nothing in common": {"u:one m:m1:a", "U:r9:nine m:m9:z", "u:one m:m1 D u:nine m:m9"},
		// A tool call the copy has running (a crash) is the agent's; one
		// it missed is put where the agent has it.
		"the copy behind a crash": {
			"u:one t:t1:in_progress m:m2:b",
			"U:r1:one t:t1:completed t:t2:failed m:m2:b",
			"u:one t:t1:completed t:t2:failed m:m2",
		},
		// A copy cleared, then written again: the agent's earlier part first.
		"the copy cleared": {"u:three m:m3:c", "U:r1:one m:m1:a U:r3:three m:m3:c", "u:one m:m1 u:three m:m3"},
		// An agent whose replay gives messages new ids (omp): their text.
		"new ids": {"u:one m:m1:hello_there", "U:r1:one m:z1:hello_there U:r2:two m:z2:bye", "u:one m:m1 u:two m:z2"},
		// The same short text many times aligns in order, nothing twice.
		"repeats": {
			"u:go m:m1:ok u:go m:m2:ok u:go m:m3:ok",
			"U:r1:go m:m1:ok U:r2:go m:m2:ok U:r3:go m:m3:ok U:r4:go m:m4:ok",
			"u:go m:m1 u:go m:m2 u:go m:m3 u:go m:m4",
		},
	} {
		t.Run(name, func(t *testing.T) {
			got := merge(items(tc.copied), items(tc.replay), claude.Compacted)
			if s := short(got); s != tc.want {
				t.Errorf("got  %s\nwant %s", s, tc.want)
			}
			seen := map[string]bool{}
			for _, it := range got {
				if it.ID != "" && seen[it.ID] {
					t.Errorf("%s twice", it.ID)
				}
				seen[it.ID] = true
			}
		})
	}
}

// The compaction's mark holds the summary.
func TestMergeKeepsTheSummary(t *testing.T) {
	got := merge(items("u:one m:m1:a"), items("S m:m1:a"), claude.Compacted)
	if got[1].Status != compactedNotice || !strings.HasPrefix(got[1].Text, "This session is being continued") {
		t.Fatalf("%+v", got)
	}
}
