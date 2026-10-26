package jira

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// The lists a site has besides its saved searches.
const (
	Mine   = "mine"   // my open issues
	Sprint = "sprint" // the picked board's active sprint
)

// mineJQL is "my open issues".
const mineJQL = "assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC"

// listLimit is how many issues a list shows.
const listLimit = 200

// List is what a list holds now: its issues, and for the sprint list the
// sprint's name ("" when the board has no active sprint).
type List struct {
	Issues []model.JiraIssue
	Sprint string
}

// List runs one of a site's lists: Mine, Sprint, or else jql itself (a
// saved search's or one being typed).
func (s *Service) List(ctx context.Context, id, list, jql string) (List, error) {
	c, site, err := s.clientOf(id)
	if err != nil {
		return List{}, err
	}
	key := listKey(site, list, jql)
	var out List
	switch list {
	case Mine:
		jql = mineJQL
	case Sprint:
		if site.Board == 0 {
			return List{}, errors.New("pick the board whose sprint to show")
		}
		out, err = s.sprint(ctx, c, id, site.Board)
	}
	if list != Sprint {
		if strings.TrimSpace(jql) == "" {
			return List{}, errors.New("an empty search")
		}
		out.Issues, err = c.Search(ctx, jql, listLimit)
	}
	if err == nil {
		s.keep(id, key, out)
	}
	return out, err
}

// sprint lists a board's active sprint. The sprint found last time is
// searched while Jira is asked which is active, and again only if that
// changed: the two calls go together.
func (s *Service) sprint(ctx context.Context, c Client, id string, board int64) (List, error) {
	key := id + " " + strconv.FormatInt(board, 10)
	s.mu.Lock()
	known, ok := s.sprints[key]
	s.mu.Unlock()
	search := func(sprint sprintRef) (List, error) {
		issues, err := c.Search(ctx, "sprint = "+strconv.FormatInt(sprint.id, 10)+" ORDER BY Rank ASC", listLimit)
		return List{Issues: issues, Sprint: sprint.name}, err
	}
	var guess List
	var guessErr error
	done := make(chan struct{})
	if ok {
		go func() {
			defer close(done)
			guess, guessErr = search(known)
		}()
	} else {
		close(done)
	}
	active, name, err := c.ActiveSprint(ctx, board)
	<-done
	if err != nil || active == 0 {
		return List{}, err
	}
	now := sprintRef{active, name}
	s.mu.Lock()
	s.sprints[key] = now
	s.mu.Unlock()
	if ok && known.id == active {
		guess.Sprint = name
		return guess, guessErr
	}
	return search(now)
}

type sprintRef struct {
	id   int64
	name string
}

// Check asks Jira who a site's token is, to see it still works.
func (s *Service) Check(ctx context.Context, id string) (model.JiraUser, error) {
	c, _, err := s.clientOf(id)
	if err != nil {
		return model.JiraUser{}, err
	}
	return c.Myself(ctx)
}

// Boards are the boards to pick the sprint list's from.
func (s *Service) Boards(ctx context.Context, id string) ([]model.JiraBoard, error) {
	c, _, err := s.clientOf(id)
	if err != nil {
		return nil, err
	}
	return c.Boards(ctx)
}

// JQL is what a site's JQL autocompletes from, asked once an hour.
func (s *Service) JQL(ctx context.Context, id string) (model.JiraJQL, error) {
	s.mu.Lock()
	cached, ok := s.jql[id]
	s.mu.Unlock()
	if ok && time.Since(cached.at) < time.Hour {
		return cached.jql, nil
	}
	c, _, err := s.clientOf(id)
	if err != nil {
		return model.JiraJQL{}, err
	}
	jql, err := c.JQL(ctx)
	if err != nil {
		return jql, err
	}
	s.mu.Lock()
	s.jql[id] = jqlCache{at: time.Now(), jql: jql}
	s.mu.Unlock()
	return jql, nil
}

// Suggestions are values of a JQL field starting with prefix.
func (s *Service) Suggestions(ctx context.Context, id, field, prefix string) ([]model.JiraOption, error) {
	c, _, err := s.clientOf(id)
	if err != nil {
		return nil, err
	}
	return c.Suggestions(ctx, field, prefix)
}

var keyRE = regexp.MustCompile(`^[A-Z][A-Z0-9_]*-[1-9]\d*$`)

// CheckKey refuses what isn't an issue key ("ABC-123").
func CheckKey(key string) error {
	if !keyRE.MatchString(key) {
		return fmt.Errorf("%q isn't an issue key", key)
	}
	return nil
}

// Issue is an issue whole.
func (s *Service) Issue(ctx context.Context, id, key string) (model.JiraIssue, error) {
	c, err := s.issueClient(id, key)
	if err != nil {
		return model.JiraIssue{}, err
	}
	is, err := c.Issue(ctx, key)
	if err == nil {
		s.keep(id, issueKey(key), is)
	}
	return is, err
}

// Transitions are the moves an issue allows now.
func (s *Service) Transitions(ctx context.Context, id, key string) ([]model.JiraTransition, error) {
	c, err := s.issueClient(id, key)
	if err != nil {
		return nil, err
	}
	return c.Transitions(ctx, key)
}

// Transition moves an issue through the transition with tid, with values
// for its screen's fields; by says who asked ("you", or a chat's agent),
// for the log.
func (s *Service) Transition(ctx context.Context, id, key, tid string, values map[string]string, by string) (model.JiraTransition, error) {
	c, err := s.issueClient(id, key)
	if err != nil {
		return model.JiraTransition{}, err
	}
	ts, err := c.Transitions(ctx, key)
	if err != nil {
		return model.JiraTransition{}, err
	}
	for _, t := range ts {
		if t.ID != tid {
			continue
		}
		for _, f := range t.Fields {
			if f.Required && strings.TrimSpace(values[f.ID]) == "" {
				return t, fmt.Errorf("%s needs %s", t.Name, f.Name)
			}
		}
		if err := c.Transition(ctx, key, t, values); err != nil {
			return t, err
		}
		slog.Info("jira issue moved", "site", id, "key", key, "by", by)
		return t, nil
	}
	return model.JiraTransition{}, fmt.Errorf("%s can't make that move now", key)
}

// AddComment posts markdown as a comment; by as for Transition.
func (s *Service) AddComment(ctx context.Context, id, key, markdown, by string) (model.JiraComment, error) {
	if strings.TrimSpace(markdown) == "" {
		return model.JiraComment{}, errors.New("an empty comment")
	}
	c, err := s.issueClient(id, key)
	if err != nil {
		return model.JiraComment{}, err
	}
	cm, err := c.AddComment(ctx, key, markdown)
	if err == nil {
		slog.Info("jira comment added", "site", id, "key", key, "by", by)
	}
	return cm, err
}

// Attachment is an attachment's file or thumbnail, and its type.
func (s *Service) Attachment(ctx context.Context, id, attachment string, thumbnail bool) ([]byte, string, error) {
	if _, err := strconv.ParseUint(attachment, 10, 64); err != nil {
		return nil, "", fmt.Errorf("%q isn't an attachment's id", attachment)
	}
	c, _, err := s.clientOf(id)
	if err != nil {
		return nil, "", err
	}
	return c.Attachment(ctx, attachment, thumbnail)
}

func (s *Service) issueClient(id, key string) (Client, error) {
	if err := CheckKey(key); err != nil {
		return nil, err
	}
	c, _, err := s.clientOf(id)
	return c, err
}
