package chats

import (
	"context"
	"regexp"
	"slices"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/model"
)

// A pinned message's title (ADR 0085): a few words a client lists the pin
// by. Every pin gets one at once from its message's text (pinTitle); an
// agent that can make one (TitleMaker, Claude) makes a better one after,
// which replaces it (titleLocked).

// titleRunes is about how long a title is: it's cut at a word near this.
const titleRunes = 40

// titleTextRunes is how much of a message the agent makes its title from.
const titleTextRunes = 2000

// A message's title is found in its opening, titleBytes of it at most, and
// in at most titleLineRunes of its first line: pinTitle runs under the
// chat's lock, and a message can be megabytes.
const (
	titleBytes     = 16 << 10
	titleLineRunes = 500
)

var (
	heading    = regexp.MustCompile(`^#{1,6}\s+(.+?)\s*#*$`)
	lineMarks  = regexp.MustCompile(`^(\s*(>\s*|[-*+]\s+|\d+[.)]\s+))+`)
	link       = regexp.MustCompile(`!?\[([^\]]*)\]\([^)]*\)`)
	strongMark = strings.NewReplacer("**", "", "__", "", "`", "", "~~", "")
	emphasis   = regexp.MustCompile(`(^|[\s(])[*_]+|[*_]+($|[\s.,;:!?)])`)
	sentence   = regexp.MustCompile(`^.*?[.!?](\s|$)`)
)

// pinTitle is a message's title from its text: its first Markdown heading,
// else its first sentence, without the Markdown, cut at a word near
// titleRunes; "Message" when it has no words outside code. The message is
// the agent's text, so the title is one line of printable text, as an
// agent's own title is (agentTitle).
func pinTitle(text string) string {
	if len(text) > titleBytes {
		text = strings.ToValidUTF8(text[:titleBytes], "")
	}
	var first string
	fenced := false
	for line := range strings.Lines(text) {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "```") || strings.HasPrefix(line, "~~~") {
			fenced = !fenced
			continue
		}
		if fenced || line == "" {
			continue
		}
		if m := heading.FindStringSubmatch(line); m != nil {
			if t := printable(plainTitle(m[1])); t != "" {
				return cutTitle(t)
			}
			continue
		}
		if first == "" {
			first = line
			if utf8.RuneCountInString(first) > titleLineRunes {
				first = string([]rune(first)[:titleLineRunes])
			}
		}
	}
	plain := printable(plainTitle(lineMarks.ReplaceAllString(first, "")))
	if s := sentence.FindString(plain); s != "" {
		plain = strings.TrimSpace(s)
	}
	if plain == "" {
		return "Message"
	}
	return cutTitle(plain)
}

// plainTitle is s without inline Markdown: a link as its text, no emphasis
// or code marks.
func plainTitle(s string) string {
	s = link.ReplaceAllString(s, "$1")
	s = emphasis.ReplaceAllString(strongMark.Replace(s), "$1$2")
	return strings.TrimSpace(s)
}

// cutTitle is s cut at the last word that ends by titleRunes (or at
// titleRunes, for one word that long), with an ellipsis when cut, and
// without a sentence's end.
func cutTitle(s string) string {
	s = strings.Join(strings.Fields(s), " ")
	if utf8.RuneCountInString(s) <= titleRunes {
		return strings.TrimRight(s, ".:!")
	}
	r := []rune(s)[:titleRunes+1]
	cut := strings.LastIndexFunc(string(r), unicode.IsSpace)
	if cut <= 0 {
		cut = len(string(r[:titleRunes]))
	}
	return strings.TrimRightFunc(s[:cut], func(r rune) bool { return unicode.IsSpace(r) || unicode.IsPunct(r) }) + "…"
}

// printable is s as one line of printable text, trimmed: its spaces and
// line breaks spaces, its control, format (a bidi override, a zero-width
// space) and other unprintable characters gone.
func printable(s string) string {
	return strings.TrimSpace(strings.Map(func(r rune) rune {
		if unicode.IsSpace(r) {
			return ' '
		}
		if !unicode.IsPrint(r) {
			return -1
		}
		return r
	}, s))
}

// agentTitle is a title an agent made, as a pin keeps it: one line of
// printable text, cut as pinTitle's are; "" when nothing's left. It's the
// model's text, so it is bounded and shown as plain text only.
func agentTitle(s string) string {
	s = strings.Trim(printable(s), `"'“”`)
	if s == "" {
		return ""
	}
	return cutTitle(s)
}

// titleText is the opening of a message an agent makes a title from.
func titleText(text string) string {
	text = strings.TrimSpace(text)
	if utf8.RuneCountInString(text) <= titleTextRunes {
		return text
	}
	return strings.ToValidUTF8(string([]rune(text)[:titleTextRunes]), "")
}

// titleTimeout bounds the agent's making of a pin's title.
const titleTimeout = time.Minute

// titlesAtOnce is how many pins' titles a chat's agent makes at once: each
// is a call to its model on the user's account, and pinning many messages
// quickly shouldn't send them all together.
const titlesAtOnce = 2

// titleLocked has the agent make a title for the pin of item, whose message
// is text, on a goroutine of its own, if it can (TitleMaker) and runs now:
// pinning doesn't start an agent. A title that comes replaces the one from
// the message, if the message is still pinned; a failure or none keeps it.
// One already being made isn't asked for again (a pin taken off and put
// back meanwhile gets that one), and a chat's agent makes titlesAtOnce at
// most, the others waiting their turn.
//
//nolint:contextcheck // the title comes on the chat's own life, after PinMessage has answered
func (c *chat) titleLocked(item, text string) {
	maker, agent, sid := c.kind.titleMaker, c.agent, c.sid
	if maker == nil || agent == nil || sid == "" || c.titling[item] {
		return
	}
	if c.titling == nil {
		c.titling = map[string]bool{}
		c.titleSlots = make(chan struct{}, titlesAtOnce)
	}
	c.titling[item] = true
	slots := c.titleSlots
	go func() {
		// Each way out drops item from titling under the same lock as its
		// last look at the pins, so a pin put back meanwhile is either seen
		// here or asks anew.
		select {
		case slots <- struct{}{}:
			defer func() { <-slots }()
		case <-c.ctx.Done():
			c.mu.Lock()
			delete(c.titling, item)
			c.mu.Unlock()
			return
		}
		if !c.stillPinned(item) {
			return // unpinned while it waited
		}
		ctx, cancel := context.WithTimeout(c.ctx, titleTimeout)
		defer cancel()
		made, err := maker.MessageTitle(ctx, agent.Call, sid, titleText(text))
		title := agentTitle(made)
		if err != nil || title == "" {
			c.log().Info("no title from the agent for a pin", "err", err)
			title = ""
		}
		c.mu.Lock()
		defer c.mu.Unlock()
		delete(c.titling, item)
		i := slices.IndexFunc(c.record.Pins, func(p model.MessagePin) bool { return p.Item == item })
		if title == "" || i < 0 || c.halting {
			return // none, unpinned meanwhile, or the chat is being deleted: its record isn't saved again
		}
		pins := slices.Clone(c.record.Pins)
		pins[i].Title = title
		c.saveLocked(func(s *model.ChatRecord) { s.Pins = pins })
	}()
}

// stillPinned says the message of item is pinned; when it isn't, item is
// no longer being titled.
func (c *chat) stillPinned(item string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	pinned := slices.ContainsFunc(c.record.Pins, func(p model.MessagePin) bool { return p.Item == item })
	if !pinned {
		delete(c.titling, item)
	}
	return pinned
}
