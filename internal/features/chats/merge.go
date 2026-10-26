package chats

import (
	"slices"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// merge makes a reopened chat's transcript from Nushi's copy of it and the
// agent's replay (session/load), showing what both have once.
//
// The two are lined up item by item, by the agent's ids where it gave
// them (its messages' and tool calls' ids are the same live and replayed),
// else by text (a user message: Nushi names it, the replay names it again),
// as the longest run in order both have. Where they agree the copy's items
// stand, with what only the copy has between them (prompts, questions,
// notices, subagents' steps, which no replay brings back), and what only
// the agent has by its id (a tool call the copy missed); a tool call the
// copy has still running is the agent's.
//
// Before the first item both have: the copy's earlier part, then a mark,
// then the agent's own earlier items. The mark is "compacted" when the
// replay starts with a compaction's summary (Claude replays only what
// follows its last compaction: before it, the copy alone), else a divider
// if the copy has a conversation there that the agent doesn't. After the
// last: what only one has; when both go on, differently (a rewind or an
// edit in a terminal), the agent's replay wins from there, after a divider.
//
// compaction says an item is part of a compaction (Dialect.Compacted).
// The marks come without ids; the chat gives them theirs.
func merge(copied, replay []model.Item, compaction func(model.Item) bool) []model.Item {
	var summary *model.Item
	if len(replay) > 0 && replay[0].Kind == model.UserMessage && compaction != nil && compaction(replay[0]) {
		summary, replay = &replay[0], replay[1:]
	}
	mark := func(differs bool) model.Item {
		if !differs && summary != nil {
			return model.Item{Kind: model.Notice, Status: compactedNotice, Text: summary.Text}
		}
		return model.Item{Kind: model.Notice, Status: differsNotice}
	}
	substantive := func(items []model.Item) int {
		return slices.IndexFunc(items, func(it model.Item) bool { return conversation(it, compaction) })
	}
	pairs := align(copied, replay)
	var out []model.Item
	switch {
	case len(pairs) > 0:
	case len(replay) == 0 && summary == nil:
		return slices.Clone(copied)
	case len(copied) == 0 && summary == nil:
		return slices.Clone(replay)
	default: // nothing in common: the copy, then the agent's
		out = append(slices.Clone(copied), mark(summary == nil))
		return append(out, replay...)
	}
	first := pairs[0]
	out = append(out, copied[:first.c]...)
	if summary != nil || substantive(copied[:first.c]) >= 0 {
		out = append(out, mark(false))
	}
	out = append(out, replay[:first.r]...)
	for k, p := range pairs {
		out = append(out, pick(copied[p.c], replay[p.r]))
		if k+1 < len(pairs) {
			next := pairs[k+1]
			out = append(out, copied[p.c+1:next.c]...)
			for _, it := range replay[p.r+1 : next.r] {
				if stableID(it) { // an item the copy missed; one without an id may be the copy's, told otherwise
					out = append(out, it)
				}
			}
		}
	}
	last := pairs[len(pairs)-1]
	ctail, rtail := copied[last.c+1:], replay[last.r+1:]
	if i := substantive(ctail); i >= 0 && len(rtail) > 0 {
		out = append(out, ctail[:i]...)
		out = append(out, mark(true))
	} else {
		out = append(out, ctail...)
	}
	out = append(out, rtail...)
	seen := map[string]bool{}
	return slices.DeleteFunc(out, func(it model.Item) bool { // an item twice: the first stands
		dup := it.ID != "" && seen[it.ID]
		seen[it.ID] = true
		return dup
	})
}

// conversation says an item is part of the conversation the agent keeps
// and replays: a message or tool call of its own, a user message that
// isn't a command (the agent may answer one itself and keep nothing), not
// a compaction.
func conversation(it model.Item, compaction func(model.Item) bool) bool {
	if it.Parent != "" || compaction != nil && compaction(it) {
		return false
	}
	switch it.Kind {
	case model.UserMessage:
		return !strings.HasPrefix(strings.TrimSpace(it.Text), "/")
	case model.AgentMessage, model.ToolCall:
		return true
	default:
		return false
	}
}

// pick is the item to show of one both have: the copy's (it has what the
// replay doesn't: a subagent's steps and report, findings), unless the copy
// has it still running and the agent has it ended.
func pick(copied, replayed model.Item) model.Item {
	ended := func(s string) bool { return s == "completed" || s == "failed" }
	if copied.Kind == model.ToolCall && !ended(copied.Status) && ended(replayed.Status) {
		return replayed
	}
	return copied
}

// stableID says an item has the agent's id for it, not one Nushi gave it.
func stableID(it model.Item) bool { return it.ID != "" && !strings.HasPrefix(it.ID, "item-") }

// idKey is what an item is matched by first: the agent's id for it.
func idKey(it model.Item) []string {
	if stableID(it) {
		return []string{strconv.Itoa(int(it.Kind)) + "\x00" + it.ID}
	}
	return nil
}

// textKey is what an item is matched by where ids don't tell: its text (a
// tool call's title and output).
func textKey(it model.Item) []string {
	text := strings.TrimSpace(it.Text)
	switch {
	case it.Kind == model.ToolCall && text != "":
		return []string{"tool\x00" + it.Parent + "\x00" + it.Title + "\x00" + text}
	case it.Kind == model.UserMessage, it.Kind == model.AgentMessage, it.Kind == model.Thought:
		if text != "" || len(it.Images) > 0 {
			return []string{strconv.Itoa(int(it.Kind)) + "\x00" + it.Parent + "\x00" + text}
		}
	}
	return nil
}

// pair is an item both have: its index in the copy and in the replay.
type pair struct{ c, r int }

// maxCandidates bounds the items of the copy one replayed item is tried
// against (a short text the copy has many times).
const maxCandidates = 64

// align returns the items both have, in order: the longest run of those
// the agent's ids match, and between them (or, when none do, throughout)
// the longest run of those their texts match.
func align(copied, replay []model.Item) []pair {
	anchors := lcs(copied, replay, idKey)
	if len(anchors) == 0 {
		return lcs(copied, replay, textKey)
	}
	var out []pair
	c, r := 0, 0
	for _, a := range append(anchors, pair{len(copied), len(replay)}) {
		for _, p := range lcs(copied[c:a.c], replay[r:a.r], textKey) {
			out = append(out, pair{c + p.c, r + p.r})
		}
		if a.c < len(copied) {
			out = append(out, a)
		}
		c, r = a.c+1, a.r+1
	}
	return out
}

// lcs returns the longest run of items both have by keys, in order (a
// longest common subsequence, found as the longest increasing run of the
// copy's indexes over the matches, Hunt and Szymanski's way).
func lcs(copied, replay []model.Item, keys func(model.Item) []string) []pair {
	at := map[string][]int{}
	for j, it := range copied {
		for _, k := range keys(it) {
			at[k] = append(at[k], j)
		}
	}
	type link struct {
		pair
		prev int // the link before it in the run, -1 for none
	}
	var links []link
	var tails []int // tails[n]: the link ending the best run of n+1 found so far
	for i, it := range replay {
		var cands []int
		for _, k := range keys(it) {
			js := at[k]
			cands = append(cands, js[max(0, len(js)-maxCandidates):]...)
		}
		slices.Sort(cands)
		cands = slices.Compact(cands)
		// Descending, so one replayed item extends a run once.
		for _, j := range slices.Backward(cands) {
			n, _ := slices.BinarySearchFunc(tails, j, func(l, j int) int { return links[l].c - j })
			prev := -1
			if n > 0 {
				prev = tails[n-1]
			}
			links = append(links, link{pair{j, i}, prev})
			if n == len(tails) {
				tails = append(tails, len(links)-1)
			} else {
				tails[n] = len(links) - 1
			}
		}
	}
	if len(tails) == 0 {
		return nil
	}
	out := make([]pair, len(tails))
	for l, n := tails[len(tails)-1], len(tails)-1; l >= 0; l, n = links[l].prev, n-1 {
		out[n] = links[l].pair
	}
	return out
}
