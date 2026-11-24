package github

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/keychain/keychaintest"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
)

// fakeClient is a host's client: its answers, and what it was asked.
type fakeClient struct {
	mu       sync.Mutex
	token    string
	inbox    githubapi.Inbox
	fail     error
	states   map[string]model.GitHubItem
	asked    []string
	blobs    map[githubapi.BlobAt]githubapi.Blob
	files    []githubapi.File
	written  []string
	heads    map[string][]githubapi.HeadPull // by repository and head
	branches map[string]string               // a branch's head, by name
	pull     *model.GitHubPull               // what Pull answers, when set
	inboxing func()                          // called as Inbox is asked, when set

	merges    []githubapi.MergeInput // Merge's calls
	autos     []githubapi.MergeInput // EnableAutoMerge's
	mergeErr  error                  // what Merge answers
	mergeText githubapi.MergeText
	edits     []fakeEdit // EditPull's calls
	refused   bool       // what Refused answers: GitHub said 401
}

// fakeEdit is one of EditPull's calls.
type fakeEdit struct {
	pull        string
	title, body *string
}

func (f *fakeClient) note(s string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.asked = append(f.asked, s)
}

func (f *fakeClient) Viewer(context.Context) (githubapi.User, error) {
	f.note("viewer")
	if f.token == "bad" {
		return githubapi.User{}, githubapi.ErrUnauthorized
	}
	return githubapi.User{Login: "octo-" + f.token}, nil
}

func (f *fakeClient) RateLimits(context.Context) ([]githubapi.Bucket, error) {
	return []githubapi.Bucket{{Name: "graphql", Limit: 5000, Remaining: 4000}}, nil
}
func (f *fakeClient) Budget() []githubapi.Bucket { return nil }
func (f *fakeClient) Refused() bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.refused
}
func (f *fakeClient) Inbox(_ context.Context, in githubapi.InboxFilter) (githubapi.Inbox, error) {
	f.note(fmt.Sprint("inbox ", in.Teams, " ", strings.Join(in.Repos, ",")))
	if f.inboxing != nil {
		f.inboxing()
	}
	return f.inbox, f.fail
}

// Items answers from states by node id "<repo>#<number>"; any other is
// unseen.
func (f *fakeClient) Items(_ context.Context, refs []model.GitHubRef) ([]model.GitHubItem, []model.GitHubRef, error) {
	names := make([]string, 0, len(refs))
	for _, r := range refs {
		names = append(names, fmt.Sprint(r.Repo, "#", r.Number))
	}
	f.note("items " + strings.Join(names, ","))
	if f.fail != nil {
		return nil, nil, f.fail
	}
	var items []model.GitHubItem
	var unseen []model.GitHubRef
	f.mu.Lock()
	defer f.mu.Unlock()
	for i, r := range refs {
		if it, ok := f.states[names[i]]; ok {
			it.GitHubRef = r
			items = append(items, it)
		} else {
			unseen = append(unseen, r)
		}
	}
	return items, unseen, nil
}

func (f *fakeClient) Pull(_ context.Context, _ string, n int) (model.GitHubPull, error) {
	if f.pull != nil {
		return *f.pull, nil
	}
	if n == 9 { // a fork's
		return model.GitHubPull{ID: "PR_9", Head: "Fix: the thing!", CrossRepo: true}, nil
	}
	return model.GitHubPull{ID: "PR_1", Head: "subtract"}, nil
}

func (f *fakeClient) Commits(_ context.Context, repo string, n int) (model.GitHubCommits, error) {
	f.note(fmt.Sprint("commits ", repo, "#", n))
	c := model.GitHubCommit{OID: strings.Repeat("c", 40), Headline: "Subtract", Author: "mira"}
	return model.GitHubCommits{Newest: []model.GitHubCommit{c}, First: c, Total: 1}, f.fail
}

func (f *fakeClient) PullsByHead(_ context.Context, repo, head string) ([]githubapi.HeadPull, time.Duration, error) {
	f.note("heads " + repo + " " + head)
	return f.heads[repo+" "+head], 0, f.fail
}

func (f *fakeClient) Issue(context.Context, string, int) (model.GitHubIssue, error) {
	return model.GitHubIssue{}, nil
}

func (f *fakeClient) JobLog(context.Context, string, int64) (string, error) {
	f.note("log")
	return "2026-10-26T04:15:18.0000000Z \x1b[31mfailed\x1b[0m", nil
}

func (f *fakeClient) Compare(context.Context, string, string, string) (string, []githubapi.File, error) {
	return "base0", f.files, nil
}

func (f *fakeClient) Blobs(_ context.Context, _ string, at []githubapi.BlobAt) (map[githubapi.BlobAt]githubapi.Blob, error) {
	out := map[githubapi.BlobAt]githubapi.Blob{}
	for _, a := range at {
		f.note("blob " + a.Commit + ":" + a.Path)
		out[a] = f.blobs[a]
	}
	return out, nil
}

func (f *fakeClient) Reply(context.Context, string, string) error {
	f.written = append(f.written, "reply")
	return nil
}

func (f *fakeClient) Resolve(context.Context, string, bool) error {
	f.written = append(f.written, "resolve")
	return nil
}

func (f *fakeClient) Viewed(context.Context, string, int) (viewed, changed []string, err error) {
	f.note("viewed")
	return []string{"a.go"}, []string{"b.go"}, f.fail
}

func (f *fakeClient) SetViewed(_ context.Context, _, path string, viewed bool) error {
	f.written = append(f.written, fmt.Sprintf("viewed %s %v", path, viewed))
	return nil
}

func (f *fakeClient) React(_ context.Context, subject, kind string, on bool) error {
	f.written = append(f.written, fmt.Sprintf("react %s %s %v", subject, kind, on))
	return nil
}

func (f *fakeClient) Comment(context.Context, string, string) error {
	f.written = append(f.written, "comment")
	return nil
}

func (f *fakeClient) EditPull(_ context.Context, pull string, title, body *string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.edits = append(f.edits, fakeEdit{pull, title, body})
	return nil
}

func (f *fakeClient) RerunFailed(_ context.Context, _ string, jobs []int64) ([]int64, error) {
	f.written = append(f.written, "rerun")
	return jobs[:1], nil
}

func (f *fakeClient) BranchHead(_ context.Context, _, branch string) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if sha, ok := f.branches[branch]; ok {
		return sha, nil
	}
	return "", githubapi.ErrNotFound
}

func (f *fakeClient) DeleteBranch(_ context.Context, _, branch string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.written = append(f.written, "delete "+branch)
	delete(f.branches, branch)
	return nil
}

func (f *fakeClient) CreateBranch(_ context.Context, _, branch, sha string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.written = append(f.written, "create "+branch)
	if f.branches == nil {
		f.branches = map[string]string{}
	}
	f.branches[branch] = sha
	return nil
}

func (f *fakeClient) DefaultBranch(context.Context, string) (string, error) { return "main", nil }

func (f *fakeClient) SubmitReview(context.Context, githubapi.Review) error {
	f.written = append(f.written, "review")
	return nil
}

func (f *fakeClient) MergeText(context.Context, string, int) (githubapi.MergeText, error) {
	return f.mergeText, nil
}

func (f *fakeClient) Merge(_ context.Context, m githubapi.MergeInput) error {
	f.merges = append(f.merges, m)
	return f.mergeErr
}

func (f *fakeClient) EnableAutoMerge(_ context.Context, m githubapi.MergeInput) error {
	f.autos = append(f.autos, m)
	return nil
}

func (f *fakeClient) DisableAutoMerge(context.Context, string) error {
	f.written = append(f.written, "disable auto-merge")
	return nil
}

func (f *fakeClient) Enqueue(_ context.Context, _, head string) error {
	f.written = append(f.written, "enqueue "+head)
	return nil
}

func (f *fakeClient) Dequeue(context.Context, string) error {
	f.written = append(f.written, "dequeue")
	return nil
}

// fakeStore is the real store in a temp folder for the cache, its token
// hosts in memory.
type fakeStore struct {
	*store.Store
	hosts []string
}

func (s *fakeStore) GitHubTokenHosts() ([]string, error)   { return slices.Clone(s.hosts), nil }
func (s *fakeStore) SaveGitHubTokenHosts(h []string) error { s.hosts = h; return nil }

type world struct {
	s       *Service
	mu      sync.Mutex // asked, read and clients, for the tests that ask at once
	asked   []string   // the hosts gh was asked a token for
	ghHosts []string   // the hosts gh is signed in to
	asking  func()     // called as gh is asked for a token, when set
	ghToken string     // gh's token for github.com ("gho_gh" when "")
	fetched []string
	tokens  *keychaintest.Keychain
	store   *fakeStore
	clients map[string]*fakeClient // by token
	branch  map[string][2]string   // by folder: its branch and the remote it's pushed to
}

func newWorld(t *testing.T) *world {
	t.Helper()
	w := &world{tokens: &keychaintest.Keychain{Items: map[string]string{}}, store: &fakeStore{Store: store.New(t.TempDir())}, clients: map[string]*fakeClient{}, ghHosts: []string{"github.com"},
		branch: map[string][2]string{}}
	w.s = New(Deps{
		Gh: Gh{
			Token: func(ctx context.Context, host string) (string, string, error) {
				w.mu.Lock()
				w.asked = append(w.asked, host)
				asking := w.asking
				w.mu.Unlock()
				if asking != nil {
					asking()
				}
				if ctx.Err() != nil {
					return "", "gh", ctx.Err() // as ghToken: gh killed, so it didn't say
				}
				if host == "github.com" || host == "git.corp.example" {
					w.mu.Lock()
					defer w.mu.Unlock()
					if w.ghToken != "" {
						return w.ghToken, "gh", nil
					}
					return "gho_gh", "gh", nil
				}
				return "", "", nil
			},
			Hosts: func() []string {
				w.mu.Lock()
				defer w.mu.Unlock()
				return slices.Clone(w.ghHosts)
			},
		},
		Tokens: w.tokens, Store: w.store,
		Open: func(_, token string) Client {
			w.mu.Lock()
			defer w.mu.Unlock()
			c := w.clients[token]
			if c == nil {
				c = &fakeClient{token: token, states: map[string]model.GitHubItem{}, blobs: map[githubapi.BlobAt]githubapi.Blob{}}
				w.clients[token] = c
			}
			return c
		},
		Keys: Keys{NeedsOK: func(err error) bool { return errors.Is(err, keychaintest.ErrNeedsOK) }, Restart: func(error) bool { return false }, Missing: func(error) bool { return false }},
		Remotes: func(_ context.Context, folder string) (map[string]string, error) {
			if folder == "lab" {
				return map[string]string{"origin": "https://gitlab.com/me/lab"}, nil
			}
			return map[string]string{"origin": "git@github.com:afrase/" + folder + ".git", "fork": "https://github.com/me/" + folder}, nil
		},
		Fetch: func(_ context.Context, folder, remote, refspec string) error {
			w.fetched = append(w.fetched, folder+" "+remote+" "+refspec)
			return nil
		},
		CheckBranch: func(name string) error {
			if strings.ContainsAny(name, " ~^:") {
				return errors.New("bad")
			}
			return nil
		},
		Head: func(_ context.Context, folder string) (string, string) {
			b := w.branch[folder]
			return b[0], b[1]
		},
		DefaultBranch: func(context.Context, string) string { return "origin/main" },
	})
	return w
}

func TestHostsAndTokens(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	hosts, err := w.s.Hosts(ctx)
	if err != nil || len(hosts) != 1 || hosts[0].Source != "gh" || hosts[0].User.Login != "octo-gho_gh" || hosts[0].Kind != "oauth" || len(hosts[0].Budget) != 1 {
		t.Fatalf("%+v %v", hosts, err)
	}
	if _, err := w.s.AddToken(ctx, "git.example.com", "bad"); !errors.Is(err, githubapi.ErrUnauthorized) || len(w.tokens.Items) != 0 {
		t.Fatalf("a refused token was kept: %v", err)
	}
	if _, err := w.s.AddToken(ctx, "Not A Host", "ghp_x"); err == nil || !strings.Contains(err.Error(), `"Not A Host"`) {
		t.Fatalf("a bad host: %v", err)
	}
	if u, err := w.s.AddToken(ctx, "git.example.com", "ghp_ent"); err != nil || u.Login != "octo-ghp_ent" {
		t.Fatalf("%+v %v", u, err)
	}
	if _, err := w.s.AddToken(ctx, "github.com", "ghp_mine"); err != nil {
		t.Fatal(err)
	}
	hosts, _ = w.s.Hosts(ctx)
	if len(hosts) != 2 || hosts[0].Host != "git.example.com" || hosts[1].Source != "token" || hosts[1].Kind != "classic" || !hosts[1].Pasted {
		t.Fatalf("a pasted token goes before gh's: %+v", hosts)
	}
	if kept, err := w.s.RemoveToken("github.com"); err != nil || kept != "" {
		t.Fatalf("remove: %q %v", kept, err)
	}
	if hosts, _ = w.s.Hosts(ctx); hosts[1].Source != "gh" || w.tokens.Items["github.com"] != "" {
		t.Fatalf("back to gh's: %+v", hosts)
	}
	// A new build of Nushi: the keychain wants the user's OK.
	w2 := newWorld(t)
	w2.tokens.Items["git.example.com"], w2.store.hosts, w2.tokens.Locked = "ghp_ent", []string{"git.example.com"}, true
	hosts, _ = w2.s.Hosts(ctx)
	if !hosts[0].NeedsOK {
		t.Fatalf("%+v", hosts)
	}
	if err := w2.s.AllowToken(t.Context(), "git.example.com"); err != nil {
		t.Fatal(err)
	}
	if hosts, _ = w2.s.Hosts(ctx); hosts[0].NeedsOK || hosts[0].User.Login != "octo-ghp_ent" {
		t.Fatalf("%+v", hosts)
	}
}

// A token GitHub refused is read again by the next call, whichever it
// is (no host listing needed), at most every noTokenFor, so a revoked
// one doesn't start gh on every poll.
func TestRefusedTokenReadAgain(t *testing.T) {
	w := newWorld(t)
	w.ghToken = "gho_old"
	inbox := func() string {
		t.Helper()
		_, _ = w.s.Inbox(t.Context(), "github.com", githubapi.InboxFilter{}, false)
		h, err := w.s.host(t.Context(), "github.com", false)
		testcheck.NoErr(t, err)
		return h.c.(*fakeClient).token
	}
	if got := inbox(); got != "gho_old" {
		t.Fatal(got)
	}
	old := w.clients["gho_old"]
	old.mu.Lock()
	old.refused, old.fail = true, githubapi.ErrUnauthorized
	old.mu.Unlock()
	w.mu.Lock()
	w.ghToken = "gho_new" // gh auth login again
	w.mu.Unlock()
	if got := inbox(); got != "gho_old" || len(w.asked) != 1 {
		t.Fatalf("gh asked again within noTokenFor: %s %v", got, w.asked)
	}
	w.s.mu.Lock()
	w.s.clients["github.com"].opened = time.Now().Add(-noTokenFor)
	w.s.mu.Unlock()
	if got := inbox(); got != "gho_new" || len(w.asked) != 2 {
		t.Fatalf("a refused token kept: %s %v", got, w.asked)
	}
}

// Settings listing the hosts reads a refused token again at once, however
// new its client: the user who just ran `gh auth login` sees the new
// login, not the old refusal, without waiting out noTokenFor.
func TestHostsReadRefusedTokenAgain(t *testing.T) {
	w := newWorld(t)
	w.ghToken = "gho_old"
	_, err := w.s.host(t.Context(), "github.com", false)
	testcheck.NoErr(t, err)
	old := w.clients["gho_old"]
	old.mu.Lock()
	old.refused = true
	old.mu.Unlock()
	w.mu.Lock()
	w.ghToken = "gho_new" // gh auth login again
	w.mu.Unlock()
	hosts, err := w.s.Hosts(t.Context())
	testcheck.NoErr(t, err)
	for _, h := range hosts {
		if h.Host == "github.com" && (h.User.Login != "octo-gho_new" || h.Problem != "") {
			t.Fatalf("the refused token still listed: %+v", h)
		}
	}
}

// A refused client is dropped only while it's still the one kept: a
// token added meanwhile stays.
func TestRefusedDropKeepsANewerToken(t *testing.T) {
	w := newWorld(t)
	h, err := w.s.host(t.Context(), "github.com", false)
	testcheck.NoErr(t, err)
	if _, err := w.s.AddToken(t.Context(), "github.com", "ghp_mine"); err != nil {
		t.Fatal(err)
	}
	w.s.mu.Lock()
	kept := w.s.clients["github.com"]
	w.s.mu.Unlock()
	w.s.drop("github.com", h)
	w.s.mu.Lock()
	defer w.s.mu.Unlock()
	if got := w.s.clients["github.com"]; got != kept {
		t.Fatalf("the newer token's client was dropped: %+v", got)
	}
}

// Removing a token forgets the host first: a keychain that can't delete
// it (no keyring, a dismissed prompt) doesn't leave the host stuck, and
// the removal names the keychain item left behind, for the user to
// delete.
func TestRemoveTokenKeychainFails(t *testing.T) {
	w := newWorld(t)
	if _, err := w.s.AddToken(t.Context(), "git.example.com", "ghp_ent"); err != nil {
		t.Fatal(err)
	}
	w.tokens.Fail = errors.New("your keyring is locked")
	if kept, err := w.s.RemoveToken("git.example.com"); err != nil || kept != "Nushi: GitHub token for git.example.com" {
		t.Fatalf("remove: %q %v", kept, err)
	}
	if hosts, _ := w.s.Store.GitHubTokenHosts(); len(hosts) != 0 {
		t.Fatalf("still given a token: %v", hosts)
	}
	w.s.mu.Lock()
	defer w.s.mu.Unlock()
	if w.s.clients["git.example.com"] != nil {
		t.Fatal("its client kept")
	}
}

func TestNoToken(t *testing.T) {
	w := newWorld(t)
	w.ghHosts = append(w.ghHosts, "git.example.com") // gh knows it, but has no token for it
	for range 2 {
		if _, err := w.s.Inbox(t.Context(), "git.example.com", githubapi.InboxFilter{}, false); err == nil || !strings.Contains(err.Error(), "gh auth login") {
			t.Fatal(err)
		}
	}
	if len(w.asked) != 1 {
		t.Fatalf("gh asked again within 30 s: %v", w.asked)
	}
	w.s.noToken["git.example.com"] = time.Now().Add(-noTokenFor)
	if _, err := w.s.Inbox(t.Context(), "git.example.com", githubapi.InboxFilter{}, false); err == nil || len(w.asked) != 2 {
		t.Fatalf("gh not asked after 30 s: %v %v", err, w.asked)
	}
}

// A token read its request cut short isn't gh having no token: the next
// request asks gh again.
func TestTokenReadCutShort(t *testing.T) {
	w := newWorld(t)
	ctx, cancel := context.WithCancel(t.Context())
	w.asking = cancel // the app dropped the call while gh ran
	if _, err := w.s.client(ctx, "github.com"); !errors.Is(err, context.Canceled) {
		t.Fatalf("a read cut short: %v", err)
	}
	w.asking = nil
	if _, err := w.s.client(t.Context(), "github.com"); err != nil || len(w.asked) != 2 {
		t.Fatalf("gh not asked again: %v %v", err, w.asked)
	}
}

// A host gh signed in to after the daemon started is known: gh's hosts
// are read afresh once the host's unknownFor is past.
func TestGhLoginSince(t *testing.T) {
	w := newWorld(t)
	now := time.Now()
	w.s.now = func() time.Time { return now }
	if _, err := w.s.client(t.Context(), "git.corp.example"); err == nil {
		t.Fatal("a host gh doesn't know")
	}
	w.mu.Lock()
	w.ghHosts = append(w.ghHosts, "git.corp.example") // gh auth login, the config written
	w.mu.Unlock()
	now = now.Add(unknownFor)
	if _, err := w.s.client(t.Context(), "git.corp.example"); err != nil {
		t.Fatal(err)
	}
}

// Ten asking at once for a host not yet read all get the same client.
func TestHostAtOnce(t *testing.T) {
	w := newWorld(t)
	var mu sync.Mutex
	n, all := 0, make(chan struct{})
	w.asking = func() {
		mu.Lock()
		if n++; n == 10 {
			close(all)
		}
		mu.Unlock()
		select {
		case <-all:
		case <-time.After(5 * time.Second): // asked fewer times: fine too
		}
	}
	got := make([]*host, 10)
	var wg sync.WaitGroup
	for i := range got {
		wg.Go(func() { got[i], _ = w.s.host(t.Context(), "github.com", false) })
	}
	wg.Wait()
	for _, h := range got {
		if h == nil || h != got[0] {
			t.Fatal("two clients of github.com")
		}
	}
}

func TestInboxKeepsTheLastKnown(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	pr := model.GitHubItem{ID: "PR_1", Pull: true, Number: 1}
	if _, err := w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false); err != nil {
		t.Fatal(err)
	}
	c := w.clients["gho_gh"]
	c.inbox = githubapi.Inbox{Mine: []model.GitHubItem{pr}}
	in, _ := w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, true)
	if len(in.Mine) != 0 || len(c.asked) != 1 {
		t.Fatalf("asked again within 20 s: %v", c.asked)
	}
	in, err := w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{Repos: []string{"a/b"}}, true) // another filter: asked
	if err != nil || len(in.Mine) != 1 {
		t.Fatalf("%+v %v", in, err)
	}
	w.s.inboxes["github.com "+inboxKey(githubapi.InboxFilter{Repos: []string{"a/b"}})] = inboxCache{at: in.At.Add(-inboxFresh), inbox: in.Inbox}
	c.fail = errors.New("GitHub's graphql rate limit is spent")
	in, err = w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{Repos: []string{"a/b"}}, true)
	if err != nil || in.Stale == nil || len(in.Mine) != 1 {
		t.Fatalf("the last inbox goes on a failure: %+v %v", in, err)
	}
}

// The inbox GitHub gave last is kept per host and filter, read back
// without GitHub, and dropped when the host's token changes.
func TestInboxCache(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	if in, err := w.s.CachedInbox("github.com", githubapi.InboxFilter{}); err != nil || !in.At.IsZero() {
		t.Fatalf("nothing kept yet: %+v %v", in, err)
	}
	if _, err := w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false); err != nil {
		t.Fatal(err)
	}
	c := w.clients["gho_gh"]
	c.fail = errors.New("not asked")
	in, err := w.s.CachedInbox("github.com", githubapi.InboxFilter{})
	if err != nil || in.At.IsZero() || len(c.asked) != 1 {
		t.Fatalf("%+v %v, asked %v", in, err, c.asked)
	}
	for _, f := range []githubapi.InboxFilter{{Teams: true}, {Days: 90}, {Days: 90, Wide: []string{"mine"}},
		{Hide: []string{"a/b"}}, {Owners: []string{"a"}}, {Repos: []string{"a/b"}}} {
		if in, _ := w.s.CachedInbox("github.com", f); !in.At.IsZero() {
			t.Errorf("another filter's inbox: %+v", f)
		}
	}
	if _, err := w.s.CachedInbox("evil.example", githubapi.InboxFilter{}); err == nil {
		t.Error("a host never known")
	}
	if _, err := w.s.RemoveToken("github.com"); err != nil {
		t.Fatal(err)
	}
	if in, _ := w.s.CachedInbox("github.com", githubapi.InboxFilter{}); !in.At.IsZero() {
		t.Error("kept after the token changed")
	}
}

// TestWroteMakesItemsOld: a write made in Nushi makes its host's items
// old, so the next Items asks GitHub again (the chips and rows read them,
// ADR 0140); GitHub failing then keeps the last known.
func TestWroteMakesItemsOld(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	_, _ = w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false)
	c := w.clients["gho_gh"]
	c.states["a/b#1"] = model.GitHubItem{ID: "PR_1", Pull: true, State: "open"}
	refs := []model.GitHubRef{{Host: "github.com", Repo: "a/b", Number: 1}}
	asked := func() int {
		return len(slices.DeleteFunc(slices.Clone(c.asked), func(s string) bool { return !strings.HasPrefix(s, "items") }))
	}
	_, _, _, _ = w.s.Items(ctx, refs, true)
	_, _, _, _ = w.s.Items(ctx, refs, true)
	if n := asked(); n != 1 {
		t.Fatalf("asked again within 30 s: %v", c.asked)
	}
	if err := w.s.Comment(ctx, "GitHub.com", "PR_1", "Thanks"); err != nil {
		t.Fatal(err)
	}
	c.fail = errors.New("down")
	items, _, _, err := w.s.Items(ctx, refs, true)
	if n := asked(); n != 2 || err == nil || len(items) != 1 || items[0].State != "open" {
		t.Fatalf("after a write: asked %d times, %+v %v", n, items, err)
	}
	if err := w.s.Comment(ctx, "github.com", "PR_1", " "); err == nil {
		t.Fatal("an empty comment")
	}
}

func TestViewed(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	_, _ = w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false)
	ref := model.GitHubRef{Host: "github.com", Repo: "acme/lumen", Number: 218}
	viewed, changed, err := w.s.Viewed(ctx, ref, true)
	if err != nil || !slices.Equal(viewed, []string{"a.go"}) || !slices.Equal(changed, []string{"b.go"}) {
		t.Fatalf("%v %v %v", viewed, changed, err)
	}
	if err := w.s.SetViewed(ctx, "github.com", "PR_218", "a.go", false); err != nil {
		t.Fatal(err)
	}
	if c := w.clients["gho_gh"]; !slices.Contains(c.written, "viewed a.go false") {
		t.Fatalf("%v", c.written)
	}
}

func TestReact(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	_, _ = w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false)
	if err := w.s.React(ctx, "github.com", "IC_1", "heart", true); err != nil {
		t.Fatal(err)
	}
	if c := w.clients["gho_gh"]; !slices.Contains(c.written, "react IC_1 heart true") {
		t.Fatalf("%v", c.written)
	}
}

func TestRerunFailed(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	_, _ = w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false)
	n, err := w.s.RerunFailed(ctx, model.GitHubRef{Host: "github.com", Repo: "afrase/nushi-gh-test", Number: 1}, []int64{8, 9})
	if c := w.clients["gho_gh"]; err != nil || n != 1 || !slices.Contains(c.written, "rerun") {
		t.Fatalf("%d %v %v", n, err, c.written)
	}
}

func TestHeadBranch(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	_, _ = w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false)
	c := w.clients["gho_gh"]
	ref := model.GitHubRef{Host: "github.com", Repo: "afrase/nushi-gh-test", Number: 3}
	p := model.GitHubPull{State: "open", Head: "feat", HeadOID: "abc", HeadRepo: "afrase/nushi-gh-test"}
	c.pull = &p
	c.branches = map[string]string{"feat": "abc"}
	if _, err := w.s.DeleteHeadBranch(ctx, ref); err == nil || !strings.Contains(err.Error(), "still open") {
		t.Fatalf("an open pull request's branch: %v", err)
	}
	p.State = "merged"
	c.branches["feat"] = "def" // moved on since
	if _, err := w.s.DeleteHeadBranch(ctx, ref); err == nil || !strings.Contains(err.Error(), "moved on") {
		t.Fatalf("a branch with new commits: %v", err)
	}
	c.branches["feat"] = "abc"
	if ok, err := w.s.DeleteHeadBranch(ctx, ref); !ok || err != nil {
		t.Fatalf("%v %v", ok, err)
	}
	if ok, err := w.s.DeleteHeadBranch(ctx, ref); ok || err != nil { // gone already
		t.Fatalf("%v %v", ok, err)
	}
	if err := w.s.RestoreHeadBranch(ctx, ref); err != nil || c.branches["feat"] != "abc" {
		t.Fatalf("%v %v", err, c.branches)
	}
	if err := w.s.RestoreHeadBranch(ctx, ref); err != nil { // there already
		t.Fatal(err)
	}
	p.Head = "main" // the default branch
	if _, err := w.s.DeleteHeadBranch(ctx, ref); err == nil || !strings.Contains(err.Error(), "default branch") {
		t.Fatalf("the default branch: %v", err)
	}
	if got := strings.Join(c.written, ","); got != "delete feat,create feat" {
		t.Fatal(got)
	}
}

func TestFiles(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	_, _ = w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false)
	c := w.clients["gho_gh"]
	head := strings.Repeat("b", 40)
	c.files = []githubapi.File{{Path: "new.go", Status: "added"}, {Path: "gone.go", Status: "removed"},
		{Path: "b.go", OldPath: "a.go", Status: "renamed"}, {Path: "logo.png", Status: "modified"}}
	c.blobs[githubapi.BlobAt{Commit: head, Path: "new.go"}] = githubapi.Blob{Found: true, Text: "new"}
	c.blobs[githubapi.BlobAt{Commit: "base0", Path: "gone.go"}] = githubapi.Blob{Found: true, Text: "old"}
	c.blobs[githubapi.BlobAt{Commit: "base0", Path: "a.go"}] = githubapi.Blob{Found: true, Text: "a"}
	c.blobs[githubapi.BlobAt{Commit: head, Path: "b.go"}] = githubapi.Blob{Found: true, Text: "b"}
	c.blobs[githubapi.BlobAt{Commit: head, Path: "logo.png"}] = githubapi.Blob{Found: true, Skipped: "binary"}
	ref := model.GitHubRef{Host: "github.com", Repo: "a/b", Number: 1}
	files, err := w.s.Files(ctx, ref, strings.Repeat("a", 40), head)
	if err != nil || len(files) != 4 {
		t.Fatalf("%+v %v", files, err)
	}
	if f := files[0]; f.Status != "added" || f.New != "new" || f.Old != "" {
		t.Fatalf("%+v", f)
	}
	if f := files[1]; f.Status != "deleted" || f.Old != "old" {
		t.Fatalf("%+v", f)
	}
	if f := files[2]; f.Status != "renamed" || f.OldPath != "a.go" || f.Old != "a" || f.New != "b" {
		t.Fatalf("%+v", f)
	}
	if f := files[3]; f.Skipped != "binary" || f.New != "" {
		t.Fatalf("%+v", f)
	}
	before := len(c.asked)
	if _, err := w.s.Files(ctx, ref, strings.Repeat("a", 40), head); err != nil || len(c.asked) != before {
		t.Fatalf("texts asked again: %v", c.asked[before:])
	}
	if _, err := w.s.Files(ctx, ref, "main", head); err == nil {
		t.Fatal("a branch's name for a commit")
	}
}

// TestFilesPastTheCache: a pull request whose texts pass the cache's 32 MB
// (lockfiles, generated files) still gets every text it fetched, though
// the cache drops its first ones before the answer is built.
func TestFilesPastTheCache(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	_, _ = w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false)
	c := w.clients["gho_gh"]
	head := strings.Repeat("b", 40)
	big := strings.Repeat("x", 900<<10) // under the 1 MB a file
	for i := range 40 {
		p := fmt.Sprintf("lock%d.json", i)
		c.files = append(c.files, githubapi.File{Path: p, Status: "modified"})
		c.blobs[githubapi.BlobAt{Commit: "base0", Path: p}] = githubapi.Blob{Found: true, Text: big}
		c.blobs[githubapi.BlobAt{Commit: head, Path: p}] = githubapi.Blob{Found: true, Text: big + "y"}
	}
	files, err := w.s.Files(ctx, model.GitHubRef{Host: "github.com", Repo: "a/b", Number: 1}, strings.Repeat("a", 40), head)
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range files {
		if f.Old != big || f.New != big+"y" {
			t.Fatalf("%s came back with a side empty (%d and %d bytes)", f.Path, len(f.Old), len(f.New))
		}
	}
}

func TestJobTail(t *testing.T) {
	w := newWorld(t)
	ref := model.GitHubRef{Host: "github.com", Repo: "a/b"}
	for range 2 {
		if tail, err := w.s.JobTail(t.Context(), ref, 7); err != nil || tail != "failed" {
			t.Fatalf("%q %v", tail, err)
		}
	}
	if n := slices.Index(w.clients["gho_gh"].asked, "log"); n < 0 || slices.Contains(w.clients["gho_gh"].asked[n+1:], "log") {
		t.Fatalf("asked twice: %v", w.clients["gho_gh"].asked)
	}
	// The same job's number on a host Nushi gives no token to, or in
	// another repository, isn't the tail kept.
	if _, err := w.s.JobTail(t.Context(), model.GitHubRef{Host: "evil.example", Repo: "a/b"}, 7); err == nil {
		t.Fatal("a kept tail for an unknown host")
	}
	_, _ = w.s.JobTail(t.Context(), model.GitHubRef{Host: "github.com", Repo: "a/c"}, 7)
	if logs := slices.DeleteFunc(slices.Clone(w.clients["gho_gh"].asked), func(s string) bool { return s != "log" }); len(logs) != 2 {
		t.Fatal("another repository's job 7 had a/b's tail")
	}
}

func TestParseRemote(t *testing.T) {
	for in, want := range map[string]string{
		"https://github.com/afrase/nushi.git":         "github.com afrase/nushi",
		"https://github.com/afrase/nushi":             "github.com afrase/nushi",
		"git@github.com:afrase/nushi.git":             "github.com afrase/nushi",
		"ssh://git@ssh.github.com:443/afrase/nushi":   "github.com afrase/nushi",
		"ssh://git@git.example.com:2222/team/app.git": "git.example.com team/app",
		"https://git.example.com:8443/team/app":       "git.example.com:8443 team/app",
		"https://github.com/afrase":                   "",
		"/Users/me/repo.git":                          "",
		"file:///tmp/x/y":                             "",
	} {
		h, r, ok := parseRemote(in)
		got := ""
		if ok {
			got = h + " " + r
		}
		if got != want {
			t.Errorf("%s: %q", in, got)
		}
	}
}

func TestRepos(t *testing.T) {
	w := newWorld(t)
	repos := w.s.Repos(t.Context(), []string{"one", "two", "one"})
	if len(repos) != 4 || repos[0].Repo != "me/one" || repos[1].Repo != "afrase/one" || len(repos[1].Folders) != 1 {
		t.Fatalf("%+v", repos)
	}
	// Remotes spelling one repository in two cases are one repository.
	repos = w.s.Repos(t.Context(), []string{"one", "One"})
	if len(repos) != 2 || repos[0].Repo != "me/one" || !slices.Equal(repos[1].Folders, []string{"one", "One"}) {
		t.Fatalf("%+v", repos)
	}
}

// TestUnknownHosts: a host that's neither github.com, nor gh's, nor given
// a token is refused before any token is read (gh would give its
// GH_ENTERPRISE_TOKEN for any), so no token goes to a server someone's
// text named.
func TestUnknownHosts(t *testing.T) {
	w := newWorld(t)
	w.ghHosts = append(w.ghHosts, "git.corp.example")
	ctx := t.Context()
	for _, h := range []string{"evil.example", "github.com.evil.example", "github.com@evil.example", "evil.example/github.com",
		"github.com:8443", "git.corp.example.evil", "ev il", "", "github..com"} {
		if _, err := w.s.Inbox(ctx, h, githubapi.InboxFilter{}, false); err == nil {
			t.Errorf("%q: asked", h)
		}
		if _, err := w.s.Pull(ctx, model.GitHubRef{Host: h, Repo: "a/b", Number: 1}, false); err == nil {
			t.Errorf("%q: asked", h)
		}
		if _, err := w.s.Commits(ctx, model.GitHubRef{Host: h, Repo: "a/b", Number: 1}, false); err == nil {
			t.Errorf("%q: asked", h)
		}
		_, _, _, _ = w.s.Items(ctx, []model.GitHubRef{{Host: h, Repo: "a/b", Number: 1}}, false)
	}
	if len(w.asked) != 0 || len(w.clients) != 0 {
		t.Fatalf("a token was read for %v", w.asked)
	}
	// Spellings of known hosts are the hosts.
	for _, h := range []string{"GitHub.com", "github.com.", "github.com:443", " github.com "} {
		if _, err := w.s.Inbox(ctx, h, githubapi.InboxFilter{}, false); err != nil {
			t.Errorf("%q: %v", h, err)
		}
	}
	if _, err := w.s.Inbox(ctx, "Git.Corp.Example", githubapi.InboxFilter{}, false); err != nil {
		t.Errorf("gh's own host: %v", err)
	}
	if slices.ContainsFunc(w.asked, func(h string) bool { return h != "github.com" && h != "git.corp.example" }) {
		t.Fatalf("asked gh for %v", w.asked)
	}
}

// TestUnknownHostRemembered: a host found unknown (a GitLab remote, a
// link in a transcript) is believed for unknownFor, gh's config not read
// again for it meanwhile; a gh login to it shows once that's past, and a
// token added or removed for a host counts at once.
func TestUnknownHostRemembered(t *testing.T) {
	w := newWorld(t)
	now := time.Date(2026, 11, 24, 9, 0, 0, 0, time.UTC)
	w.s.now = func() time.Time { return now }
	read := 0
	hosts := w.s.Gh.Hosts
	w.s.Gh.Hosts = func() []string { read++; return hosts() }
	if w.s.Known("gitlab.com") || w.s.Known("GitLab.com") || read != 1 {
		t.Fatalf("known, or gh's hosts read %d times", read)
	}
	w.mu.Lock()
	w.ghHosts = append(w.ghHosts, "gitlab.com") // gh auth login, say
	w.mu.Unlock()
	now = now.Add(unknownFor - time.Second)
	if w.s.Known("gitlab.com") || read != 1 {
		t.Fatalf("not believed for %v: read %d", unknownFor, read)
	}
	now = now.Add(time.Second)
	if !w.s.Known("gitlab.com") || read != 2 {
		t.Fatalf("gh's login not seen once past it: read %d", read)
	}
	// A token added makes a host known at once; removed, unknown at once.
	if w.s.Known("ghe.example") {
		t.Fatal("never given a token")
	}
	if _, err := w.s.AddToken(t.Context(), "ghe.example", "ghp_e"); err != nil {
		t.Fatal(err)
	}
	if !w.s.Known("ghe.example") {
		t.Fatal("unknown after its token was added")
	}
	if _, err := w.s.RemoveToken("ghe.example"); err != nil {
		t.Fatal(err)
	}
	if w.s.Known("ghe.example") {
		t.Fatal("known after its token was removed")
	}
}

func TestCheckOut(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	co, err := w.s.CheckOut(ctx, "app", model.GitHubRef{Host: "github.com", Repo: "afrase/app", Number: 1})
	if err != nil || co.Branch != "subtract" || co.From != "refs/remotes/origin/subtract" || co.Link.ID != "PR_1" || !co.Link.Pull {
		t.Fatalf("%+v %v", co, err)
	}
	co, err = w.s.CheckOut(ctx, "app", model.GitHubRef{Host: "github.com", Repo: "me/app", Number: 9})
	if err != nil || co.Branch != "pr-9-fix-the-thing" || co.From != "refs/nushi/pull/9" {
		t.Fatalf("%+v %v", co, err)
	}
	want := []string{"app origin +refs/heads/subtract:refs/remotes/origin/subtract", "app fork +refs/pull/9/head:refs/nushi/pull/9"}
	if !slices.Equal(w.fetched, want) {
		t.Fatalf("%v", w.fetched)
	}
	if _, err := w.s.CheckOut(ctx, "app", model.GitHubRef{Host: "github.com", Repo: "someone/else", Number: 1}); err == nil {
		t.Fatal("a folder that isn't a clone of it")
	}
}

// TestOnlyAskedWrites: reading everything there is (the inbox, states, a
// pull request, its commits, an issue, files, a log, a checkout) writes nothing to
// GitHub; only the user's writes do.
func TestOnlyAskedWrites(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	ref := model.GitHubRef{Host: "github.com", Repo: "afrase/app", Number: 1}
	_, _ = w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, true)
	_, _, _, _ = w.s.Items(ctx, []model.GitHubRef{ref}, true)
	_, _ = w.s.Pull(ctx, ref, true)
	if cs, err := w.s.Commits(ctx, ref, true); err != nil || cs.Total != 1 || cs.Newest[0].Author != "mira" || cs.First.Author != "mira" {
		t.Fatalf("commits %+v %v", cs, err)
	}
	_, _ = w.s.Issue(ctx, ref, true)
	_, _ = w.s.Files(ctx, ref, strings.Repeat("a", 40), strings.Repeat("b", 40))
	_, _ = w.s.JobTail(ctx, ref, 7)
	_, _ = w.s.CheckOut(ctx, "app", ref)
	if c := w.clients["gho_gh"]; len(c.written) != 0 {
		t.Fatalf("wrote %v", c.written)
	}
}
