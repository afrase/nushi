package chats

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"slices"
	"strings"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/model"
)

// A pinned message is kept in its chat's record by its item's id (ADR
// 0085). The id holds while Nushi's copy does (ADR 0047: a reopen keeps the
// copy's items where they agree with the replay), but a reopen without a
// copy names the user's messages anew, and the agent's too when it gives
// them no ids, so a pin also keeps the message's opening: a reopen finds
// one of Nushi's ids by that when it no longer points at it (repinLocked).

// ErrNotMessage is PinMessage's refusal of an item that isn't one of the
// agent's own messages: not the user's, a subagent's, a tool call or a card.
var ErrNotMessage = errors.New("no such message of the agent's")

// pinRunes is how much of a message's opening a pin keeps the hash of: a
// message is told from another by its first lines.
const pinRunes = 200

// pinnable says an item is a message a pin can mark: the agent's own, at
// the top level (ADR 0085). The user's aren't: what the agent made of them
// is what's gone back to.
func pinnable(it model.Item) bool {
	return it.Parent == "" && it.Kind == model.AgentMessage
}

// opening is the hash of text's first n runes, trimmed, and how many runes
// that is (fewer than n when text is shorter).
func opening(text string, n int) (string, int) {
	text = strings.TrimSpace(text)
	end, runes := 0, 0
	for end < len(text) && runes < n {
		_, size := utf8.DecodeRuneInString(text[end:])
		end += size
		runes++
	}
	sum := sha256.Sum256([]byte(text[:end]))
	return hex.EncodeToString(sum[:16]), runes
}

// opensAs says it is a message of p's kind with p's opening.
func opensAs(p model.MessagePin, it model.Item) bool {
	if !pinnable(it) || it.Kind != p.Kind {
		return false
	}
	start, runes := opening(it.Text, p.Runes)
	return runes == p.Runes && start == p.Start
}

// pinOf is the pin of items[i], a message.
func pinOf(items []model.Item, i int) model.MessagePin {
	it := items[i]
	p := model.MessagePin{Item: it.ID, Kind: it.Kind}
	p.Start, p.Runes = opening(it.Text, pinRunes)
	for _, before := range items[:i] {
		if opensAs(p, before) {
			p.Nth++
		}
	}
	return p
}

// findPin is p's message in items, its pin as it is there: the item of
// p's id if it still opens as p's did, else, for an id Nushi gave (item-N,
// which a reopen gives anew), the Nth (from 0) message that does. The
// agent's own ids are the same live and replayed (merge): a message of
// one that's gone is gone, though another may open alike ("Done.").
func findPin(items []model.Item, p model.MessagePin) (model.MessagePin, bool) {
	if i := slices.IndexFunc(items, func(it model.Item) bool { return it.ID == p.Item }); i >= 0 && opensAs(p, items[i]) {
		return titledAs(pinOf(items, i), p, items[i]), true
	}
	if !strings.HasPrefix(p.Item, "item-") {
		return p, false
	}
	n := 0
	for i, it := range items {
		if !opensAs(p, it) {
			continue
		}
		if n == p.Nth {
			return titledAs(pinOf(items, i), p, items[i]), true
		}
		n++
	}
	return p, false
}

// titledAs is p found again, with the title it had (one from its message,
// for a pin kept before titles were).
func titledAs(found, p model.MessagePin, it model.Item) model.MessagePin {
	found.Title = p.Title
	if found.Title == "" {
		found.Title = pinTitle(it.Text)
	}
	return found
}

// PinMessage pins one of the agent's messages in a chat (its item's id),
// or unpins it. Pinning a message already pinned, or unpinning one that
// isn't, changes nothing. A new pin is titled from the message at once,
// and by the agent after if it can (titleLocked). Saving tells the clients
// (Chat.pinned_messages, Chat.message_pins).
func (s *Service) PinMessage(chatID, itemID string, pinned bool) error {
	c, err := s.stored(chatID)
	if err != nil {
		return fmt.Errorf("pinning a message: %w", err)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	pins := slices.DeleteFunc(slices.Clone(c.record.Pins), func(p model.MessagePin) bool { return p.Item == itemID })
	if pinned {
		i := c.indexLocked(itemID)
		if i < 0 || !pinnable(c.items[i]) {
			return ErrNotMessage
		}
		if len(pins) < len(c.record.Pins) {
			return nil // pinned already, its place kept
		}
		p := pinOf(c.items, i)
		p.Title = pinTitle(c.items[i].Text)
		pins = append(pins, p)
	}
	c.saveLocked(func(s *model.ChatRecord) { s.Pins = orNil(pins) })
	if pinned {
		c.titleLocked(itemID, c.items[c.indexLocked(itemID)].Text)
	}
	return nil
}

// repinLocked finds the chat's pins in items, the transcript a reopen
// made of the copy and the replay, before they're shown: a pin follows its
// message to another id; one whose message isn't there goes (the agent's
// history no longer has it, or a compaction took it and there's no copy).
// An empty transcript, of a replay that brought nothing, changes nothing.
func (c *chat) repinLocked(items []model.Item) {
	if len(items) == 0 || len(c.record.Pins) == 0 {
		return
	}
	var pins []model.MessagePin
	for _, p := range c.record.Pins {
		found, ok := findPin(items, p)
		if ok && !slices.ContainsFunc(pins, func(q model.MessagePin) bool { return q.Item == found.Item }) {
			pins = append(pins, found)
		}
	}
	c.saveLocked(func(s *model.ChatRecord) { s.Pins = pins })
}

// unpinGoneLocked drops the pins of messages the transcript no longer has
// (a rewind cut them, or one never sent was taken back).
func (c *chat) unpinGoneLocked() {
	c.saveLocked(func(s *model.ChatRecord) { s.Pins = pinsIn(s.Pins, c.items) })
}

// pinsIn is pins, those of items alone; nil for none, as a record without
// pins has them.
func pinsIn(pins []model.MessagePin, items []model.Item) []model.MessagePin {
	return orNil(slices.DeleteFunc(slices.Clone(pins), func(p model.MessagePin) bool {
		return !slices.ContainsFunc(items, func(it model.Item) bool { return it.ID == p.Item })
	}))
}

// orNil is pins, nil when there are none: a record compares equal to one
// that never had any (saveLocked saves only a change).
func orNil(pins []model.MessagePin) []model.MessagePin {
	if len(pins) == 0 {
		return nil
	}
	return slices.Clip(pins)
}
