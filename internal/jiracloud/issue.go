package jiracloud

import (
	"cmp"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/adf"
	"github.com/afrase/nushi/internal/model"
)

// issueFields are what the issue view shows (the site's acceptance
// criteria field joins them).
var issueFields = []string{"summary", "status", "issuetype", "priority", "assignee", "reporter", "created", "updated",
	"labels", "description", "parent", "subtasks", "issuelinks", "attachment"}

type rawRef struct {
	Key    string `json:"key"`
	Fields struct {
		Summary   string    `json:"summary"`
		Status    rawStatus `json:"status"`
		IssueType struct {
			Name string `json:"name"`
		} `json:"issuetype"`
	} `json:"fields"`
}

func (r rawRef) ref() model.JiraIssueRef {
	return model.JiraIssueRef{Key: r.Key, Summary: r.Fields.Summary, Type: r.Fields.IssueType.Name,
		Status: r.Fields.Status.Name, StatusCategory: r.Fields.Status.Category.Key}
}

type rawDetail struct {
	Reporter    *rawUser        `json:"reporter"`
	Created     jiraTime        `json:"created"`
	Labels      []string        `json:"labels"`
	Description json.RawMessage `json:"description"`
	Parent      *rawRef         `json:"parent"`
	Subtasks    []rawRef        `json:"subtasks"`
	IssueLinks  []struct {
		Type struct {
			Inward  string `json:"inward"`
			Outward string `json:"outward"`
		} `json:"type"`
		InwardIssue  *rawRef `json:"inwardIssue"`
		OutwardIssue *rawRef `json:"outwardIssue"`
	} `json:"issuelinks"`
	Attachment []struct {
		ID       string `json:"id"`
		Filename string `json:"filename"`
		MimeType string `json:"mimeType"`
		Size     int64  `json:"size"`
	} `json:"attachment"`
}

// Issue is an issue whole: its fields, comments (the latest 100) and
// remote links, text as Markdown.
func (c *Client) Issue(ctx context.Context, key string) (model.JiraIssue, error) {
	accept, err := c.AcceptanceField(ctx)
	if err != nil {
		return model.JiraIssue{}, err
	}
	fields := issueFields
	if accept != "" {
		fields = append(slices.Clip(fields), accept)
	}
	var raw struct {
		Key      string                     `json:"key"`
		Fields   json.RawMessage            `json:"fields"`
		Rendered map[string]json.RawMessage `json:"renderedFields"`
	}
	q := url.Values{"fields": {strings.Join(fields, ",")}, "expand": {"renderedFields"}}
	if err := c.do(ctx, http.MethodGet, "/rest/api/3/issue/{}", []string{key}, q, nil, &raw); err != nil {
		return model.JiraIssue{}, err
	}
	base := rawIssue{Key: raw.Key}
	var d rawDetail
	var all map[string]json.RawMessage
	for _, v := range []any{&base.Fields, &d, &all} {
		if err := json.Unmarshal(raw.Fields, v); err != nil {
			return model.JiraIssue{}, err
		}
	}
	is := base.listed()
	is.Reporter, is.Created, is.Labels = d.Reporter.name(), time.Time(d.Created), d.Labels
	names := map[string]string{} // attachment id -> file name
	for _, a := range d.Attachment {
		is.Attachments = append(is.Attachments, model.JiraAttachment{ID: a.ID, Name: a.Filename, MimeType: a.MimeType, Size: a.Size})
		names[a.ID] = a.Filename
	}
	media := mediaOf(names, string(raw.Rendered["description"]))
	if is.Description, err = markdown(d.Description, media); err != nil {
		return is, err
	}
	if accept != "" {
		media := mediaOf(names, string(raw.Rendered[accept]))
		is.AcceptanceCriteria, _ = markdown(all[accept], media) // a field of another kind than text is left out
	}
	if d.Parent != nil {
		p := d.Parent.ref()
		is.Parent = &p
	}
	for _, s := range d.Subtasks {
		is.Subtasks = append(is.Subtasks, s.ref())
	}
	for _, l := range d.IssueLinks {
		switch {
		case l.OutwardIssue != nil:
			is.Links = append(is.Links, model.JiraLink{Relation: l.Type.Outward, Issue: l.OutwardIssue.ref()})
		case l.InwardIssue != nil:
			is.Links = append(is.Links, model.JiraLink{Relation: l.Type.Inward, Issue: l.InwardIssue.ref()})
		}
	}
	if is.Comments, err = c.comments(ctx, key, names); err != nil {
		return is, err
	}
	is.RemoteLinks, err = c.remoteLinks(ctx, key)
	return is, err
}

// markdown renders an ADF field; a field that isn't ADF (a plain string)
// is shown as it is.
func markdown(raw json.RawMessage, media adf.Media) (string, error) {
	var s string
	if json.Unmarshal(raw, &s) == nil {
		return s, nil
	}
	doc, err := adf.Parse(raw)
	if err != nil {
		return "", fmt.Errorf("an issue's text Nushi can't read: %w", err)
	}
	return adf.ToMarkdown(doc, media), nil
}

type rawComment struct {
	ID       string          `json:"id"`
	Author   *rawUser        `json:"author"`
	Body     json.RawMessage `json:"body"`
	Rendered string          `json:"renderedBody"`
	Created  jiraTime        `json:"created"`
	Updated  jiraTime        `json:"updated"`
}

func (r rawComment) comment(names map[string]string) (model.JiraComment, error) {
	body, err := markdown(r.Body, mediaOf(names, r.Rendered))
	return model.JiraComment{ID: r.ID, Author: r.Author.name(), Body: body, Created: time.Time(r.Created), Updated: time.Time(r.Updated)}, err
}

// comments are an issue's latest 100 comments, oldest first.
func (c *Client) comments(ctx context.Context, key string, names map[string]string) ([]model.JiraComment, error) {
	var page struct {
		Comments []rawComment `json:"comments"`
	}
	q := url.Values{"orderBy": {"-created"}, "maxResults": {"100"}, "expand": {"renderedBody"}}
	if err := c.do(ctx, http.MethodGet, "/rest/api/3/issue/{}/comment", []string{key}, q, nil, &page); err != nil {
		return nil, err
	}
	out := make([]model.JiraComment, 0, len(page.Comments))
	for _, r := range slices.Backward(page.Comments) {
		cm, err := r.comment(names)
		if err != nil {
			return nil, err
		}
		out = append(out, cm)
	}
	return out, nil
}

// AddComment posts markdown as a comment on an issue.
func (c *Client) AddComment(ctx context.Context, key, markdown string) (model.JiraComment, error) {
	var r rawComment
	body := map[string]any{"body": adf.FromMarkdown(markdown)}
	if err := c.do(ctx, http.MethodPost, "/rest/api/3/issue/{}/comment", []string{key}, nil, body, &r); err != nil {
		return model.JiraComment{}, err
	}
	return r.comment(nil)
}

func (c *Client) remoteLinks(ctx context.Context, key string) ([]model.JiraRemoteLink, error) {
	var raw []struct {
		Object struct {
			Title string `json:"title"`
			URL   string `json:"url"`
		} `json:"object"`
	}
	if err := c.do(ctx, http.MethodGet, "/rest/api/3/issue/{}/remotelink", []string{key}, nil, nil, &raw); err != nil {
		return nil, err
	}
	var out []model.JiraRemoteLink
	for _, r := range raw {
		out = append(out, model.JiraRemoteLink{Title: r.Object.Title, URL: r.Object.URL})
	}
	return out, nil
}

// Transitions are the moves an issue's workflow allows now, with the
// fields each one's screen asks for.
func (c *Client) Transitions(ctx context.Context, key string) ([]model.JiraTransition, error) {
	var raw struct {
		Transitions []struct {
			ID     string    `json:"id"`
			Name   string    `json:"name"`
			To     rawStatus `json:"to"`
			Fields map[string]struct {
				Required bool   `json:"required"`
				Name     string `json:"name"`
				Schema   struct {
					Type   string `json:"type"`
					Items  string `json:"items"`
					Custom string `json:"custom"`
				} `json:"schema"`
				Allowed []struct {
					ID    string `json:"id"`
					Name  string `json:"name"`
					Value string `json:"value"`
				} `json:"allowedValues"`
			} `json:"fields"`
		} `json:"transitions"`
	}
	q := url.Values{"expand": {"transitions.fields"}}
	if err := c.do(ctx, http.MethodGet, "/rest/api/3/issue/{}/transitions", []string{key}, q, nil, &raw); err != nil {
		return nil, err
	}
	var out []model.JiraTransition
	for _, t := range raw.Transitions {
		tr := model.JiraTransition{ID: t.ID, Name: t.Name, To: t.To.Name, ToCategory: t.To.Category.Key}
		for id, f := range t.Fields {
			typ := f.Schema.Type
			switch {
			case typ == "array":
				typ = "array:" + f.Schema.Items
			case strings.HasSuffix(f.Schema.Custom, ":textarea"):
				typ = "text"
			}
			fl := model.JiraField{ID: id, Name: f.Name, Type: typ, Required: f.Required}
			for _, a := range f.Allowed {
				fl.Options = append(fl.Options, model.JiraOption{ID: a.ID, Name: cmp.Or(a.Name, a.Value)})
			}
			tr.Fields = append(tr.Fields, fl)
		}
		slices.SortFunc(tr.Fields, func(a, b model.JiraField) int { // required first, then by name
			if a.Required != b.Required {
				return map[bool]int{true: -1, false: 1}[a.Required]
			}
			return strings.Compare(a.Name, b.Name)
		})
		out = append(out, tr)
	}
	return out, nil
}

// Transition moves an issue through t, with values for its fields (by
// id: an option's id, a user's account id, text as Markdown).
func (c *Client) Transition(ctx context.Context, key string, t model.JiraTransition, values map[string]string) error {
	body := map[string]any{"transition": map[string]string{"id": t.ID}}
	fields := map[string]any{}
	for _, f := range t.Fields {
		v, ok := values[f.ID]
		if !ok || v == "" {
			continue
		}
		fields[f.ID] = fieldValue(f, v)
	}
	if len(fields) > 0 {
		body["fields"] = fields
	}
	return c.do(ctx, http.MethodPost, "/rest/api/3/issue/{}/transitions", []string{key}, nil, body, nil)
}

// fieldValue is v as Jira takes a field of f's type.
func fieldValue(f model.JiraField, v string) any {
	switch f.Type {
	case "text":
		return adf.FromMarkdown(v)
	case "number":
		if n, err := strconv.ParseFloat(v, 64); err == nil {
			return n
		}
	case "user":
		return map[string]string{"accountId": v}
	case "array:string":
		return strings.Fields(v)
	case "string", "date", "datetime":
		return v
	}
	if strings.HasPrefix(f.Type, "array:") {
		return []map[string]string{{"id": v}}
	}
	return map[string]string{"id": v} // option, priority, resolution, version…
}

// maxAttachment is the largest attachment Nushi fetches.
const maxAttachment = 20 << 20

// Attachment fetches an attachment's file (or its thumbnail), 20 MB at
// most, and its type.
func (c *Client) Attachment(ctx context.Context, id string, thumbnail bool) ([]byte, string, error) {
	path := "/rest/api/3/attachment/content/{}"
	if thumbnail {
		path = "/rest/api/3/attachment/thumbnail/{}"
	}
	resp, err := c.send(ctx, http.MethodGet, path, []string{id}, nil, nil)
	if err != nil {
		return nil, "", err
	}
	defer func() { _ = resp.Body.Close() }()
	b, err := io.ReadAll(io.LimitReader(resp.Body, maxAttachment+1))
	if err == nil && len(b) > maxAttachment {
		err = fmt.Errorf("the attachment is over %d MB", maxAttachment>>20)
	}
	return b, resp.Header.Get("Content-Type"), err
}

var acceptanceNames = map[string]bool{"acceptance criteria": true, "acceptance criterion": true}

// AcceptanceField is the id of the site's acceptance criteria field, ""
// when it has none (looked up once).
func (c *Client) AcceptanceField(ctx context.Context) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.acceptance != nil {
		return *c.acceptance, nil
	}
	var fields []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	}
	if err := c.do(ctx, http.MethodGet, "/rest/api/3/field", nil, nil, nil, &fields); err != nil {
		return "", err
	}
	id := ""
	for _, f := range fields {
		if acceptanceNames[strings.ToLower(strings.TrimSpace(f.Name))] {
			id = f.ID
			break
		}
	}
	c.acceptance = &id
	return id, nil
}

var (
	tagRE        = regexp.MustCompile(`<[^>]+>`)
	mediaIDRE    = regexp.MustCompile(`data-media-services-id="([^"]+)"`)
	attachmentRE = regexp.MustCompile(`/attachment/(?:content|thumbnail)/(\d+)`)
)

// mediaOf maps the media ids in a text's ADF to the issue's attachments,
// through the HTML Jira renders of it: ADF names Atlassian's media files,
// and the rendered tag for each has the attachment's id beside it. The
// link is adf.AttachmentScheme and the attachment's id.
func mediaOf(names map[string]string, rendered string) adf.Media {
	ids := map[string]string{}
	if s, err := strconv.Unquote(rendered); err == nil {
		rendered = s // a JSON string as it came
	}
	for _, tag := range tagRE.FindAllString(rendered, -1) {
		m, a := mediaIDRE.FindStringSubmatch(tag), attachmentRE.FindStringSubmatch(tag)
		if m != nil && a != nil {
			ids[m[1]] = a[1]
		}
	}
	return func(media string) (string, string) {
		id, ok := ids[media]
		if !ok {
			return "", ""
		}
		return names[id], adf.AttachmentScheme + id
	}
}
