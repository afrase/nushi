package jira

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

var errLocked = errors.New("locked")

// fakeTokens is a keychain in memory; locked makes reads without a
// prompt fail as an earlier build's item does.
type fakeTokens struct {
	mu     sync.Mutex
	items  map[string]string
	locked bool
}

func (k *fakeTokens) Set(account, _ string, secret []byte) error {
	k.mu.Lock()
	defer k.mu.Unlock()
	k.items[account] = string(secret)
	return nil
}

func (k *fakeTokens) Get(account string, prompt bool) ([]byte, error) {
	k.mu.Lock()
	defer k.mu.Unlock()
	if k.locked && !prompt {
		return nil, errLocked
	}
	v, ok := k.items[account]
	if !ok {
		return nil, errors.New("not in the keychain")
	}
	return []byte(v), nil
}

func (k *fakeTokens) Delete(account string) error {
	k.mu.Lock()
	defer k.mu.Unlock()
	delete(k.items, account)
	return nil
}

type memStore struct{ sites []model.JiraSite }

func (m *memStore) JiraSites() ([]model.JiraSite, error) {
	return append([]model.JiraSite(nil), m.sites...), nil
}

func (m *memStore) SaveJiraSites(s []model.JiraSite) error {
	m.sites = append([]model.JiraSite(nil), s...)
	return nil
}

// fakeClient records what reaches "Jira".
type fakeClient struct {
	token   string
	jql     []string
	moves   []map[string]string
	comment string
}

func (f *fakeClient) Myself(context.Context) (model.JiraUser, error) {
	return model.JiraUser{Name: "Test User"}, nil
}

func (f *fakeClient) Search(_ context.Context, jql string, _ int) ([]model.JiraIssue, error) {
	f.jql = append(f.jql, jql)
	return []model.JiraIssue{{Key: "A-1"}}, nil
}

func (f *fakeClient) Boards(context.Context) ([]model.JiraBoard, error) {
	return []model.JiraBoard{{ID: 7, Name: "A board"}}, nil
}

func (f *fakeClient) ActiveSprint(_ context.Context, board int64) (int64, string, error) {
	if board != 7 {
		return 0, "", errors.New("no board")
	}
	return 3, "Sprint 3", nil
}

func (f *fakeClient) JQL(context.Context) (model.JiraJQL, error) { return model.JiraJQL{}, nil }

func (f *fakeClient) Suggestions(context.Context, string, string) ([]model.JiraOption, error) {
	return nil, nil
}

func (f *fakeClient) Issue(_ context.Context, key string) (model.JiraIssue, error) {
	return model.JiraIssue{Key: key}, nil
}

func (f *fakeClient) Transitions(context.Context, string) ([]model.JiraTransition, error) {
	return []model.JiraTransition{{ID: "41", Name: "Done", Fields: []model.JiraField{{ID: "resolution", Name: "Resolution", Required: true}}}}, nil
}

func (f *fakeClient) Transition(_ context.Context, _ string, _ model.JiraTransition, values map[string]string) error {
	f.moves = append(f.moves, values)
	return nil
}

func (f *fakeClient) AddComment(_ context.Context, _, markdown string) (model.JiraComment, error) {
	f.comment = markdown
	return model.JiraComment{ID: "1", Body: markdown}, nil
}

func (f *fakeClient) Attachment(context.Context, string, bool) ([]byte, string, error) {
	return []byte("x"), "image/png", nil
}

func newService(t *testing.T) (*Service, *fakeTokens, *[]*fakeClient) {
	t.Helper()
	tokens := &fakeTokens{items: map[string]string{}}
	var opened []*fakeClient
	sites := Sites{
		Connect: func(_ context.Context, site, _, token string) (Client, model.JiraSite, error) {
			if token != "good" {
				return nil, model.JiraSite{}, errors.New("refused")
			}
			c := &fakeClient{token: token}
			opened = append(opened, c)
			return c, model.JiraSite{URL: site, AccountID: "acc", Name: "Test User"}, nil
		},
		Open: func(_ model.JiraSite, token string) Client {
			c := &fakeClient{token: token}
			opened = append(opened, c)
			return c
		},
	}
	return New(sites, tokens, &memStore{}, func(err error) bool { return errors.Is(err, errLocked) }), tokens, &opened
}

func TestSites(t *testing.T) {
	s, tokens, opened := newService(t)
	if _, err := s.AddSite(t.Context(), "https://e.atlassian.net", "me@e.com", "bad", time.Time{}); err == nil {
		t.Fatal("a refused token was added")
	}
	expires := time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC)
	site, err := s.AddSite(t.Context(), "https://e.atlassian.net", " me@e.com ", " good ", expires)
	if err != nil {
		t.Fatal(err)
	}
	if SiteID(site) != "e.atlassian.net" || site.Email != "me@e.com" || !site.Expires.Equal(expires) {
		t.Errorf("site %+v", site)
	}
	if tokens.items["me@e.com on e.atlassian.net"] != "good" {
		t.Errorf("the keychain has %v", tokens.items)
	}
	if err := s.SetBoard("e.atlassian.net", model.JiraBoard{ID: 7, Name: "A board"}); err != nil {
		t.Fatal(err)
	}

	// A new build of Nushi: the keychain wants the user's OK.
	s2 := New(s.sites, tokens, s.store, s.needsOK)
	tokens.locked = true
	states, err := s2.Sites()
	if err != nil || len(states) != 1 || !states[0].NeedsOK || states[0].Board != 7 {
		t.Fatalf("%+v, %v", states, err)
	}
	if _, err := s2.List(t.Context(), "e.atlassian.net", Mine, ""); !errors.Is(err, ErrNeedsOK) {
		t.Errorf("a list without the OK: %v", err)
	}
	if err := s2.AllowToken("e.atlassian.net"); err != nil {
		t.Fatal(err)
	}
	if states, _ := s2.Sites(); states[0].Problem != "" {
		t.Errorf("after the OK: %+v", states[0])
	}
	if c := (*opened)[len(*opened)-1]; c.token != "good" {
		t.Errorf("opened with %q", c.token)
	}

	if err := s2.RemoveSite("e.atlassian.net"); err != nil {
		t.Fatal(err)
	}
	if len(tokens.items) != 0 {
		t.Errorf("the token stayed: %v", tokens.items)
	}
	if states, _ := s2.Sites(); len(states) != 0 {
		t.Errorf("still listed: %+v", states)
	}
}

func TestLists(t *testing.T) {
	s, _, opened := newService(t)
	if _, err := s.AddSite(t.Context(), "https://e.atlassian.net", "me@e.com", "good", time.Time{}); err != nil {
		t.Fatal(err)
	}
	c := (*opened)[0]
	if _, err := s.List(t.Context(), "e.atlassian.net", Sprint, ""); err == nil {
		t.Error("a sprint list without a board")
	}
	if err := s.SetBoard("e.atlassian.net", model.JiraBoard{ID: 7}); err != nil {
		t.Fatal(err)
	}
	l, err := s.List(t.Context(), "e.atlassian.net", Sprint, "")
	if err != nil || l.Sprint != "Sprint 3" || len(l.Issues) != 1 {
		t.Errorf("%+v, %v", l, err)
	}
	if _, err := s.List(t.Context(), "e.atlassian.net", Mine, ""); err != nil {
		t.Fatal(err)
	}
	if _, err := s.List(t.Context(), "e.atlassian.net", "", "project = A"); err != nil {
		t.Fatal(err)
	}
	want := []string{"sprint = 3 ORDER BY Rank ASC", mineJQL, "project = A"}
	if strings.Join(c.jql, "|") != strings.Join(want, "|") {
		t.Errorf("searched %q", c.jql)
	}
	if _, err := s.List(t.Context(), "nope", Mine, ""); err == nil {
		t.Error("a site never added")
	}
}

func TestWrites(t *testing.T) {
	s, _, opened := newService(t)
	if _, err := s.AddSite(t.Context(), "https://e.atlassian.net", "me@e.com", "good", time.Time{}); err != nil {
		t.Fatal(err)
	}
	c := (*opened)[0]
	if _, err := s.Transition(t.Context(), "e.atlassian.net", "A-1", "41", nil, "you"); err == nil || !strings.Contains(err.Error(), "Resolution") {
		t.Errorf("a required field missing: %v", err)
	}
	if _, err := s.Transition(t.Context(), "e.atlassian.net", "A-1", "99", nil, "you"); err == nil {
		t.Error("a move the issue doesn't have")
	}
	if _, err := s.Transition(t.Context(), "e.atlassian.net", "A-1", "41", map[string]string{"resolution": "1"}, "you"); err != nil || len(c.moves) != 1 {
		t.Errorf("%v, %v", err, c.moves)
	}
	if _, err := s.AddComment(t.Context(), "e.atlassian.net", "A-1", "  ", "you"); err == nil {
		t.Error("an empty comment")
	}
	if _, err := s.AddComment(t.Context(), "e.atlassian.net", "A-1", "hi", "you"); err != nil || c.comment != "hi" {
		t.Error(err)
	}
	for _, key := range []string{"a-1", "A-0", "A 1", "../x", "A-1/comment"} {
		if _, err := s.Issue(t.Context(), "e.atlassian.net", key); err == nil {
			t.Errorf("%q taken as a key", key)
		}
	}
	if _, _, err := s.Attachment(t.Context(), "e.atlassian.net", "../1", false); err == nil {
		t.Error("an attachment id that isn't one")
	}
}
