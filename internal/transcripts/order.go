package transcripts

import "slices"

// entry is an item of a transcript being replayed: its id, and the item
// as last written, or nil where the reader kept only the id (Find) or
// its head (index, with at and n where its last record is in the file).
type entry struct {
	id    string
	item  *stored
	head  *itemHead
	at, n int64
}

// change is a record as a transcript replays it: an item (nil for a cut
// or a drop) and the record's After, Cut and Drop.
type change struct {
	item             *entry
	after, cut, drop string
}

// transcript replays a chat's records into its items, in the transcript's
// order: a new item goes right after the item it was written after, and
// one written before that item waits for it (at the end, if it never
// comes); a record of an item already there replaces it in place, and one
// of an item still waiting replaces it there (or places it, its new After
// there). So no id is there twice: in list or in waiting, once.
type transcript struct {
	list    []entry
	waiting []change       // items whose After isn't there yet, in the order written
	pos     map[string]int // list's indexes by id; nil after list changed other than at its end
}

func (t *transcript) index(id string) int {
	if t.pos == nil {
		t.pos = make(map[string]int, len(t.list))
		for i, e := range t.list {
			t.pos[e.id] = i
		}
	}
	if i, ok := t.pos[id]; ok {
		return i
	}
	return -1
}

func (t *transcript) apply(c change) {
	switch {
	case c.item != nil:
		if i := t.index(c.item.id); i >= 0 {
			t.list[i] = *c.item
			return
		}
		j := slices.IndexFunc(t.waiting, func(w change) bool { return w.item.id == c.item.id })
		switch placed := t.place(c); {
		case !placed && j >= 0:
			t.waiting[j] = c
		case !placed:
			t.waiting = append(t.waiting, c)
		default:
			if j >= 0 {
				t.waiting = slices.Delete(t.waiting, j, j+1)
			}
			t.placeWaiting()
		}
	case c.cut != "":
		// What comes from the cut item on, as entries gives it: the list's
		// rest and all that waits, or, for an item still waiting, it and
		// what waits after it.
		if i := t.index(c.cut); i >= 0 {
			t.list, t.waiting, t.pos = t.list[:i], nil, nil
		} else if j := slices.IndexFunc(t.waiting, func(w change) bool { return w.item.id == c.cut }); j >= 0 {
			t.waiting = t.waiting[:j]
		}
	case c.drop != "":
		if i := t.index(c.drop); i >= 0 {
			t.list, t.pos = slices.Delete(t.list, i, i+1), nil
		}
		t.waiting = slices.DeleteFunc(t.waiting, func(w change) bool { return w.item.id == c.drop })
	}
}

// place puts a new item right after its After ("": first), if that is there.
func (t *transcript) place(c change) bool {
	at := 0
	if c.after != "" {
		i := t.index(c.after)
		if i < 0 {
			return false
		}
		at = i + 1
	}
	if at == len(t.list) {
		if t.pos != nil {
			t.pos[c.item.id] = at
		}
		t.list = append(t.list, *c.item)
	} else {
		t.list, t.pos = slices.Insert(t.list, at, *c.item), nil
	}
	return true
}

// placeWaiting places the items waiting for one that has come, until none
// can be.
func (t *transcript) placeWaiting() {
	for placed := true; placed; {
		placed = false
		for i, w := range t.waiting {
			if t.place(w) {
				t.waiting = slices.Delete(t.waiting, i, i+1)
				placed = true
				break
			}
		}
	}
}

// entries is the transcript, with what still waits at its end.
func (t *transcript) entries() []entry {
	out := t.list
	for _, w := range t.waiting {
		out = append(out, *w.item)
	}
	return out
}
