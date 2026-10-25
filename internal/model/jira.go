package model

import "time"

// JiraUser is who a Jira site's token belongs to.
type JiraUser struct {
	AccountID, Name, Email string
}

// JiraIssue is an issue as lists and the issue view show it. Text fields
// (Description, AcceptanceCriteria, comments) are Markdown; lists fill
// only the first fields, up to Updated.
type JiraIssue struct {
	Key, Summary, Type, Status string
	// StatusCategory is Jira's "new", "indeterminate" or "done".
	StatusCategory     string
	Priority, Assignee string
	Updated            time.Time

	Reporter           string
	Created            time.Time
	Labels             []string
	Description        string
	AcceptanceCriteria string // the site's field of that name, if it has one
	Parent             *JiraIssueRef
	Subtasks           []JiraIssueRef
	Links              []JiraLink
	Attachments        []JiraAttachment
	Comments           []JiraComment
	RemoteLinks        []JiraRemoteLink
}

// JiraIssueRef is another issue an issue names: its parent, a subtask, a
// linked issue.
type JiraIssueRef struct {
	Key, Summary, Type, Status, StatusCategory string
}

// JiraLink is a link to another issue, as this issue reads it ("blocks",
// "is blocked by").
type JiraLink struct {
	Relation string
	Issue    JiraIssueRef
}

// JiraAttachment is a file on an issue.
type JiraAttachment struct {
	ID, Name, MimeType string
	Size               int64
}

// JiraComment is a comment; Body is Markdown.
type JiraComment struct {
	ID, Author, Body string
	Created, Updated time.Time
}

// JiraRemoteLink is a link to something outside Jira (a pull request, a
// page).
type JiraRemoteLink struct {
	Title, URL string
}

// JiraTransition is a move an issue's workflow allows now, to a status;
// Fields are what the move's screen asks for.
type JiraTransition struct {
	ID, Name, To, ToCategory string
	Fields                   []JiraField
}

// JiraField is a field a transition asks for. Type is Jira's schema type
// ("string", "option", "user", "array", "priority", "resolution"…);
// Options are its allowed values, when Jira lists them.
type JiraField struct {
	ID, Name, Type string
	Required       bool
	Options        []JiraOption
}

// JiraOption is an allowed value of a field.
type JiraOption struct {
	ID, Name string
}

// JiraBoard is a board, for its current sprint.
type JiraBoard struct {
	ID            int64
	Name, Project string
}

// JiraJQL is what a site's JQL autocompletes from: its fields (with the
// operators each takes), functions and reserved words.
type JiraJQL struct {
	Fields    []JiraJQLField
	Functions []string
	Words     []string
}

// JiraJQLField is a field JQL can search on: Name as typed in JQL,
// Display as Jira shows it.
type JiraJQLField struct {
	Name, Display string
	Operators     []string
}
