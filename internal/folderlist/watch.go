package folderlist

import (
	"context"
	"encoding/binary"
	"hash"
	"hash/fnv"
	"os"
	"time"
)

// Watch sends rel's listing (List's), then again each time it changes,
// looked at every every, until ctx ends (nil), send fails, or rel can't
// be listed (that error). A change is a folder's own time (an entry
// added, removed or renamed), a sent entry's kind, size or time, or the
// top .gitignore's: a stat each, and git runs only when one changed.
func Watch(ctx context.Context, root, rel string, o Options, every time.Duration, send func([]Listing) error) error {
	o = o.bounded()
	tick := time.NewTicker(every)
	defer tick.Stop()
	for {
		ignores := ignoresStamp(root)
		ls, err := List(ctx, root, rel, o)
		if err != nil {
			return err
		}
		if err := send(ls); err != nil {
			return err
		}
		// As read: a change since the read differs from it.
		last := listed(ls, ignores)
		for {
			select {
			case <-ctx.Done():
				return nil
			case <-tick.C:
			}
			if now(root, ls) != last {
				break
			}
		}
	}
}

// stamp sums up what a listing saw, to tell a change.
type stamp uint64

func newHash() hash.Hash64 { return fnv.New64a() }

func put(h hash.Hash64, vs ...int64) {
	var b [8]byte
	for _, v := range vs {
		binary.LittleEndian.PutUint64(b[:], uint64(v)) //nolint:gosec // a hash's input
		_, _ = h.Write(b[:])
	}
}

func putEntry(h hash.Hash64, e Entry) {
	_, _ = h.Write([]byte(e.Name + "\x00" + string(e.Kind) + "\x00"))
	put(h, e.Size, e.Modified.UnixNano())
}

// listed is the stamp of ls as it was read, with the .gitignore's.
func listed(ls []Listing, ignores int64) stamp {
	h := newHash()
	put(h, ignores)
	for _, l := range ls {
		if l.Missing {
			put(h, -1)
			continue
		}
		put(h, l.at.UnixNano())
		for _, e := range l.Entries {
			putEntry(h, e)
		}
	}
	return stamp(h.Sum64())
}

// now is the stamp of the folders and entries of ls as they are now: the
// same as listed's when nothing changed.
func now(root string, ls []Listing) stamp {
	h := newHash()
	put(h, ignoresStamp(root))
	r, err := os.OpenRoot(root)
	if err != nil {
		return stamp(h.Sum64())
	}
	defer r.Close() //nolint:errcheck // read-only
	for _, l := range ls {
		rel := l.Path
		if rel == "" {
			rel = "."
		}
		fi, err := r.Stat(rel)
		if err != nil {
			put(h, -1)
			continue
		}
		put(h, fi.ModTime().UnixNano())
		for _, e := range l.Entries {
			p := join(l.Path, e.Name)
			info, err := r.Lstat(p)
			putEntry(h, entry(r, p, e.Name, info, err))
		}
	}
	return stamp(h.Sum64())
}

// ignoresStamp is the time of root's .gitignore, which says what's
// ignored throughout (0 when there's none).
func ignoresStamp(root string) int64 {
	r, err := os.OpenRoot(root)
	if err != nil {
		return 0
	}
	defer r.Close() //nolint:errcheck // read-only
	fi, err := r.Stat(".gitignore")
	if err != nil {
		return 0
	}
	return fi.ModTime().UnixNano() ^ fi.Size()
}
