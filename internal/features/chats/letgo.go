package chats

import (
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// A chat whose agent doesn't run lets go of its items when its copy holds
// them all (ADR 0047; copies on, nothing unsaved): an asleep chat at once,
// another once no client shows it. A long transcript's text and images are
// most of what the daemon holds, and an asleep chat may stay so for days.
// Its items are read back by the first lookup that needs them (lookup); the
// recent part, a page, a snapshot and an image are read from the copy
// without holding them. The items that only show (shownOnly: notices the
// copy never has) stay, each with the id of the item before it. Nothing is
// sent either way: a client sees the same items and the same event numbers
// as before.
//
// A chat looked up after a daemon start starts so: its copy is its
// transcript, as read back (ended), until something needs it whole.

// asideItem is an item that only shows, kept while the chat's other items
// are let go, with the id of the item before it ("" for the first).
type asideItem struct {
	item  model.Item
	after string
}

// letGoCheck is how often the chats no client shows are looked at.
var letGoCheck = time.Minute

// letGoUnseen lets go of the items of the chats no client shows, now and
// then, until the service's life ends.
func (s *Service) letGoUnseen() {
	tick := time.NewTicker(letGoCheck)
	defer tick.Stop()
	for {
		select {
		case <-tick.C:
		case <-s.ctx.Done():
			return
		}
		for _, c := range s.openChats() {
			c.mu.Lock()
			c.letGoLocked()
			c.mu.Unlock()
		}
	}
}

// letGoLocked lets go of the chat's items if its copy holds them all and
// nothing needs them (canLetGoLocked), when it's asleep or no client shows
// it.
func (c *chat) letGoLocked() {
	if c.inCopy || !c.canLetGoLocked() || !c.asleep && c.viewers != nil && c.viewers.Shown(c.id) {
		return
	}
	var aside []asideItem
	prev := ""
	for _, it := range c.items {
		if shownOnly(it) {
			aside = append(aside, asideItem{it, prev})
		}
		prev = it.ID
	}
	n := len(c.items)
	c.items, c.aside, c.inCopy = nil, aside, true
	c.logLocked().Info("transcript let go", "items", n, "asleep", c.asleep)
}

// canLetGoLocked says the copy holds every item that doesn't only show,
// as reading it back would give it (nothing under way, which reading back
// ends), and nothing of the chat's needs them now: no agent, no work, no
// side chat, no pin being titled.
func (c *chat) canLetGoLocked() bool {
	return c.copies != nil && c.copiesOn() && c.mirrored && len(c.unsaved) == 0 && len(c.items) > 0 &&
		c.parent == nil && c.agent == nil && !c.busy && !c.opening && !c.replaying && !c.halting && !c.removing && !c.stopping &&
		len(c.sides) == 0 && len(c.children) == 0 && len(c.titling) == 0 && c.quietLocked() &&
		!slices.ContainsFunc(c.items, underWay)
}

// itemsBackLocked reads the chat's items back from its copy if they were
// let go, what was under way when it was written ended, with the items set
// aside in their places. A copy that can't be read leaves the chat with
// those alone, as a lookup's did before.
func (c *chat) itemsBackLocked() {
	if !c.inCopy {
		return
	}
	items, err := c.copies.Read(c.id)
	if err != nil {
		c.logLocked().Warn("transcript copy not read", "err", err)
	}
	changed := false
	for i := range items {
		changed = changed || underWay(items[i])
		ended(&items[i])
	}
	c.items = splice(items, c.aside)
	for _, it := range c.items {
		c.noteID(it.ID)
	}
	c.inCopy, c.aside = false, nil
	c.mirrored = err == nil && !changed // an item ended here differs from the copy's
}

// splice puts the items set aside back among items, each after the item it
// followed; one whose item is gone goes at the end.
func splice(items []model.Item, aside []asideItem) []model.Item {
	if len(aside) == 0 {
		return items
	}
	out := make([]model.Item, 0, len(items)+len(aside))
	placed := make([]bool, len(aside))
	var follow func(id string)
	follow = func(id string) {
		for i, a := range aside {
			if !placed[i] && a.after == id {
				placed[i] = true
				out = append(out, a.item)
				follow(a.item.ID)
			}
		}
	}
	follow("")
	for _, it := range items {
		out = append(out, it)
		follow(it.ID)
	}
	for i, a := range aside {
		if !placed[i] {
			out = append(out, a.item)
		}
	}
	return out
}

// headsLocked is the transcript of a chat whose items were let go as the
// copy's heads (Copies.Heads, ended as reading back ends them), with the
// items set aside, whole, in their places.
func (c *chat) headsLocked() ([]model.Item, error) {
	heads, err := c.copies.Heads(c.id)
	if err != nil {
		return nil, err
	}
	for i := range heads {
		ended(&heads[i])
	}
	return splice(heads, c.aside), nil
}

// wholeLocked is heads (headsLocked's) whole: the copy's items read back
// (only those), ended, and the items set aside as they are.
func (c *chat) wholeLocked(heads []model.Item) ([]model.Item, error) {
	want := make(map[string]bool, len(heads))
	var ids []string
	for _, h := range heads {
		if want[h.ID] = !shownOnly(h); want[h.ID] {
			ids = append(ids, h.ID)
		}
	}
	found, err := c.copies.Pick(c.id, ids)
	if err != nil {
		return nil, err
	}
	byID := make(map[string]model.Item, len(found))
	for _, it := range found {
		ended(&it)
		byID[it.ID] = it
	}
	out := make([]model.Item, 0, len(heads))
	for _, h := range heads {
		if !want[h.ID] {
			out = append(out, h) // set aside, whole
		} else if it, ok := byID[h.ID]; ok {
			out = append(out, it)
		}
	}
	return out, nil
}

// copyItemsLocked is every item of a chat whose items were let go, read
// from its copy as itemsBackLocked would, without holding them.
func (c *chat) copyItemsLocked() ([]model.Item, error) {
	items, err := c.copies.Read(c.id)
	if err != nil {
		return nil, err
	}
	for i := range items {
		ended(&items[i])
	}
	return splice(items, c.aside), nil
}

// failureLocked is the notice saying why the chat's last reopen failed, if
// it shows one, without reading let-go items back (it's set aside).
func (c *chat) failureLocked() *model.Item {
	if !c.inCopy {
		return c.itemLocked(c.failure)
	}
	for i := range c.aside {
		if c.failure != "" && c.aside[i].item.ID == c.failure {
			return &c.aside[i].item
		}
	}
	return nil
}
