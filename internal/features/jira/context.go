package jira

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"unicode"

	"github.com/afrase/nushi/internal/adf"
	"github.com/afrase/nushi/internal/model"
)

// Branch is a branch's name for work on an issue: its key, uppercase so
// Jira links it, then its summary as a slug of 40 characters at most, cut
// between words ("SCRUM-5-fix-the-login").
func Branch(key, summary string) string {
	words := strings.FieldsFunc(strings.ToLower(summary), func(r rune) bool {
		return r >= unicode.MaxASCII || !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
	slug := ""
	for _, w := range words {
		if len(slug)+1+len(w) > 41 {
			break
		}
		slug += "-" + w
	}
	return key + slug
}

var slugRE = regexp.MustCompile(`^(-[a-z0-9]+)*$`)

// IsBranch says branch is one Branch could have named for key (the
// worktree's folder takes its name).
func IsBranch(key, branch string) bool {
	rest, ok := strings.CutPrefix(branch, key)
	return ok && CheckKey(key) == nil && len(branch) <= 100 && slugRE.MatchString(rest)
}

// recentComments is how many of the latest comments a context packet has.
const recentComments = 5

var attachmentImage = regexp.MustCompile(`!\[([^\]]*)\]\(jira-attachment:\d+\)`)

// Context is an issue as a chat's first message: a Markdown packet of its
// key, summary, type, status, description, acceptance criteria, recent
// comments, links and subtasks. The user sees it in the box, and can edit
// it, before it's sent.
func (s *Service) Context(ctx context.Context, id, key string) (packet, branch string, err error) {
	is, err := s.Issue(ctx, id, key)
	if err != nil {
		return "", "", err
	}
	var b strings.Builder
	line := func(format string, args ...any) { fmt.Fprintf(&b, format+"\n", args...) }
	// The agent can't fetch an attachment: its image becomes its name.
	text := func(md string) string { return attachmentImage.ReplaceAllString(md, "[image: $1]") }
	line("# %s: %s", is.Key, is.Summary)
	line("")
	facts := []string{is.Type, is.Status}
	if is.Priority != "" {
		facts = append(facts, "priority "+is.Priority)
	}
	line("Jira issue %s (%s): %s", is.Key, strings.Join(facts, ", "), s.Browse(id, is.Key))
	if is.Assignee != "" || is.Reporter != "" {
		line("Assignee: %s · Reporter: %s", or(is.Assignee, "nobody"), or(is.Reporter, "unknown"))
	}
	if len(is.Labels) > 0 {
		line("Labels: %s", strings.Join(is.Labels, ", "))
	}
	if p := is.Parent; p != nil {
		line("Parent: %s %s (%s)", p.Key, p.Summary, p.Status)
	}
	section := func(title, body string) {
		if strings.TrimSpace(body) != "" {
			line("\n## %s\n\n%s", title, strings.TrimSpace(body))
		}
	}
	section("Description", text(is.Description))
	section("Acceptance criteria", text(is.AcceptanceCriteria))
	section("Subtasks", refs(is.Subtasks, func(model.JiraIssueRef) string { return "" }))
	links := make([]model.JiraIssueRef, len(is.Links))
	for i, l := range is.Links {
		links[i] = l.Issue
	}
	section("Linked issues", refs(links, func(r model.JiraIssueRef) string {
		for _, l := range is.Links {
			if l.Issue.Key == r.Key {
				return l.Relation + " "
			}
		}
		return ""
	}))
	var remote strings.Builder
	for _, r := range is.RemoteLinks {
		fmt.Fprintf(&remote, "- %s\n", adf.Link(or(r.Title, r.URL), r.URL))
	}
	section("Remote links", remote.String())
	var comments strings.Builder
	for _, c := range is.Comments[max(0, len(is.Comments)-recentComments):] {
		fmt.Fprintf(&comments, "**%s** (%s):\n\n%s\n\n", or(c.Author, "someone"), c.Created.Format("2006-01-02"), text(c.Body))
	}
	section("Recent comments", comments.String())
	return strings.TrimSpace(b.String()) + "\n", Branch(is.Key, is.Summary), nil
}

func refs(rs []model.JiraIssueRef, before func(model.JiraIssueRef) string) string {
	var b strings.Builder
	for _, r := range rs {
		fmt.Fprintf(&b, "- %s%s %s (%s)\n", before(r), r.Key, r.Summary, r.Status)
	}
	return b.String()
}

func or(s, otherwise string) string {
	if s == "" {
		return otherwise
	}
	return s
}
