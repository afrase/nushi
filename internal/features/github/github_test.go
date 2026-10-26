package github

import (
	"context"
	"errors"
	"slices"
	"strings"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// fakeClient is a host's client: its answers, and what it was asked.
type fakeClient struct {
	mu      sync.Mutex
	token   string
	inbox   githubapi.Inbox
	fail    error
	states  map[string]model.GitHubItem
	asked   []string
	blobs   map[githubapi.BlobAt]githubapi.Blob
	files   []githubapi.File
	written []string
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
func (f *fakeClient) Inbox(_ context.Context, repos []string) (githubapi.Inbox, error) {
	f.note("inbox " + strings.Join(repos, ","))
	return f.inbox, f.fail
}

func (f *fakeClient) Status(_ context.Context, ids []string) (map[string]model.GitHubItem, error) {
	f.note("status " + strings.Join(ids, ","))
	if f.fail != nil {
		return nil, f.fail
	}
	out := map[string]model.GitHubItem{}
	for _, id := range ids {
		if it, ok := f.states[id]; ok {
			out[id] = it
		}
	}
	return out, nil
}

func (f *fakeClient) Pull(context.Context, string, int) (model.GitHubPull, error) {
	return model.GitHubPull{}, nil
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

func (f *fakeClient) Reply(context.Context, string, string) (model.GitHubComment, error) {
	f.written = append(f.written, "reply")
	return model.GitHubComment{ID: "C1"}, nil
}

func (f *fakeClient) Resolve(context.Context, string, bool) error {
	f.written = append(f.written, "resolve")
	return nil
}

func (f *fakeClient) Comment(context.Context, string, string) (model.GitHubComment, error) {
	f.written = append(f.written, "comment")
	return model.GitHubComment{ID: "C2"}, nil
}

func (f *fakeClient) SubmitReview(context.Context, githubapi.Review) error {
	f.written = append(f.written, "review")
	return nil
}

type fakeTokens struct {
	m      map[string]string
	needOK bool
}

var errOK = errors.New("needs ok")

func (k *fakeTokens) Set(account, _ string, secret []byte) error {
	k.m[account] = string(secret)
	return nil
}

func (k *fakeTokens) Get(account string, prompt bool) ([]byte, error) {
	if k.needOK && !prompt {
		return nil, errOK
	}
	t, ok := k.m[account]
	if !ok {
		return nil, errors.New("not found")
	}
	return []byte(t), nil
}

func (k *fakeTokens) Delete(account string) error {
	delete(k.m, account)
	return nil
}

type fakeStore struct{ hosts []string }

func (s *fakeStore) GitHubTokenHosts() ([]string, error)   { return slices.Clone(s.hosts), nil }
func (s *fakeStore) SaveGitHubTokenHosts(h []string) error { s.hosts = h; return nil }

type world struct {
	s       *Service
	tokens  *fakeTokens
	store   *fakeStore
	clients map[string]*fakeClient // by token
}

func newWorld(t *testing.T) *world {
	t.Helper()
	w := &world{tokens: &fakeTokens{m: map[string]string{}}, store: &fakeStore{}, clients: map[string]*fakeClient{}}
	w.s = New(Deps{
		Gh: Gh{
			Token: func(host string) (string, string) {
				if host == "github.com" {
					return "gho_gh", "gh"
				}
				return "", ""
			},
			Hosts: func() []string { return []string{"github.com"} },
		},
		Tokens: w.tokens, Store: w.store,
		Open: func(_, token string) Client {
			c := w.clients[token]
			if c == nil {
				c = &fakeClient{token: token, states: map[string]model.GitHubItem{}, blobs: map[githubapi.BlobAt]githubapi.Blob{}}
				w.clients[token] = c
			}
			return c
		},
		NeedsOK: func(err error) bool { return errors.Is(err, errOK) },
		Remotes: func(_ context.Context, folder string) (map[string]string, error) {
			return map[string]string{"origin": "git@github.com:afrase/" + folder + ".git", "fork": "https://github.com/me/" + folder}, nil
		},
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
	if _, err := w.s.AddToken(ctx, "git.example.com", "bad"); !errors.Is(err, githubapi.ErrUnauthorized) || len(w.tokens.m) != 0 {
		t.Fatalf("a refused token was kept: %v", err)
	}
	if _, err := w.s.AddToken(ctx, "Not A Host", "ghp_x"); err == nil {
		t.Fatal("a bad host")
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
	if err := w.s.RemoveToken("github.com"); err != nil {
		t.Fatal(err)
	}
	if hosts, _ = w.s.Hosts(ctx); hosts[1].Source != "gh" || w.tokens.m["github.com"] != "" {
		t.Fatalf("back to gh's: %+v", hosts)
	}
	// A new build of Nushi: the keychain wants the user's OK.
	w2 := newWorld(t)
	w2.tokens.m["git.example.com"], w2.store.hosts, w2.tokens.needOK = "ghp_ent", []string{"git.example.com"}, true
	hosts, _ = w2.s.Hosts(ctx)
	if !hosts[0].NeedsOK {
		t.Fatalf("%+v", hosts)
	}
	if err := w2.s.AllowToken("git.example.com"); err != nil {
		t.Fatal(err)
	}
	if hosts, _ = w2.s.Hosts(ctx); hosts[0].NeedsOK || hosts[0].User.Login != "octo-ghp_ent" {
		t.Fatalf("%+v", hosts)
	}
}

func TestNoToken(t *testing.T) {
	w := newWorld(t)
	if _, err := w.s.Inbox(t.Context(), "git.example.com", nil, false); err == nil || !strings.Contains(err.Error(), "gh auth login") {
		t.Fatal(err)
	}
}

func TestInboxKeepsTheLastKnown(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	pr := model.GitHubItem{ID: "PR_1", Pull: true, Number: 1}
	if _, err := w.s.Inbox(ctx, "github.com", nil, false); err != nil {
		t.Fatal(err)
	}
	c := w.clients["gho_gh"]
	c.inbox = githubapi.Inbox{Mine: []model.GitHubItem{pr}}
	in, _ := w.s.Inbox(ctx, "github.com", nil, true)
	if len(in.Mine) != 0 || len(c.asked) != 1 {
		t.Fatalf("asked again within 20 s: %v", c.asked)
	}
	in, err := w.s.Inbox(ctx, "github.com", []string{"a/b"}, true) // another filter: asked
	if err != nil || len(in.Mine) != 1 {
		t.Fatalf("%+v %v", in, err)
	}
	w.s.inboxes["github.com a/b"] = inboxCache{at: in.At.Add(-inboxFresh), inbox: in.Inbox}
	c.fail = errors.New("GitHub's graphql rate limit is spent")
	in, err = w.s.Inbox(ctx, "github.com", []string{"a/b"}, true)
	if err != nil || in.Stale == nil || len(in.Mine) != 1 {
		t.Fatalf("the last inbox goes on a failure: %+v %v", in, err)
	}
	// The inbox told the chips: a state from it costs nothing.
	if st := w.s.States(ctx, []model.ChatGitHub{{Host: "github.com", ID: "PR_1"}}, true); st["PR_1"].Number != 1 {
		t.Fatalf("%+v", st)
	}
}

func TestStates(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	_, _ = w.s.Inbox(ctx, "github.com", nil, false)
	c := w.clients["gho_gh"]
	c.states["PR_1"] = model.GitHubItem{ID: "PR_1", State: "open"}
	items := []model.ChatGitHub{{Host: "github.com", ID: "PR_1"}, {Host: "github.com", ID: "I_gone"}}
	st := w.s.States(ctx, items, true)
	if st["PR_1"].State != "open" || len(st) != 1 {
		t.Fatalf("%+v", st)
	}
	w.s.States(ctx, items[:1], true)
	if n := len(slices.DeleteFunc(slices.Clone(c.asked), func(s string) bool { return !strings.HasPrefix(s, "status") })); n != 1 {
		t.Fatalf("asked again within 30 s: %v", c.asked)
	}
	// A write makes them old; GitHub failing then keeps the last known.
	if _, err := w.s.Comment(ctx, "github.com", "PR_1", "Thanks"); err != nil {
		t.Fatal(err)
	}
	c.fail = errors.New("down")
	if st := w.s.States(ctx, items[:1], true); st["PR_1"].State != "open" {
		t.Fatalf("%+v", st)
	}
	if _, err := w.s.Comment(ctx, "github.com", "PR_1", " "); err == nil {
		t.Fatal("an empty comment")
	}
}

func TestFiles(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	_, _ = w.s.Inbox(ctx, "github.com", nil, false)
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
		h, r, ok := ParseRemote(in)
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
}
