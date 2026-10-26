// Package github is GitHub in Nushi: the hosts it can reach (the gh
// login's token, or one pasted into Settings, in the keychain), the
// inbox, a pull request's or an issue's details, the chats' items' state,
// and the writes the user asks for. Nothing reaches GitHub on its own:
// every call here is a request from the app, polls marked as such so they
// leave the rate limits room (ADR 0045).
package github

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"regexp"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// Client is a host as the feature uses it (internal/githubapi's).
type Client interface { //nolint:interfacebloat // the GitHub calls the feature makes
	Viewer(ctx context.Context) (githubapi.User, error)
	RateLimits(ctx context.Context) ([]githubapi.Bucket, error)
	Budget() []githubapi.Bucket
	Inbox(ctx context.Context, f githubapi.InboxFilter) (githubapi.Inbox, error)
	Status(ctx context.Context, ids []string) (map[string]model.GitHubItem, error)
	Pull(ctx context.Context, repo string, number int) (model.GitHubPull, error)
	Issue(ctx context.Context, repo string, number int) (model.GitHubIssue, error)
	JobLog(ctx context.Context, repo string, job int64) (string, error)
	Compare(ctx context.Context, repo, base, head string) (string, []githubapi.File, error)
	Blobs(ctx context.Context, repo string, at []githubapi.BlobAt) (map[githubapi.BlobAt]githubapi.Blob, error)
	Reply(ctx context.Context, thread, body string) (model.GitHubComment, error)
	Resolve(ctx context.Context, thread string, resolve bool) error
	Comment(ctx context.Context, subject, body string) (model.GitHubComment, error)
	SubmitReview(ctx context.Context, r githubapi.Review) error
}

// Gh is the gh CLI's login, read in this process through go-gh: a host's
// token and where it came from ("" when gh has none), and the hosts gh
// knows.
type Gh struct {
	Token func(host string) (token, source string)
	Hosts func() []string
}

// Tokens keeps pasted tokens (internal/keychain), by host. A read without
// prompt never shows macOS's dialog.
type Tokens interface {
	Set(account, label string, secret []byte) error
	Get(account string, prompt bool) ([]byte, error)
	Delete(account string) error
}

// Store keeps the hosts given a token, and each host's inbox as it was
// last (the cache: area "github", a file a host).
type Store interface {
	GitHubTokenHosts() ([]string, error)
	SaveGitHubTokenHosts([]string) error
	Cached(area, name, key string) (time.Time, json.RawMessage, error)
	Cache(area, name, key string, at time.Time, data json.RawMessage) error
	ForgetCache(area, name string) error
}

// ErrNeedsOK is a pasted token the keychain gives only once the user
// allows it (a new build of Nushi): AllowToken asks.
var ErrNeedsOK = errors.New("this build of Nushi needs your OK to read the GitHub token from the keychain: Settings › GitHub › Allow")

// Deps are what the feature takes from main: gh's login, the keychain,
// the store, a client of a host for a token, whether a keychain error
// means the user's OK is needed, a folder's git remotes (name to URL),
// fetching a refspec from one, and whether git takes a branch's name.
type Deps struct {
	Gh          Gh
	Tokens      Tokens
	Store       Store
	Open        func(host, token string) Client
	NeedsOK     func(error) bool
	Remotes     func(ctx context.Context, folder string) (map[string]string, error)
	Fetch       func(ctx context.Context, folder, remote, refspec string) error
	CheckBranch func(name string) error
}

// Service is GitHub's feature.
type Service struct {
	Deps

	mu      sync.Mutex
	clients map[string]*host // by host, once its token was read
	inboxes map[string]inboxCache
	states  map[string]stateCache // by node id
	logs    map[int64]string      // finished jobs' log tails
	blobs   *blobCache
	repos   map[string]repoCache // by folder
}

// host is a host's client and what Nushi learned of its token.
type host struct {
	c      Client
	source string // "gh", "GH_TOKEN", "token" (pasted)…
	kind   string // githubapi.TokenKind
	user   githubapi.User
	asked  time.Time // when user was asked for
	err    error     // the last time the token was refused
}

// New makes the service.
func New(d Deps) *Service {
	return &Service{Deps: d, clients: map[string]*host{}, inboxes: map[string]inboxCache{}, states: map[string]stateCache{},
		logs: map[int64]string{}, blobs: newBlobCache(), repos: map[string]repoCache{}}
}

// HostState is a host as Settings › GitHub shows it.
type HostState struct {
	Host   string
	Source string // where its token is from: "gh" (its login), "GH_TOKEN", "token" (pasted)
	Kind   string // the token's kind ("oauth" for gh's, "classic", "fine-grained")
	User   githubapi.User
	Budget []githubapi.Bucket
	// Problem says why Nushi can't use the host now; NeedsOK that the
	// keychain wants the user's OK for its pasted token.
	Problem string
	NeedsOK bool
	// Pasted says a pasted token is kept for it (Remove deletes it).
	Pasted bool
}

// Hosts are the hosts gh is signed in to and those given a token, each
// with who its token is and what's left of its rate limits (asked of
// GitHub, which doesn't count against them).
func (s *Service) Hosts(ctx context.Context) ([]HostState, error) {
	pasted, err := s.Store.GitHubTokenHosts()
	if err != nil {
		return nil, err
	}
	names := slices.Clone(pasted)
	for _, h := range s.Gh.Hosts() {
		if !slices.Contains(names, h) {
			names = append(names, h)
		}
	}
	slices.Sort(names)
	out := make([]HostState, 0, len(names))
	for _, name := range names {
		st := HostState{Host: name, Pasted: slices.Contains(pasted, name)}
		h, err := s.host(name, false)
		if err == nil {
			err = s.check(ctx, name, h)
		}
		if err != nil {
			st.Problem, st.NeedsOK = err.Error(), errors.Is(err, ErrNeedsOK)
		}
		if h != nil {
			s.mu.Lock()
			st.Source, st.Kind, st.User = h.source, h.kind, h.user
			s.mu.Unlock()
			if b, err := h.c.RateLimits(ctx); err == nil {
				st.Budget = b
			} else {
				st.Budget = h.c.Budget()
			}
		}
		out = append(out, st)
	}
	return out, nil
}

// check asks who a host's token is, at most every ten minutes.
func (s *Service) check(ctx context.Context, name string, h *host) error {
	s.mu.Lock()
	fresh := time.Since(h.asked) < 10*time.Minute
	s.mu.Unlock()
	if fresh {
		return h.err
	}
	u, err := h.c.Viewer(ctx)
	s.mu.Lock()
	defer s.mu.Unlock()
	h.asked, h.err = time.Now(), err
	if err == nil {
		h.user = u
	} else if errors.Is(err, githubapi.ErrUnauthorized) {
		delete(s.clients, name) // read the token again next time: gh may have a new one
	}
	return err
}

// hostRE is a host name, with a port maybe: no user, no path.
var hostRE = regexp.MustCompile(`^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?(:\d{1,5})?$`)

// NormalHost is a host's name as Nushi keys it: lowercase, without a
// trailing dot or the default port; false for what isn't a host's name
// (a user, a path, spaces).
func NormalHost(name string) (string, bool) {
	h := strings.TrimSuffix(strings.ToLower(strings.TrimSpace(name)), ":443")
	h = strings.TrimSuffix(h, ".")
	if !hostRE.MatchString(h) || strings.Contains(h, "..") {
		return "", false
	}
	return h, true
}

// known checks a host may be given a token: github.com, a host gh is
// signed in to (its own hosts), or one given a pasted token in Settings.
// Any other (a host named by a link in someone's text, say) is refused
// before a token is read, so no token ever goes to a server someone else
// picked: gh's GH_ENTERPRISE_TOKEN would be given for any.
func (s *Service) known(name string) (string, []string, error) {
	h, ok := NormalHost(name)
	if !ok {
		return "", nil, fmt.Errorf("%q isn't a host's name", name)
	}
	pasted, err := s.Store.GitHubTokenHosts()
	if err != nil {
		return "", nil, err
	}
	if h != "github.com" && !slices.Contains(pasted, h) && !slices.Contains(s.Gh.Hosts(), h) {
		return "", nil, fmt.Errorf("%s isn't a host gh is signed in to or one given a token in Settings › GitHub", h)
	}
	return h, pasted, nil
}

// AddToken checks a pasted token on a host and keeps it in the keychain.
// It's used for the host instead of gh's login, until removed.
func (s *Service) AddToken(ctx context.Context, name, token string) (githubapi.User, error) {
	name, ok := NormalHost(name)
	if !ok {
		return githubapi.User{}, fmt.Errorf("%q isn't a host's name, such as github.com", name)
	}
	if token == "" {
		return githubapi.User{}, errors.New("a token is needed")
	}
	c := s.Open(name, token)
	u, err := c.Viewer(ctx)
	if err != nil {
		return u, err
	}
	if err := s.Tokens.Set(name, "Nushi: GitHub token for "+name, []byte(token)); err != nil {
		return u, fmt.Errorf("keeping the token in the keychain: %w", err)
	}
	hosts, err := s.Store.GitHubTokenHosts()
	if err == nil && !slices.Contains(hosts, name) {
		err = s.Store.SaveGitHubTokenHosts(append(hosts, name))
	}
	if err != nil {
		return u, err
	}
	s.mu.Lock()
	s.clients[name] = &host{c: c, source: "token", kind: githubapi.TokenKind(token), user: u, asked: time.Now()}
	s.mu.Unlock()
	s.forget(name) // another account's inbox
	slog.Info("github token added", "host", name, "kind", githubapi.TokenKind(token))
	return u, nil
}

// RemoveToken deletes a host's pasted token: the host goes back to gh's
// login, if gh has one.
func (s *Service) RemoveToken(name string) error {
	name, ok := NormalHost(name)
	if !ok {
		return errors.New("not a host's name")
	}
	if err := s.Tokens.Delete(name); err != nil {
		return fmt.Errorf("deleting the token from the keychain: %w", err)
	}
	hosts, err := s.Store.GitHubTokenHosts()
	if err != nil {
		return err
	}
	s.mu.Lock()
	delete(s.clients, name)
	s.mu.Unlock()
	s.forget(name)
	slog.Info("github token removed", "host", name)
	return s.Store.SaveGitHubTokenHosts(slices.DeleteFunc(hosts, func(h string) bool { return h == name }))
}

// AllowToken reads a host's pasted token with macOS's prompt, which asks
// the user to let this build of Nushi read it.
func (s *Service) AllowToken(name string) error {
	_, err := s.host(name, true)
	return err
}

// host is a host's client: its pasted token's (read from the keychain the
// first time, with macOS's prompt only when asked), else gh's login's.
// The token stays in the client only.
func (s *Service) host(name string, prompt bool) (*host, error) {
	name, pasted, err := s.known(name)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	h := s.clients[name]
	s.mu.Unlock()
	if h != nil {
		return h, nil
	}
	var token []byte
	source := "token"
	if slices.Contains(pasted, name) {
		token, err = s.Tokens.Get(name, prompt)
		switch {
		case err != nil && s.NeedsOK(err):
			return nil, ErrNeedsOK
		case err != nil:
			return nil, fmt.Errorf("reading the token from the keychain: %w", err)
		}
	} else {
		var t string
		t, source = s.Gh.Token(name)
		if t == "" {
			return nil, fmt.Errorf("no token for %s: sign in with gh auth login, or add one in Settings › GitHub", name)
		}
		token = []byte(t)
	}
	h = &host{c: s.Open(name, string(token)), source: source, kind: githubapi.TokenKind(string(token))}
	clear(token)
	s.mu.Lock()
	s.clients[name] = h
	s.mu.Unlock()
	return h, nil
}

// client is a host's client.
func (s *Service) client(name string) (Client, error) {
	h, err := s.host(name, false)
	if err != nil {
		return nil, err
	}
	return h.c, nil
}
