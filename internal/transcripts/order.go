package transcripts

import "slices"

// transcript replays a chat's records into its items, in the transcript's
// order: a new item goes right after the item it was written after, and
// one written before that item waits for it (at the end, if it never
// comes); a record of an item already there replaces it in place.
type transcript struct {
	list    []stored
	waiting []record       // items whose After isn't there yet, in the order written
	pos     map[string]int // list's indexes by id; nil after list changed other than at its end
}

func (t *transcript) index(id string) int {
	if t.pos == nil {
		t.pos = make(map[string]int, len(t.list))
		for i, s := range t.list {
			t.pos[s.ID] = i
		}
	}
	if i, ok := t.pos[id]; ok {
		return i
	}
	return -1
}

func (t *transcript) apply(r record) {
	switch {
	case r.Item != nil:
		if i := t.index(r.Item.ID); i >= 0 {
			t.list[i] = *r.Item
			return
		}
		if !t.place(r) {
			t.waiting = append(t.waiting, r)
			return
		}
		t.placeWaiting()
	case r.Cut != "":
		if i := t.index(r.Cut); i >= 0 {
			t.list, t.waiting, t.pos = t.list[:i], nil, nil
		}
	case r.Drop != "":
		if i := t.index(r.Drop); i >= 0 {
			t.list, t.pos = slices.Delete(t.list, i, i+1), nil
		}
		t.waiting = slices.DeleteFunc(t.waiting, func(w record) bool { return w.Item.ID == r.Drop })
	}
}

// place puts a new item right after its After ("": first), if that is there.
func (t *transcript) place(r record) bool {
	at := 0
	if r.After != "" {
		i := t.index(r.After)
		if i < 0 {
			return false
		}
		at = i + 1
	}
	if at == len(t.list) {
		if t.pos != nil {
			t.pos[r.Item.ID] = at
		}
		t.list = append(t.list, *r.Item)
	} else {
		t.list, t.pos = slices.Insert(t.list, at, *r.Item), nil
	}
	return true
}

// placeWaiting places the items waiting for one that has come, until none
// can be.
func (t *transcript) placeWaiting() {
	for placed := true; placed; {
		placed = false
		for i, w := range t.waiting {
			if t.index(w.Item.ID) >= 0 { // written again meanwhile: the later one wins
				t.waiting = slices.Delete(t.waiting, i, i+1)
				placed = true
				break
			}
			if t.place(w) {
				t.waiting = slices.Delete(t.waiting, i, i+1)
				placed = true
				break
			}
		}
	}
}

// items is the transcript, with what still waits at its end.
func (t *transcript) items() []stored {
	out := t.list
	for _, w := range t.waiting {
		if t.index(w.Item.ID) < 0 {
			out = append(out, *w.Item)
		}
	}
	return out
}
