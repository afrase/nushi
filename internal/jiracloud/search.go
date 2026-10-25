package jiracloud

import (
	"context"
	"fmt"
	"html"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Myself is who the token belongs to.
func (c *Client) Myself(ctx context.Context) (model.JiraUser, error) {
	var u rawUser
	err := c.do(ctx, http.MethodGet, "/rest/api/3/myself", nil, nil, nil, &u)
	return model.JiraUser{AccountID: u.AccountID, Name: u.DisplayName, Email: u.EmailAddress}, err
}

// listFields are what a list of issues shows.
var listFields = []string{"summary", "status", "issuetype", "priority", "assignee", "updated"}

// Search returns up to limit issues jql finds (a bounded query: Jira
// refuses one without a restriction), following nextPageToken.
func (c *Client) Search(ctx context.Context, jql string, limit int) ([]model.JiraIssue, error) {
	var out []model.JiraIssue
	seen := map[string]bool{}
	token := ""
	for len(out) < limit {
		req := map[string]any{"jql": jql, "fields": listFields, "maxResults": min(limit-len(out), 100)}
		if token != "" {
			req["nextPageToken"] = token
		}
		var page struct {
			Issues        []rawIssue `json:"issues"`
			NextPageToken string     `json:"nextPageToken"`
		}
		if err := c.do(ctx, http.MethodPost, "/rest/api/3/search/jql", nil, nil, req, &page); err != nil {
			return nil, err
		}
		for _, r := range page.Issues {
			out = append(out, r.listed())
		}
		// No token is the last page; a token seen before would go round
		// for ever (a bug people have hit).
		if page.NextPageToken == "" || seen[page.NextPageToken] || len(page.Issues) == 0 {
			break
		}
		seen[page.NextPageToken] = true
		token = page.NextPageToken
	}
	return out[:min(len(out), limit)], nil
}

// Boards lists the boards the user can see (500 at most).
func (c *Client) Boards(ctx context.Context) ([]model.JiraBoard, error) {
	var out []model.JiraBoard
	for start := 0; start < 500; {
		var page struct {
			IsLast bool `json:"isLast"`
			Values []struct {
				ID       int64  `json:"id"`
				Name     string `json:"name"`
				Location struct {
					ProjectKey string `json:"projectKey"`
				} `json:"location"`
			} `json:"values"`
		}
		q := url.Values{"startAt": {strconv.Itoa(start)}, "maxResults": {"50"}}
		if err := c.do(ctx, http.MethodGet, "/rest/agile/1.0/board", nil, q, nil, &page); err != nil {
			return nil, err
		}
		for _, b := range page.Values {
			out = append(out, model.JiraBoard{ID: b.ID, Name: b.Name, Project: b.Location.ProjectKey})
		}
		if page.IsLast || len(page.Values) == 0 {
			break
		}
		start += len(page.Values)
	}
	return out, nil
}

// ActiveSprint is a board's active sprint (its id and name); 0 when none
// is active.
func (c *Client) ActiveSprint(ctx context.Context, board int64) (int64, string, error) {
	var page struct {
		Values []struct {
			ID   int64  `json:"id"`
			Name string `json:"name"`
		} `json:"values"`
	}
	q := url.Values{"state": {"active"}}
	if err := c.do(ctx, http.MethodGet, "/rest/agile/1.0/board/{}/sprint", []string{strconv.FormatInt(board, 10)}, q, nil, &page); err != nil {
		return 0, "", err
	}
	if len(page.Values) == 0 {
		return 0, "", nil
	}
	return page.Values[0].ID, page.Values[0].Name, nil
}

// JQL is what the site's JQL autocompletes from.
func (c *Client) JQL(ctx context.Context) (model.JiraJQL, error) {
	var raw struct {
		Fields []struct {
			Value       string   `json:"value"`
			DisplayName string   `json:"displayName"`
			Operators   []string `json:"operators"`
		} `json:"visibleFieldNames"`
		Functions []struct {
			Value string `json:"value"`
		} `json:"visibleFunctionNames"`
		Words []string `json:"jqlReservedWords"`
	}
	if err := c.do(ctx, http.MethodGet, "/rest/api/3/jql/autocompletedata", nil, nil, nil, &raw); err != nil {
		return model.JiraJQL{}, err
	}
	out := model.JiraJQL{Words: raw.Words}
	for _, f := range raw.Fields {
		out.Fields = append(out.Fields, model.JiraJQLField{Name: f.Value, Display: f.DisplayName, Operators: f.Operators})
	}
	for _, f := range raw.Functions {
		out.Functions = append(out.Functions, f.Value)
	}
	return out, nil
}

var tags = regexp.MustCompile(`<[^>]*>`)

// Suggestions are values of field that start with prefix, as JQL takes
// them (quoted where needed): ID the value, Name how it reads.
func (c *Client) Suggestions(ctx context.Context, field, prefix string) ([]model.JiraOption, error) {
	var raw struct {
		Results []struct {
			Value       string `json:"value"`
			DisplayName string `json:"displayName"`
		} `json:"results"`
	}
	q := url.Values{"fieldName": {field}, "fieldValue": {prefix}}
	if err := c.do(ctx, http.MethodGet, "/rest/api/3/jql/autocompletedata/suggestions", nil, q, nil, &raw); err != nil {
		return nil, err
	}
	var out []model.JiraOption
	for _, r := range raw.Results { // the part typed is in <b>
		out = append(out, model.JiraOption{ID: r.Value, Name: html.UnescapeString(tags.ReplaceAllString(r.DisplayName, ""))})
	}
	return out, nil
}

type rawUser struct {
	AccountID    string `json:"accountId"`
	DisplayName  string `json:"displayName"`
	EmailAddress string `json:"emailAddress"`
}

func (u *rawUser) name() string {
	if u == nil {
		return ""
	}
	return u.DisplayName
}

type rawStatus struct {
	Name     string `json:"name"`
	Category struct {
		Key string `json:"key"`
	} `json:"statusCategory"`
}

type rawIssue struct {
	ID     string `json:"id"`
	Key    string `json:"key"`
	Fields struct {
		Summary   string    `json:"summary"`
		Status    rawStatus `json:"status"`
		IssueType struct {
			Name string `json:"name"`
		} `json:"issuetype"`
		Priority *struct {
			Name string `json:"name"`
		} `json:"priority"`
		Assignee *rawUser `json:"assignee"`
		Updated  jiraTime `json:"updated"`
	} `json:"fields"`
}

func (r rawIssue) listed() model.JiraIssue {
	f := r.Fields
	is := model.JiraIssue{Key: r.Key, Summary: f.Summary, Type: f.IssueType.Name, Status: f.Status.Name,
		StatusCategory: f.Status.Category.Key, Assignee: f.Assignee.name(), Updated: time.Time(f.Updated)}
	if f.Priority != nil {
		is.Priority = f.Priority.Name
	}
	return is
}

// jiraTime reads Jira's times ("2026-10-25T21:15:39.083+0900").
type jiraTime time.Time

func (t *jiraTime) UnmarshalJSON(b []byte) error {
	s := strings.Trim(string(b), `"`)
	if s == "null" || s == "" {
		return nil
	}
	v, err := time.Parse("2006-01-02T15:04:05.000-0700", s)
	if err != nil {
		if v, err = time.Parse(time.RFC3339, s); err != nil {
			return fmt.Errorf("a time Jira sent: %w", err)
		}
	}
	*t = jiraTime(v)
	return nil
}
