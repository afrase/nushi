package api

import (
	"context"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/jira"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

// jiraErr is a Jira call's failure: the message says what (Jira's own
// words, a refused token, the keychain wanting an OK).
func jiraErr(err error) error { return connect.NewError(connect.CodeFailedPrecondition, err) }

func (s *server) ListJiraSites(context.Context, *connect.Request[nushiv1.ListJiraSitesRequest]) (*connect.Response[nushiv1.ListJiraSitesResponse], error) {
	sites, err := s.jira.Sites()
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	out := &nushiv1.ListJiraSitesResponse{}
	for _, st := range sites {
		p := jiraSiteProto(st.JiraSite)
		p.Problem, p.NeedsOk, p.NeedsRestart = st.Problem, st.NeedsOK, st.Restart
		out.Sites = append(out.Sites, p)
	}
	return connect.NewResponse(out), nil
}

func jiraSiteProto(site model.JiraSite) *nushiv1.JiraSite {
	p := &nushiv1.JiraSite{Id: jira.SiteID(site), Url: site.URL, Email: site.Email, Name: site.Name, AccountId: site.AccountID,
		Scoped: site.CloudID != "", Expires: unixMs(site.Expires), Board: site.Board, BoardName: site.BoardName}
	for _, q := range site.Searches {
		p.Searches = append(p.Searches, &nushiv1.JiraSearch{Name: q.Name, Jql: q.JQL})
	}
	return p
}

func (s *server) AddJiraSite(ctx context.Context, req *connect.Request[nushiv1.AddJiraSiteRequest]) (*connect.Response[nushiv1.AddJiraSiteResponse], error) {
	var expires time.Time
	if req.Msg.Expires > 0 {
		expires = time.UnixMilli(req.Msg.Expires)
	}
	site, err := s.jira.AddSite(ctx, req.Msg.Url, req.Msg.Email, req.Msg.Token, expires)
	if err != nil {
		return nil, jiraErr(err)
	}
	return connect.NewResponse(&nushiv1.AddJiraSiteResponse{Site: jiraSiteProto(site)}), nil
}

func (s *server) RemoveJiraSite(_ context.Context, req *connect.Request[nushiv1.RemoveJiraSiteRequest]) (*connect.Response[nushiv1.RemoveJiraSiteResponse], error) {
	if err := s.jira.RemoveSite(req.Msg.Site); err != nil {
		return nil, jiraErr(err)
	}
	return connect.NewResponse(&nushiv1.RemoveJiraSiteResponse{}), nil
}

func (s *server) CheckJiraSite(ctx context.Context, req *connect.Request[nushiv1.CheckJiraSiteRequest]) (*connect.Response[nushiv1.CheckJiraSiteResponse], error) {
	u, err := s.jira.Check(ctx, req.Msg.Site)
	if err != nil {
		return nil, jiraErr(err)
	}
	return connect.NewResponse(&nushiv1.CheckJiraSiteResponse{Name: u.Name}), nil
}

func (s *server) AllowJiraToken(_ context.Context, req *connect.Request[nushiv1.AllowJiraTokenRequest]) (*connect.Response[nushiv1.AllowJiraTokenResponse], error) {
	if err := s.jira.AllowToken(req.Msg.Site); err != nil {
		return nil, jiraErr(err)
	}
	return connect.NewResponse(&nushiv1.AllowJiraTokenResponse{}), nil
}

func (s *server) ListJiraBoards(ctx context.Context, req *connect.Request[nushiv1.ListJiraBoardsRequest]) (*connect.Response[nushiv1.ListJiraBoardsResponse], error) {
	boards, err := s.jira.Boards(ctx, req.Msg.Site)
	if err != nil {
		return nil, jiraErr(err)
	}
	out := &nushiv1.ListJiraBoardsResponse{}
	for _, b := range boards {
		out.Boards = append(out.Boards, &nushiv1.JiraBoard{Id: b.ID, Name: b.Name, Project: b.Project})
	}
	return connect.NewResponse(out), nil
}

func (s *server) SetJiraBoard(_ context.Context, req *connect.Request[nushiv1.SetJiraBoardRequest]) (*connect.Response[nushiv1.SetJiraBoardResponse], error) {
	b := req.Msg.GetBoard()
	if err := s.jira.SetBoard(req.Msg.Site, model.JiraBoard{ID: b.GetId(), Name: b.GetName(), Project: b.GetProject()}); err != nil {
		return nil, jiraErr(err)
	}
	return connect.NewResponse(&nushiv1.SetJiraBoardResponse{}), nil
}

func (s *server) SetJiraSearches(_ context.Context, req *connect.Request[nushiv1.SetJiraSearchesRequest]) (*connect.Response[nushiv1.SetJiraSearchesResponse], error) {
	var searches []model.JiraSearch
	for _, q := range req.Msg.Searches {
		searches = append(searches, model.JiraSearch{Name: q.Name, JQL: q.Jql})
	}
	if err := s.jira.SetSearches(req.Msg.Site, searches); err != nil {
		return nil, jiraErr(err)
	}
	return connect.NewResponse(&nushiv1.SetJiraSearchesResponse{}), nil
}

func (s *server) ListJiraIssues(ctx context.Context, req *connect.Request[nushiv1.ListJiraIssuesRequest]) (*connect.Response[nushiv1.ListJiraIssuesResponse], error) {
	var (
		l   jira.List
		at  = time.Now()
		err error
	)
	if req.Msg.Cached {
		l, at, err = s.jira.CachedList(req.Msg.Site, req.Msg.List, req.Msg.Jql)
	} else {
		l, err = s.jira.List(ctx, req.Msg.Site, req.Msg.List, req.Msg.Jql)
	}
	if err != nil {
		return nil, jiraErr(err)
	}
	out := &nushiv1.ListJiraIssuesResponse{Sprint: l.Sprint, AtMs: unixMs(at)}
	for _, is := range l.Issues {
		out.Issues = append(out.Issues, jiraIssueProto(is, ""))
	}
	return connect.NewResponse(out), nil
}

func (s *server) GetJiraJql(ctx context.Context, req *connect.Request[nushiv1.GetJiraJqlRequest]) (*connect.Response[nushiv1.GetJiraJqlResponse], error) {
	jql, err := s.jira.JQL(ctx, req.Msg.Site)
	if err != nil {
		return nil, jiraErr(err)
	}
	out := &nushiv1.GetJiraJqlResponse{Functions: jql.Functions, Words: jql.Words}
	for _, f := range jql.Fields {
		out.Fields = append(out.Fields, &nushiv1.JiraJqlField{Name: f.Name, Display: f.Display, Operators: f.Operators})
	}
	return connect.NewResponse(out), nil
}

func (s *server) SuggestJiraJql(ctx context.Context, req *connect.Request[nushiv1.SuggestJiraJqlRequest]) (*connect.Response[nushiv1.SuggestJiraJqlResponse], error) {
	values, err := s.jira.Suggestions(ctx, req.Msg.Site, req.Msg.FieldName, req.Msg.Prefix)
	if err != nil {
		return nil, jiraErr(err)
	}
	return connect.NewResponse(&nushiv1.SuggestJiraJqlResponse{Values: jiraOptions(values)}), nil
}

func (s *server) GetJiraIssue(ctx context.Context, req *connect.Request[nushiv1.GetJiraIssueRequest]) (*connect.Response[nushiv1.GetJiraIssueResponse], error) {
	var (
		is  model.JiraIssue
		at  = time.Now()
		err error
	)
	if req.Msg.Cached {
		is, at, err = s.jira.CachedIssue(req.Msg.Site, req.Msg.Key)
	} else {
		is, err = s.jira.Issue(ctx, req.Msg.Site, req.Msg.Key)
	}
	if err != nil {
		return nil, jiraErr(err)
	}
	if at.IsZero() {
		return connect.NewResponse(&nushiv1.GetJiraIssueResponse{}), nil
	}
	resp := &nushiv1.GetJiraIssueResponse{Issue: jiraIssueProto(is, s.jira.Browse(req.Msg.Site, is.Key)), AtMs: unixMs(at)}
	for _, w := range s.jira.Writes(req.Msg.Site, is.Key) {
		resp.AgentWrites = append(resp.AgentWrites, &nushiv1.JiraWrite{Kind: w.Kind, Comment: w.Comment, To: w.To, Chat: w.Chat, Agent: w.Agent, At: unixMs(w.At)})
	}
	return connect.NewResponse(resp), nil
}

func (s *server) ListJiraTransitions(ctx context.Context, req *connect.Request[nushiv1.ListJiraTransitionsRequest]) (*connect.Response[nushiv1.ListJiraTransitionsResponse], error) {
	ts, err := s.jira.Transitions(ctx, req.Msg.Site, req.Msg.Key)
	if err != nil {
		return nil, jiraErr(err)
	}
	out := &nushiv1.ListJiraTransitionsResponse{}
	for _, t := range ts {
		pt := &nushiv1.JiraTransition{Id: t.ID, Name: t.Name, To: t.To, ToCategory: t.ToCategory}
		for _, f := range t.Fields {
			pt.Fields = append(pt.Fields, &nushiv1.JiraField{Id: f.ID, Name: f.Name, Type: f.Type, Required: f.Required, Options: jiraOptions(f.Options)})
		}
		out.Transitions = append(out.Transitions, pt)
	}
	return connect.NewResponse(out), nil
}

func (s *server) TransitionJiraIssue(ctx context.Context, req *connect.Request[nushiv1.TransitionJiraIssueRequest]) (*connect.Response[nushiv1.TransitionJiraIssueResponse], error) {
	if _, err := s.jira.Transition(ctx, req.Msg.Site, req.Msg.Key, req.Msg.Transition, req.Msg.Values, "you"); err != nil {
		return nil, jiraErr(err)
	}
	return connect.NewResponse(&nushiv1.TransitionJiraIssueResponse{}), nil
}

func (s *server) AddJiraComment(ctx context.Context, req *connect.Request[nushiv1.AddJiraCommentRequest]) (*connect.Response[nushiv1.AddJiraCommentResponse], error) {
	cm, err := s.jira.AddComment(ctx, req.Msg.Site, req.Msg.Key, req.Msg.Markdown, "you")
	if err != nil {
		return nil, jiraErr(err)
	}
	return connect.NewResponse(&nushiv1.AddJiraCommentResponse{Comment: jiraCommentProto(cm)}), nil
}

func (s *server) FindJiraIssues(ctx context.Context, req *connect.Request[nushiv1.FindJiraIssuesRequest]) (*connect.Response[nushiv1.FindJiraIssuesResponse], error) {
	f, err := s.jira.Find(ctx, req.Msg.Text, req.Msg.Site)
	if err != nil {
		return nil, jiraErr(err)
	}
	out := &nushiv1.FindJiraIssuesResponse{UnknownSite: f.UnknownSite}
	for _, x := range f.Issues {
		out.Issues = append(out.Issues, &nushiv1.FoundJiraIssue{Site: x.Site, Issue: jiraIssueProto(x.Issue, ""), Branch: x.Branch})
	}
	return connect.NewResponse(out), nil
}

func (s *server) GetJiraAttachment(ctx context.Context, req *connect.Request[nushiv1.GetJiraAttachmentRequest]) (*connect.Response[nushiv1.GetJiraAttachmentResponse], error) {
	b, mime, err := s.jira.Attachment(ctx, req.Msg.Site, req.Msg.Id, req.Msg.Thumbnail)
	if err != nil {
		return nil, jiraErr(err)
	}
	return connect.NewResponse(&nushiv1.GetJiraAttachmentResponse{Data: b, MimeType: mime}), nil
}

func jiraOptions(opts []model.JiraOption) []*nushiv1.JiraOption {
	var out []*nushiv1.JiraOption
	for _, o := range opts {
		out = append(out, &nushiv1.JiraOption{Id: o.ID, Name: o.Name})
	}
	return out
}

func jiraRef(r model.JiraIssueRef) *nushiv1.JiraIssueRef {
	return &nushiv1.JiraIssueRef{Key: r.Key, Summary: r.Summary, Type: r.Type, Status: r.Status, StatusCategory: r.StatusCategory}
}

func jiraCommentProto(c model.JiraComment) *nushiv1.JiraComment {
	return &nushiv1.JiraComment{Id: c.ID, Author: c.Author, Body: c.Body, Created: unixMs(c.Created), Updated: unixMs(c.Updated)}
}

func jiraIssueProto(is model.JiraIssue, url string) *nushiv1.JiraIssue {
	p := &nushiv1.JiraIssue{Key: is.Key, Summary: is.Summary, Type: is.Type, Status: is.Status, StatusCategory: is.StatusCategory,
		Priority: is.Priority, Assignee: is.Assignee, AssigneeId: is.AssigneeID, Updated: unixMs(is.Updated), Reporter: is.Reporter, Created: unixMs(is.Created),
		Labels: is.Labels, Description: is.Description, AcceptanceCriteria: is.AcceptanceCriteria, Url: url}
	if is.Parent != nil {
		p.Parent = jiraRef(*is.Parent)
	}
	for _, r := range is.Subtasks {
		p.Subtasks = append(p.Subtasks, jiraRef(r))
	}
	for _, l := range is.Links {
		p.Links = append(p.Links, &nushiv1.JiraLink{Relation: l.Relation, Issue: jiraRef(l.Issue)})
	}
	for _, a := range is.Attachments {
		p.Attachments = append(p.Attachments, &nushiv1.JiraAttachment{Id: a.ID, Name: a.Name, MimeType: a.MimeType, Size: a.Size})
	}
	for _, c := range is.Comments {
		p.Comments = append(p.Comments, jiraCommentProto(c))
	}
	for _, r := range is.RemoteLinks {
		p.RemoteLinks = append(p.RemoteLinks, &nushiv1.JiraRemoteLink{Title: r.Title, Url: r.URL})
	}
	return p
}
