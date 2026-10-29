package chats

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"maps"
	"os"
	"slices"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/git"
)

// Found is one of an agent's sessions that isn't a chat: started in a
// terminal, say. Opening it (Service.Open) makes it one.
type Found struct {
	SessionID string
	Title     string
	Folder    string    // its cwd, as the agent reports it
	Updated   time.Time // its last activity; zero when the agent doesn't say
	Messages  int       // how many messages it has, when the agent says (_meta.messageCount)
	// OpenIn says where it is open now, outside this daemon ("a terminal"),
	// when the agent's Kind can tell (Kind.OpenElsewhere).
	OpenIn     string
	FolderGone bool // its folder no longer exists: it can't be opened
}

// FoundPage is a page of an agent's sessions, newest first.
type FoundPage struct {
	Sessions []Found
	Next     string // the cursor for the next page; "" at the end
	// CanList says the agent lists its sessions and reopens them
	// (session/list and session/load); without, there's no list.
	CanList bool
	// SeesOpen says the agent's Kind can tell a session open elsewhere;
	// OneWriter that such a session can't be opened (Kind.OneWriter).
	SeesOpen, OneWriter bool
}

// findPage is how many sessions a page holds at least, unless the agent's
// list ends first; findCalls bounds the session/list calls one page takes
// (an agent such as Codex pages through every folder's sessions and
// leaves out the other folders' after).
const (
	findPage  = 50
	findCalls = 20
)

// Find lists the agent's sessions in folder ("" for every folder) that
// aren't chats yet and aren't forks, newest first, from cursor on (the
// last page's Next).
// It starts the agent to ask, and stops it after.
func (s *Service) Find(ctx context.Context, agent, folder, cursor string) (FoundPage, error) {
	k, err := s.kindOf(agent)
	if err != nil {
		return FoundPage{}, err
	}
	if folder != "" {
		if err := CheckFolder(folder); err != nil {
			return FoundPage{}, err
		}
	}
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	a, init, err := initialize(ctx, k.launch, quiet{}, k.Dialect, slog.With("agent", k.Name, "for", "listing"))
	if err != nil {
		return FoundPage{}, fmt.Errorf("couldn't start %s: %w", k.Title, k.explain(err))
	}
	defer a.Close() //nolint:errcheck // a lister, stopped when done
	if !lists(init) {
		return FoundPage{}, nil
	}
	ours, err := s.ownSessions()
	if err != nil {
		return FoundPage{}, err
	}
	resolved := git.RealPath(folder)
	paths := map[string]string{} // a cwd's real path, once looked up
	page := FoundPage{CanList: true, SeesOpen: k.OpenElsewhere != nil, OneWriter: k.OneWriter}
	for calls := 1; ; calls++ {
		resp, err := a.ListSessions(ctx, &acp.ListSessionsRequest{Cwd: resolved, Cursor: cursor})
		if err != nil {
			return FoundPage{}, err
		}
		for _, info := range resp.Sessions {
			id := string(info.SessionID)
			if _, ok := paths[info.Cwd]; !ok {
				paths[info.Cwd] = git.RealPath(info.Cwd)
			}
			if ours[id] || id == "" || folder != "" && paths[info.Cwd] != resolved {
				continue
			}
			page.Sessions = append(page.Sessions, found(info))
		}
		cursor = resp.NextCursor
		if cursor == "" || len(page.Sessions) >= findPage || calls >= findCalls {
			break
		}
	}
	page.Next = cursor
	ids := make([]string, len(page.Sessions))
	for i, f := range page.Sessions {
		ids[i] = f.SessionID
	}
	if k.Forked != nil {
		forks := k.Forked(ids)
		page.Sessions = slices.DeleteFunc(page.Sessions, func(f Found) bool { return forks[f.SessionID] })
	}
	if k.OpenElsewhere != nil {
		open := k.OpenElsewhere(ids)
		for i := range page.Sessions {
			page.Sessions[i].OpenIn = open[page.Sessions[i].SessionID]
		}
	}
	slices.SortStableFunc(page.Sessions, func(a, b Found) int { return b.Updated.Compare(a.Updated) })
	return page, nil
}

// found reads what the agent tells of a session.
func found(info acp.SessionInfo) Found {
	f := Found{SessionID: string(info.SessionID), Title: info.Title, Folder: info.Cwd}
	f.Updated, _ = time.Parse(time.RFC3339, info.UpdatedAt)
	if n, ok := info.Meta["messageCount"].(float64); ok && n > 0 {
		f.Messages = int(n)
	}
	_, err := os.Stat(info.Cwd)
	f.FolderGone = errors.Is(err, fs.ErrNotExist)
	return f
}

// lists says whether the agent lists sessions and reopens them.
func lists(init *acp.InitializeResponse) bool {
	caps := init.AgentCapabilities
	return caps != nil && caps.LoadSession && caps.SessionCapabilities != nil && caps.SessionCapabilities.List != nil
}

// ownSessions returns the agent sessions that are Nushi's: every chat's,
// those it had before a move or rewind, side chats and the throwaway forks
// not yet deleted.
func (s *Service) ownSessions() (map[string]bool, error) {
	stored, err := s.sessions.Sessions()
	if err != nil {
		return nil, err
	}
	own := map[string]bool{}
	for _, sess := range stored {
		own[sess.SessionID] = true
		for _, e := range sess.Earlier {
			own[e.ID] = true
		}
		for _, id := range sess.Throwaway {
			own[id] = true
		}
	}
	s.mu.Lock()
	chats := slices.Collect(maps.Values(s.chats))
	s.mu.Unlock()
	for _, c := range chats {
		c.mu.Lock()
		own[c.sid] = true
		for id := range c.sides {
			own[id] = true
		}
		for id := range c.probes {
			own[id] = true
		}
		c.mu.Unlock()
	}
	return own, nil
}

// quiet answers an agent that has no session open: there's nothing to ask
// the user about.
type quiet struct{ acp.UnimplementedClient }

func (quiet) RequestPermission(context.Context, *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	return nil, errors.New("no session is open")
}

func (quiet) CreateElicitation(context.Context, *acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
	return nil, errors.New("no session is open")
}
