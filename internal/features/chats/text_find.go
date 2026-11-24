package chats

import (
	"context"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/textfind"
)

// ⌘F in a long chat searches its whole transcript (ADR 0144): the app
// counts the matches in what it hasn't loaded from FindText's answer, and
// loads the part a step goes to. The transcript is the daemon's own, as
// its pages give it (the agent's replay, or the copy of a chat that let
// go of its items); nothing of the agent's is read or written here.

// TextMatch is one of a chat's items with matches, and how many.
type TextMatch struct {
	ID    string
	Count int
}

// maxTextMatches bounds a search's answer: past so many items with
// matches, the older ones aren't counted.
const maxTextMatches = 5000

// copyChunk is how many items of a let-go chat's copy are read whole at a
// time: a search holds that many, not the transcript.
const copyChunk = 256

// FindText counts query's matches (textfind.Literal: case aside, as
// written) in what each of a chat's items shows (findText), for those
// before the item of id before ("" for all of them), in the transcript's
// order, and says whether it stopped at maxTextMatches: it searches back
// from before, so what it answers are the matches nearest it, the ones a
// step up from what's loaded goes to. The chat's lock is
// held only to take its items' texts (strings, shared, not copied), or the
// heads of a chat whose items were let go, whose copy is then read a chunk
// at a time; ctx's end stops it.
func (s *Service) FindText(ctx context.Context, chatID, query, before string) ([]TextMatch, bool, error) {
	q := textfind.Literal(query)
	if q.Empty() {
		return nil, false, nil
	}
	c, err := s.find(chatID)
	if err != nil {
		return nil, false, err
	}
	c.mu.Lock()
	var texts []itemText
	var heads []model.Item
	if c.inCopy {
		heads, err = c.headsLocked()
	} else {
		texts = make([]itemText, len(c.items))
		for i := range c.items {
			texts[i] = itemText{c.items[i].ID, findText(c.items[i])}
		}
	}
	c.mu.Unlock()
	if err != nil {
		return nil, false, err
	}
	if heads != nil {
		return findInCopy(ctx, q, c, heads, before)
	}
	end, err := endBefore(len(texts), before, func(i int) string { return texts[i].id })
	if err != nil {
		return nil, false, err
	}
	var out backwards
	for i := end - 1; i >= 0; i-- {
		if i%64 == 0 && ctx.Err() != nil {
			return nil, false, ctx.Err()
		}
		if out.add(texts[i].id, texts[i].count(q)) {
			return out.done(true)
		}
	}
	return out.done(false)
}

// backwards gathers a search's matches from the last item back.
type backwards []TextMatch

// add counts item id's n matches, if any; true when it has maxTextMatches
// items already, so the search stops.
func (b *backwards) add(id string, n int) bool {
	if n == 0 {
		return false
	}
	if len(*b) == maxTextMatches {
		return true
	}
	*b = append(*b, TextMatch{id, n})
	return false
}

// done is the matches in the transcript's order, and more.
func (b *backwards) done(more bool) ([]TextMatch, bool, error) {
	slices.Reverse(*b)
	return *b, more, nil
}

// findInCopy is FindText for a chat whose items were let go: its copy's
// items read whole copyChunk at a time (only those), the items set aside
// as heads has them.
func findInCopy(ctx context.Context, q textfind.Query, c *chat, heads []model.Item, before string) ([]TextMatch, bool, error) {
	end, err := endBefore(len(heads), before, func(i int) string { return heads[i].ID })
	if err != nil {
		return nil, false, err
	}
	var out backwards
	for to := end; to > 0; to -= copyChunk {
		if ctx.Err() != nil {
			return nil, false, ctx.Err()
		}
		part := heads[max(0, to-copyChunk):to]
		var ids []string
		for _, h := range part {
			if !shownOnly(h) {
				ids = append(ids, h.ID)
			}
		}
		read, err := c.copies.Pick(c.id, ids)
		if err != nil {
			return nil, false, err
		}
		whole := make(map[string]*model.Item, len(read))
		for i := range read {
			whole[read[i].ID] = &read[i]
		}
		for i := len(part) - 1; i >= 0; i-- {
			it := &part[i]
			if w, ok := whole[it.ID]; ok {
				it = w
			} else if !shownOnly(*it) {
				continue // gone from the copy since its heads
			}
			if out.add(it.ID, (itemText{it.ID, findText(*it)}).count(q)) {
				return out.done(true)
			}
		}
	}
	return out.done(false)
}

// endBefore is the place of the item of id before among n (all of them
// for ""), whose ids id gives; ErrNoItem when there's none.
func endBefore(n int, before string, id func(int) string) (int, error) {
	if before == "" {
		return n, nil
	}
	for i := range n {
		if id(i) == before {
			return i, nil
		}
	}
	return 0, ErrNoItem
}

// itemText is an item's id and the texts a find looks in.
type itemText struct {
	id    string
	texts []string
}

func (t itemText) count(q textfind.Query) int {
	n := 0
	for _, s := range t.texts {
		n += q.Count(s)
	}
	return n
}

// findText is what the app's find looks in of an item, as the transcript
// shows it: a message's, thought's, notice's or question's text, a tool
// call's or permission's title, and a call's output, and its input and raw
// output where the app shows them (showsInput, showsRawOutput). Not a
// call's diffs, a plan, a question's form, a message's files or images,
// which the find doesn't look in. A title is the agent's, not the row's as
// the app writes it, as ADR 0144 accepts.
func findText(it model.Item) []string {
	switch it.Kind {
	case model.ToolCall, model.Permission:
		out := []string{it.Title, it.Text}
		if it.Kind == model.ToolCall && showsInput(it) {
			out = append(out, it.Input)
		}
		if it.Kind == model.ToolCall && showsRawOutput(it) {
			out = append(out, it.RawOutput)
		}
		return slices.DeleteFunc(out, func(s string) bool { return s == "" })
	case model.Plan:
		return nil
	default:
		return []string{it.Text}
	}
}

// The app's rules for what of a call's body shows (app/lib/tool_parts.dart's
// isCommand, showsInput and showsRawOutput), copied so find counts what
// shows: a change to one side goes to the other.

// isCommand says a call is a command the app shows as one (its title the
// command line): not Nushi's show or dev server tools, whose titles say
// their input.
func isCommand(it model.Item) bool {
	return it.ToolKind == "execute" && it.Title != "" && !isShow(it) && !isServerTool(it)
}

// showsInput says a call's input shows: it has one and no diff or command
// says what it did, and either nothing else shows or it's a tool ACP has
// no kind for (an MCP tool's), whose content is only its result.
func showsInput(it model.Item) bool {
	return it.Input != "" && !isShow(it) && !isServerTool(it) && len(it.Diffs) == 0 && !isCommand(it) &&
		(strings.TrimSpace(it.Text) == "" || it.ToolKind == "other" || it.ToolKind == "")
}

// showsRawOutput says a call's raw output shows: the agent's content
// showed nothing.
func showsRawOutput(it model.Item) bool {
	return it.RawOutput != "" && strings.TrimSpace(it.Text) == "" && len(it.Diffs) == 0 && !isCommand(it)
}
