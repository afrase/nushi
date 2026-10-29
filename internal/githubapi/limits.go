package githubapi

import (
	"context"
	"fmt"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"
)

// GitHub's limits are per user, shared with everything on the token
// (gh in a terminal, agents running gh): REST 5,000 requests an hour,
// GraphQL 5,000 points, search 30 a minute; at most 100 requests at
// once, and writes a second apart. The gate keeps Nushi well inside them.
const (
	// parallel is how many requests a client has out at once.
	parallel = 4
	// floor is how much of a bucket polls leave for what the user asks.
	floor = 200
	// writeGap is the least time between two writes (GitHub's advice).
	writeGap = time.Second
	// spentWait is how long a bucket stays shut when GitHub says it's
	// spent without saying until when (GitHub's advice: a minute).
	spentWait = time.Minute
)

// Bucket is one of GitHub's rate limits as its last answer told it:
// "core" (REST), "graphql" (points), "search" and others.
type Bucket struct {
	Name             string
	Limit, Remaining int
	Reset            time.Time
}

// RateLimitedError is a bucket GitHub said is spent (no request goes
// until Until), or a poll held back while one is low.
type RateLimitedError struct {
	Bucket string
	Until  time.Time
	Low    bool // a poll held back; the user's own requests still go
	Left   int
}

func (e *RateLimitedError) Error() string {
	at := e.Until.Format("15:04")
	if e.Low {
		return fmt.Sprintf("GitHub's %s limit is low (%d left until %s): Nushi asks only when you do", e.Bucket, e.Left, at)
	}
	return fmt.Sprintf("GitHub's %s rate limit is spent until %s", e.Bucket, at)
}

type pollKey struct{}

// Poll marks a request as a poll (the app asking again on a timer):
// held back while its bucket is below the floor.
func Poll(ctx context.Context) context.Context { return context.WithValue(ctx, pollKey{}, true) }

func polling(ctx context.Context) bool { return ctx.Value(pollKey{}) != nil }

// limits is a client's gate: its place for each request, its buckets,
// and the breaker of each bucket GitHub said is spent.
type limits struct {
	places chan struct{}
	writes chan struct{} // the write's turn, held through it: writes go one at a time
	wrote  time.Time     // when the last write ended (under writes)
	now    func() time.Time
	sleep  func(context.Context, time.Duration) error

	mu      sync.Mutex
	buckets map[string]Bucket
	shut    map[string]time.Time // a spent bucket: shut until then
}

func newLimits() *limits {
	return &limits{places: make(chan struct{}, parallel), writes: make(chan struct{}, 1), now: time.Now, sleep: sleep,
		buckets: map[string]Bucket{}, shut: map[string]time.Time{}}
}

// enter waits for a place for a request in bucket (a write also for its
// turn, a second after the last), and returns what gives it back; ctx
// ending stops the wait. It refuses at once a request whose bucket is
// shut, and a poll whose bucket is low.
func (l *limits) enter(ctx context.Context, bucket string, write bool) (func(), error) {
	now := l.now()
	l.mu.Lock()
	until, b := l.shut[bucket], l.buckets[bucket]
	l.mu.Unlock()
	if until.After(now) {
		return nil, &RateLimitedError{Bucket: bucket, Until: until}
	}
	if polling(ctx) && b.Limit > 0 && b.Remaining < floor && b.Reset.After(now) {
		return nil, &RateLimitedError{Bucket: bucket, Until: b.Reset, Low: true, Left: b.Remaining}
	}
	if write {
		select {
		case l.writes <- struct{}{}:
		case <-ctx.Done():
			return nil, ctx.Err()
		}
		if wait := l.wrote.Add(writeGap).Sub(l.now()); wait > 0 {
			if err := l.sleep(ctx, wait); err != nil {
				<-l.writes
				return nil, err
			}
		}
	}
	select {
	case l.places <- struct{}{}:
	case <-ctx.Done():
		if write {
			<-l.writes
		}
		return nil, ctx.Err()
	}
	return func() {
		<-l.places
		if write {
			l.wrote = l.now()
			<-l.writes
		}
	}, nil
}

// saw keeps what an answer's headers say of its bucket (the one asked
// for, unless X-Ratelimit-Resource names another) and returns it. An
// Enterprise server with limits off sends none: the bucket stays unknown.
func (l *limits) saw(bucket string, h http.Header) Bucket {
	b := Bucket{Name: bucket}
	if r := h.Get("X-Ratelimit-Resource"); r != "" {
		b.Name = r
	}
	limit, err := strconv.Atoi(h.Get("X-Ratelimit-Limit"))
	if err != nil {
		return b
	}
	b.Limit = limit
	b.Remaining, _ = strconv.Atoi(h.Get("X-Ratelimit-Remaining"))
	if reset, err := strconv.ParseInt(h.Get("X-Ratelimit-Reset"), 10, 64); err == nil {
		b.Reset = time.Unix(reset, 0)
	}
	l.set(b)
	return b
}

func (l *limits) set(b Bucket) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.buckets[b.Name] = b
}

// spent shuts bucket after GitHub said it's spent: until Retry-After,
// else its reset when nothing is left, else a minute (a secondary limit
// that names no time).
func (l *limits) spent(bucket string, h http.Header) *RateLimitedError {
	if r := h.Get("X-Ratelimit-Resource"); r != "" {
		bucket = r
	}
	now := l.now()
	until := now.Add(spentWait)
	if s, err := strconv.Atoi(strings.TrimSpace(h.Get("Retry-After"))); err == nil && s >= 0 {
		until = now.Add(time.Duration(s) * time.Second)
	} else if reset, err := strconv.ParseInt(h.Get("X-Ratelimit-Reset"), 10, 64); err == nil && h.Get("X-Ratelimit-Remaining") == "0" {
		until = time.Unix(reset, 0)
	}
	l.mu.Lock()
	l.shut[bucket] = until
	l.mu.Unlock()
	return &RateLimitedError{Bucket: bucket, Until: until}
}

// Budget is what's left of each bucket, as GitHub said last, by name.
func (c *Client) Budget() []Bucket {
	l := c.lim
	l.mu.Lock()
	defer l.mu.Unlock()
	out := make([]Bucket, 0, len(l.buckets))
	for _, b := range l.buckets {
		out = append(out, b)
	}
	slices.SortFunc(out, func(a, b Bucket) int { return strings.Compare(a.Name, b.Name) })
	return out
}

func sleep(ctx context.Context, d time.Duration) error {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-t.C:
		return nil
	}
}

// etags keeps REST answers by URL with their ETag, so the next read of
// the same URL can be a free 304.
type etags struct {
	mu    sync.Mutex
	m     map[string]etag
	order []string // oldest first
}

type etag struct {
	tag  string
	body []byte
}

const (
	keptEtags   = 256
	maxEtagBody = 2 << 20
)

func newEtags() *etags { return &etags{m: map[string]etag{}} }

// get is the answer kept for u, its ETag to send and its body for a 304,
// taken together: one kept later, or none, can't be decoded in its place
// (zero when there's none).
func (e *etags) get(u string) etag {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.m[u]
}

func (e *etags) keep(u, tag string, body []byte) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if _, ok := e.m[u]; ok {
		e.order = slices.DeleteFunc(e.order, func(x string) bool { return x == u })
	}
	delete(e.m, u)
	if tag == "" || len(body) > maxEtagBody {
		return
	}
	e.m[u] = etag{tag: tag, body: body}
	e.order = append(e.order, u)
	if len(e.order) > keptEtags {
		delete(e.m, e.order[0])
		e.order = e.order[1:]
	}
}
