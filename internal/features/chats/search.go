package chats

import (
	"context"
	"errors"
	"io/fs"
	"log/slog"
	"os"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// FoundText is a session Search found: as Find lists it, with where its
// messages first say the text and how many times.
type FoundText struct {
	Found
	Count int
	// Before and After are the text around the first hit, cut to a few
	// words each; Match is the hit as written.
	Before, Match, After string
}

// FoundTexts is what Search found, the newest first.
type FoundTexts struct {
	Sessions []FoundText
	// CanSearch says Nushi reads the agent's transcripts (SessionSearcher);
	// without, nothing is found.
	CanSearch bool
	// More says the search stopped before reading every transcript: it
	// took too long, or found searchMax.
	More bool
	// As FoundPage's.
	SeesOpen, OneWriter bool
}

// searchMax is how many sessions a search finds at most; searchTime how
// long it reads at most (a search reads every transcript again: ADR 0035).
const (
	searchMax  = 50
	searchTime = 10 * time.Second
)

// Search finds the agent's sessions in folder ("" for every folder) whose
// messages say text, case aside: those Find would list (no chat's, no
// fork, no subagent's), the newest first.
func (s *Service) Search(ctx context.Context, agent, folder, text string) (FoundTexts, error) {
	k, err := s.kindOf(agent)
	if err != nil {
		return FoundTexts{}, err
	}
	if folder != "" {
		if err := checkFolder(folder); err != nil {
			return FoundTexts{}, err
		}
	}
	if k.searcher == nil {
		return FoundTexts{}, nil
	}
	ours, err := s.ownSessions()
	if err != nil {
		return FoundTexts{}, err
	}
	resolved := git.RealPath(folder)
	var mu sync.Mutex
	paths := map[string]string{} // a cwd's real path, once looked up
	inFolder := func(cwd string) bool {
		if folder == "" {
			return true
		}
		mu.Lock()
		defer mu.Unlock()
		if _, ok := paths[cwd]; !ok {
			paths[cwd] = git.RealPath(cwd)
		}
		return paths[cwd] == resolved
	}
	reading, cancel := context.WithTimeout(ctx, searchTime)
	defer cancel()
	began := time.Now()
	hits, more, err := k.searcher.SearchSessions(reading, model.SessionSearch{Query: text, Folder: resolved, Max: searchMax,
		Skip: func(id string) bool { return ours[id] }, InFolder: inFolder})
	if err != nil {
		if ctx.Err() != nil || !errors.Is(err, context.DeadlineExceeded) {
			return FoundTexts{}, err
		}
		more = true // out of time: what was read is the answer
	}
	// The text searched for is the user's: never logged.
	slog.Info("searched sessions", "agent", k.Name, "found", len(hits), "more", more, "took", time.Since(began).Round(time.Millisecond))
	out := FoundTexts{CanSearch: true, More: more, SeesOpen: k.openFinder != nil, OneWriter: k.OneWriter}
	ids := make([]string, len(hits))
	for i, h := range hits {
		ids[i] = h.SessionID
		f := FoundText{SessionID: h.SessionID, Title: h.Title, Folder: h.Folder, Updated: h.Updated,
			Count: h.Count, Before: h.Before, Match: h.Match, After: h.After}
		if h.Folder != "" {
			_, err := os.Stat(h.Folder)
			f.FolderGone = errors.Is(err, fs.ErrNotExist)
		}
		out.Sessions = append(out.Sessions, f)
	}
	if k.openFinder != nil {
		open := k.openFinder.OpenElsewhere(ids)
		for i := range out.Sessions {
			out.Sessions[i].OpenIn = open[out.Sessions[i].SessionID]
		}
	}
	return out, nil
}
