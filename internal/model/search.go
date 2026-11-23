package model

import "time"

// SessionSearch is a search of an agent's sessions for text in what the
// user and the agent said (ADR 0035's search).
type SessionSearch struct {
	// Query is plain text, found case aside, its whitespace matching any.
	Query string
	// Skip says which sessions not to read at all (the chats'); nil: none.
	Skip func(id string) bool
	// InFolder says whether a session of cwd is wanted, once its cwd is
	// known; nil: every one. It may be called from several goroutines at
	// once.
	InFolder func(cwd string) bool
	// Folder narrows where the agent's files are read to the folder's
	// history, when they are kept by folder: its real path; "" for every
	// folder's. InFolder still decides.
	Folder string
	// Max is how many sessions to find at most, the newest first.
	Max int
	// Unnoted is a text of the user's without the notes Nushi sent before
	// it, which the agent keeps as part of the user's message: the reader
	// searches, and names a session by, what it returns ("" for a text
	// that was only notes). nil: each text as written.
	Unnoted func(text string) string
}

// SessionHit is a session whose messages say a search's text: the first
// time they say it, on one line, and how many times.
type SessionHit struct {
	SessionID string
	Folder    string // its cwd, as the agent records it
	Title     string // as the agent's list names it; "" when it can't tell
	Updated   time.Time
	Count     int
	// Before and After are the text around the first hit, cut to a few
	// words each ("…" where cut); Match is the hit as written.
	Before, Match, After string
}
