// Package github is GitHub in Nushi: the hosts it can reach (the gh
// login's token, or one pasted into Settings, in the keychain), the
// inbox, a pull request's or an issue's details, the chats' items' state,
// and the writes the user asks for. Nothing reaches GitHub on its own:
// every call here is a request from the app, polls marked as such so they
// leave the rate limits room (ADR 0045).
package github

import (
	"cmp"
	"context"
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
	Refused() bool
	Inbox(ctx context.Context, f githubapi.InboxFilter) (githubapi.Inbox, error)
	Status(ctx context.Context, ids []string) (map[string]model.GitHubItem, error)
	Items(ctx context.Context, refs []model.GitHubRef) ([]model.GitHubItem, []model.GitHubRef, error)
	Pull(ctx context.Context, repo string, number int) (model.GitHubPull, error)
	Commits(ctx context.Context, repo string, number int) (model.GitHubCommits, error)
	Issue(ctx context.Context, repo string, number int) (model.GitHubIssue, error)
	PullsByHead(ctx context.Context, repo, head string) ([]githubapi.HeadPull, time.Duration, error)
	JobLog(ctx context.Context, repo string, job int64) (string, error)
	RerunFailed(ctx context.Context, repo string, jobs []int64) ([]int64, error)
	BranchHead(ctx context.Context, repo, branch string) (string, error)
	DeleteBranch(ctx context.Context, repo, branch string) error
	CreateBranch(ctx context.Context, repo, branch, sha string) error
	DefaultBranch(ctx context.Context, repo string) (string, error)
	Compare(ctx context.Context, repo, base, head string) (string, []githubapi.File, error)
	Blobs(ctx context.Context, repo string, at []githubapi.BlobAt) (map[githubapi.BlobAt]githubapi.Blob, error)
	Reply(ctx context.Context, thread, body string) error
	Resolve(ctx context.Context, thread string, resolve bool) error
	Viewed(ctx context.Context, repo string, number int) (viewed, changed []string, err error)
	SetViewed(ctx context.Context, pull, path string, viewed bool) error
	React(ctx context.Context, subject, kind string, on bool) error
	Comment(ctx context.Context, subject, body string) error
	EditPull(ctx context.Context, pull string, title, body *string) error
	SubmitReview(ctx context.Context, r githubapi.Review) error
	MergeText(ctx context.Context, repo string, number int) (githubapi.MergeText, error)
	Merge(ctx context.Context, m githubapi.MergeInput) error
	EnableAutoMerge(ctx context.Context, m githubapi.MergeInput) error
	DisableAutoMerge(ctx context.Context, pull string) error
	Enqueue(ctx context.Context, pull, head string) error
	Dequeue(ctx context.Context, pull string) error
}

// Gh is the gh CLI's login: a host's token and where it came from (""
// when gh has none; an error when the read was cut short, so gh didn't
// say, or when a token only gh reads can't be had), and the hosts gh
// knows, read afresh each call so a `gh auth login` since shows.
type Gh struct {
	Token func(ctx context.Context, host string) (token, source string, err error)
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
	Cached(area, name, key string, v any) (time.Time, error)
	Cache(area, name, key string, v any) error
	ForgetCache(area, name string) error
}

// ErrNeedsOK is a pasted token the keychain gives only once the user
// allows it (a new build of Nushi on the Mac, a locked keyring on Linux):
// AllowToken asks.
var ErrNeedsOK = errors.New("Nushi needs your OK to read the GitHub token: Settings › GitHub › Allow")

// Keys says what a keychain error means (internal/keychain's kinds): the
// user's OK is needed (AllowToken asks), the daemon must start again to
// reach the keychain (its error says so), or the token is gone. Word is
// what the user knows the keychain as (keychain.Word: "keyring" on Linux),
// for the errors the user reads.
type Keys struct {
	NeedsOK, Restart, Missing func(error) bool
	Word                      string
}

// word is k.Word, "keychain" when none was given.
func (k Keys) word() string { return cmp.Or(k.Word, "keychain") }

// Deps are what the feature takes from main: gh's login, the keychain,
// the store, a client of a host for a token, what a keychain error
// means, a folder's git remotes (name to URL),
// fetching a refspec from one, whether git takes a branch's name, a
// folder's branch and the remote it's pushed to, and its repository's
// default branch.
type Deps struct {
	Gh            Gh
	Tokens        Tokens
	Store         Store
	Open          func(host, token string) Client
	Keys          Keys
	Remotes       func(ctx context.Context, folder string) (map[string]string, error)
	Fetch         func(ctx context.Context, folder, remote, refspec string) error
	CheckBranch   func(name string) error
	Head          func(ctx context.Context, folder string) (branch, remote string)
	DefaultBranch func(ctx context.Context, folder string) string
}

// Service is GitHub's feature.
type Service struct {
	Deps

	mu       sync.Mutex
	clients  map[string]*host     // by host, once its token was read
	noToken  map[string]time.Time // by host: when gh last had no token for it
	inboxes  map[string]inboxCache
	states   map[string]stateCache // by node id
	items    map[string]itemCache  // by refKey (refitems.go)
	logs     map[string]string     // finished jobs' log tails, by host, repository and job
	blobs    *blobCache
	repos    map[string]repoCache  // by folder
	branches map[string]headsCache // by host, repository and head
}

// host is a host's client and what Nushi learned of its token.
type host struct {
	c      Client
	source string // "gh" (its login) or "token" (pasted)
	kind   string // githubapi.TokenKind
	user   githubapi.User
	asked  time.Time // when user was asked for
	err    error     // the last time the token was refused
	opened time.Time // when the client was made
}

// drop forgets a host's client h and what its token was shown, only while
// h is still the one kept: a token added or read again meanwhile stays.
func (s *Service) drop(name string, h *host) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.clients[name] == h {
		delete(s.clients, name)
		s.forget(name)
	}
}

// New makes the service.
func New(d Deps) *Service {
	return &Service{Deps: d, clients: map[string]*host{}, noToken: map[string]time.Time{}, inboxes: map[string]inboxCache{},
		states: map[string]stateCache{}, items: map[string]itemCache{}, logs: map[string]string{}, blobs: newBlobCache(), repos: map[string]repoCache{}, branches: map[string]headsCache{}}
}

// HostState is a host as Settings › GitHub shows it.
type HostState struct {
	Host   string
	Source string // where its token is from: "gh" (its login) or "token" (pasted)
	Kind   string // the token's kind ("oauth" for gh's, "classic", "fine-grained")
	User   githubapi.User
	Budget []githubapi.Bucket
	// Problem says why Nushi can't use the host now; NeedsOK that the
	// keychain wants the user's OK for its pasted token, Restart that the
	// daemon can't reach the keychain until it starts again.
	Problem          string
	NeedsOK, Restart bool
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
		s.mu.Lock()
		kept := s.clients[name]
		s.mu.Unlock()
		if kept != nil && kept.c.Refused() {
			s.drop(name, kept) // the user is looking: read the token again now, not after noTokenFor
		}
		h, err := s.host(ctx, name, false)
		if err == nil {
			err = s.check(ctx, h)
		}
		if err != nil {
			st.Problem, st.NeedsOK, st.Restart = err.Error(), errors.Is(err, ErrNeedsOK), s.Keys.Restart(err)
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
func (s *Service) check(ctx context.Context, h *host) error {
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
	} // a refused token is read again by host (Client.Refused)
	return err
}

// hostRE is a host name, with a port maybe: no user, no path.
var hostRE = regexp.MustCompile(`^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?(:\d{1,5})?$`)

// normalHost is a host's name as Nushi keys it: lowercase, without a
// trailing dot or the default port; false for what isn't a host's name
// (a user, a path, spaces).
func normalHost(name string) (string, bool) {
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
// picked: gh's GH_ENTERPRISE_TOKEN would be given for any. A host gh
// doesn't know has gh's config read again first, for a login since.
func (s *Service) known(name string) (string, []string, error) {
	h, ok := normalHost(name)
	if !ok {
		return "", nil, unknownHostError(fmt.Sprintf("%q isn't a host's name", name))
	}
	pasted, err := s.Store.GitHubTokenHosts()
	if err != nil {
		return "", nil, err
	}
	if h != "github.com" && !slices.Contains(pasted, h) && !slices.Contains(s.Gh.Hosts(), h) {
		return "", nil, unknownHostError(h + " isn't a host gh is signed in to or one given a token in Settings › GitHub")
	}
	return h, pasted, nil
}

// unknownHostError is known's error for a name that isn't a GitHub host Nushi
// knows (gh's, or one given a token), not a failure to ask.
type unknownHostError string

func (e unknownHostError) Error() string { return string(e) }

// AddToken checks a pasted token on a host and keeps it in the keychain.
// It's used for the host instead of gh's login, until removed.
func (s *Service) AddToken(ctx context.Context, given, token string) (githubapi.User, error) {
	name, ok := normalHost(given)
	if !ok {
		return githubapi.User{}, fmt.Errorf("%q isn't a host's name, such as github.com", given)
	}
	if token == "" {
		return githubapi.User{}, errors.New("a token is needed")
	}
	c := s.Open(name, token)
	u, err := c.Viewer(ctx)
	if err != nil {
		return u, err
	}
	if err := s.Tokens.Set(name, tokenLabel(name), []byte(token)); err != nil {
		return u, fmt.Errorf("keeping the token in the %s: %w", s.Keys.word(), err)
	}
	hosts, err := s.Store.GitHubTokenHosts()
	if err == nil && !slices.Contains(hosts, name) {
		err = s.Store.SaveGitHubTokenHosts(append(hosts, name))
	}
	if err != nil {
		return u, err
	}
	s.mu.Lock()
	s.clients[name] = &host{c: c, source: "token", kind: githubapi.TokenKind(token), user: u, asked: time.Now(), opened: time.Now()}
	s.forget(name)
	s.mu.Unlock()
	slog.Info("github token added", "host", name, "kind", githubapi.TokenKind(token))
	return u, nil
}

// RemoveToken deletes a host's pasted token: the host goes back to gh's
// login, if gh has one. The host forgets the token first, then the
// keychain deletes it as best it can: a keychain that can't (no keyring,
// a dismissed prompt) never leaves a host that can't be removed; the
// token then stays in it, logged, never read again, and kept names its
// item (its label) so the user can delete it there.
func (s *Service) RemoveToken(name string) (kept string, err error) {
	name, ok := normalHost(name)
	if !ok {
		return "", errors.New("not a host's name")
	}
	hosts, err := s.Store.GitHubTokenHosts()
	if err != nil {
		return "", err
	}
	if err := s.Store.SaveGitHubTokenHosts(slices.DeleteFunc(hosts, func(h string) bool { return h == name })); err != nil {
		return "", err
	}
	s.mu.Lock()
	delete(s.clients, name)
	s.forget(name)
	s.mu.Unlock()
	slog.Info("github token removed", "host", name)
	if err := s.Tokens.Delete(name); err != nil && !s.Keys.Missing(err) {
		slog.Warn("github token left in the keychain", "host", name, "err", err)
		return tokenLabel(name), nil
	}
	return "", nil
}

// tokenLabel is a host's pasted token's name in the keychain: what
// Keychain Access, or the keyring's app on Linux, lists it as.
func tokenLabel(host string) string { return "Nushi: GitHub token for " + host }

// AllowToken reads a host's pasted token with macOS's prompt, which asks
// the user to let this build of Nushi read it.
func (s *Service) AllowToken(ctx context.Context, name string) error {
	_, err := s.host(ctx, name, true)
	return err
}

// noTokenFor is how long gh having no token for a host is believed: a
// host asked for again and again (a chat's pull request, polled) has gh
// asked (`gh auth token`, maybe) at most this often.
const noTokenFor = 30 * time.Second

// host is a host's client: its pasted token's (read from the keychain the
// first time, with macOS's prompt only when asked), else gh's login's.
// The token stays in the client only. Two asking at once may both read
// the token; both get the client kept first. A client GitHub refused the
// token of is dropped and the token read again (gh may have a new one),
// at most every noTokenFor, so a revoked token starts gh no more often.
func (s *Service) host(ctx context.Context, name string, prompt bool) (*host, error) {
	name, pasted, err := s.known(name)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	h, missed := s.clients[name], s.noToken[name]
	s.mu.Unlock()
	if h != nil && h.c.Refused() && time.Since(h.opened) >= noTokenFor {
		s.drop(name, h)
		h = nil
	}
	if h != nil {
		return h, nil
	}
	noToken := fmt.Errorf("no token for %s: sign in with gh auth login, or add one in Settings › GitHub", name)
	var token []byte
	source := "token"
	if slices.Contains(pasted, name) {
		token, err = s.Tokens.Get(name, prompt)
		switch {
		case err == nil:
		case s.Keys.NeedsOK(err):
			return nil, ErrNeedsOK
		case s.Keys.Restart(err):
			return nil, err // says what to do
		case s.Keys.Missing(err):
			return nil, fmt.Errorf("the GitHub token for %s isn't in the %s any more: add it again in Settings › GitHub", name, s.Keys.word())
		default:
			return nil, fmt.Errorf("reading the GitHub token from the %s: %w", s.Keys.word(), err)
		}
	} else {
		if time.Since(missed) < noTokenFor {
			return nil, noToken
		}
		var t string
		t, source, err = s.Gh.Token(ctx, name)
		if err != nil {
			return nil, err // not a miss: gh is asked again next time
		}
		if t == "" {
			s.mu.Lock()
			s.noToken[name] = time.Now()
			s.mu.Unlock()
			return nil, noToken
		}
		token = []byte(t)
	}
	h = &host{c: s.Open(name, string(token)), source: source, kind: githubapi.TokenKind(string(token)), opened: time.Now()}
	clear(token)
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.noToken, name)
	if kept := s.clients[name]; kept != nil {
		return kept, nil
	}
	s.clients[name] = h
	return h, nil
}

// client is a host's client.
func (s *Service) client(ctx context.Context, name string) (Client, error) {
	h, err := s.host(ctx, name, false)
	if err != nil {
		return nil, err
	}
	return h.c, nil
}
