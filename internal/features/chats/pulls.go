package chats

import (
	"cmp"
	"errors"
	"fmt"
	"regexp"
	"slices"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// A chat's pull requests (ADR 0117): found by its branch's head (they
// follow the branch), opened by one of its tool calls, or linked by hand;
// at most model.MaxPulls. The record keeps them in Pulls, and the first
// in Pull for a release before Pulls (ADR 0108).

// errTooManyPulls refuses one pull request too many picked by hand.
var errTooManyPulls = fmt.Errorf("a chat holds at most %d pull requests", model.MaxPulls)

// setPulls writes a chat's linked pull requests, the first also as Pull.
func setPulls(s *model.ChatRecord, pulls []model.ChatGitHub) {
	s.Pulls, s.Pull = pulls, nil
	if len(pulls) > 0 {
		p := pulls[0]
		s.Pull = &p
	} else {
		s.Pulls = nil
	}
}

// pullIndex is where p is in pulls, -1 when it isn't.
func pullIndex(pulls []model.ChatGitHub, p model.ChatGitHub) int {
	return slices.IndexFunc(pulls, func(q model.ChatGitHub) bool { return q.Same(p) })
}

// startedFrom says p is the pull request the chat was started from.
func startedFrom(r model.ChatRecord, p model.ChatGitHub) bool {
	return r.GitHub != nil && r.GitHub.Pull && r.GitHub.Same(p)
}

// LinkPull links a pull request to a chat: a found one (its Branch set)
// is added unless the user unlinked it; one picked by hand takes the
// primary's place (a chat started from a pull request forgets that one).
// nil unlinks the primary.
func (s *Service) LinkPull(chatID string, pull *model.ChatGitHub) error {
	if pull == nil {
		c, err := s.listed(chatID)
		if err != nil {
			return err
		}
		c.mu.Lock()
		now := c.record.PullLink()
		c.mu.Unlock()
		if now == nil {
			return nil
		}
		return s.UnlinkPull(chatID, *now)
	}
	return s.addPull(chatID, *pull, pull.Branch == "")
}

// AddPull adds a pull request picked by hand to a chat's, after the others.
func (s *Service) AddPull(chatID string, pull model.ChatGitHub) error {
	pull.Branch, pull.Opened = "", false
	return s.addPull(chatID, pull, false)
}

func (s *Service) addPull(chatID string, pull model.ChatGitHub, primary bool) error {
	c, err := s.listed(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.addPullLocked(pull, primary)
}

// addPullLocked adds pull to the chat's pull requests, or as the primary.
// One found or opened that the user unlinked stays out; one picked by
// hand is no longer unlinked. One already there keeps its place
// (updatePullLocked).
func (c *chat) addPullLocked(pull model.ChatGitHub, primary bool) error {
	pull.Pull = true
	byHand := pull.Branch == "" && !pull.Opened
	r := c.record
	if !byHand && r.Unlinked(pull) {
		return nil
	}
	linked := r.LinkedPulls()
	i := pullIndex(linked, pull)
	switch {
	case i >= 0 && !primary:
		c.updatePullLocked(linked, i, pull)
		return nil
	case !primary && startedFrom(r, pull):
		return nil
	case i >= 0:
		linked = slices.Delete(linked, i, i+1)
	}
	count := len(linked)
	if r.GitHub != nil && r.GitHub.Pull && !primary {
		count++
	}
	if count >= model.MaxPulls {
		if byHand {
			return errTooManyPulls
		}
		return nil
	}
	dropGitHub := primary && r.GitHub != nil && r.GitHub.Pull // linked by hand to another
	switch {
	case dropGitHub:
		linked = append([]model.ChatGitHub{pull}, linked...)
	case primary && len(linked) > 0:
		linked[0] = pull // takes the primary's place
	default:
		linked = append(linked, pull)
	}
	c.saveLocked(func(s *model.ChatRecord) {
		setPulls(s, linked)
		if dropGitHub {
			s.GitHub = nil
		}
		if byHand {
			relink(s, pull)
		}
	})
	c.logLocked().Info("pull request linked", "number", pull.Number, "how", linkedHow(pull))
	return nil
}

// updatePullLocked takes what pull says of linked[i], the same one: its
// node id once known, a found one's branch, and that the chat opened it
// (which then stays when the branch changes).
func (c *chat) updatePullLocked(linked []model.ChatGitHub, i int, pull model.ChatGitHub) {
	was := linked[i]
	linked[i].ID = cmp.Or(pull.ID, was.ID)
	if pull.Branch != "" && was.Branch != "" {
		linked[i].Branch = pull.Branch
	}
	if pull.Opened {
		linked[i].Opened, linked[i].Branch = true, ""
	}
	if linked[i] != was {
		c.saveLocked(func(s *model.ChatRecord) { setPulls(s, linked) })
	}
}

// relink forgets that the user unlinked pull: they linked it again.
func relink(s *model.ChatRecord, pull model.ChatGitHub) {
	s.NoPulls = slices.DeleteFunc(s.NoPulls, func(k string) bool { return k == pull.ID || k == pull.Key() })
	if len(s.NoPulls) == 0 {
		s.NoPulls = nil
	}
	if s.NoPull == pull.Number {
		s.NoPull = 0
	}
}

// linkedHow is how a pull request joined the chat, for the log.
func linkedHow(pull model.ChatGitHub) string {
	switch {
	case pull.Opened:
		return "opened in the chat"
	case pull.Branch != "":
		return "found"
	}
	return "by hand"
}

// UnlinkPull unlinks one of a chat's pull requests, remembered so it isn't
// found or opened again: by its node id, and by its address for one
// opened in the chat without one.
func (s *Service) UnlinkPull(chatID string, pull model.ChatGitHub) error {
	c, err := s.listed(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	r := c.record
	linked := r.LinkedPulls()
	i := pullIndex(linked, pull)
	if i < 0 && !startedFrom(r, pull) {
		return errors.New("not one of the chat's pull requests")
	}
	gone := pull
	if i >= 0 {
		gone = linked[i]
		linked = slices.Delete(linked, i, i+1)
	} else {
		gone = *r.GitHub
	}
	keys := []string{gone.Key()}
	for _, id := range []string{gone.ID, pull.ID} {
		if id != "" && !slices.Contains(keys, id) {
			keys = append(keys, id)
		}
	}
	c.saveLocked(func(s *model.ChatRecord) {
		if i < 0 {
			s.GitHub = nil
		}
		setPulls(s, linked)
		for _, k := range keys {
			if !slices.Contains(s.NoPulls, k) {
				s.NoPulls = append(s.NoPulls, k)
			}
		}
		s.NoPull = gone.Number // a release before Pulls doesn't find it again either
	})
	c.logLocked().Info("pull request unlinked")
	return nil
}

// DropFoundPull unlinks the pull requests found for a branch the chat's
// folder is no longer on (one opened in the chat or linked by hand stays).
func (s *Service) DropFoundPull(chatID, branch string) {
	c, err := s.listed(chatID)
	if err != nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	linked := c.record.LinkedPulls()
	kept := slices.DeleteFunc(slices.Clone(linked), func(p model.ChatGitHub) bool { return p.Branch != "" && p.Branch != branch })
	if len(kept) != len(linked) {
		c.saveLocked(func(s *model.ChatRecord) { setPulls(s, kept) })
	}
}

// pullAddressRE is a pull request's address on any host: the host, the
// repository's owner/name and the number.
var pullAddressRE = regexp.MustCompile(`https://([A-Za-z0-9.-]+(?::\d{1,5})?)/([A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._-]{1,100})/pull/(\d{1,9})\b`)

// openedPull is the pull request a completed tool call opened: one that
// ran gh pr create, or a create_pull_request tool (GitHub's MCP server's),
// and the first pull request's address in its output on a host known
// says. A link merely mentioned elsewhere is never taken.
func openedPull(it model.Item, known func(host string) bool) (model.ChatGitHub, bool) {
	if it.Kind != model.ToolCall || it.Status != "completed" {
		return model.ChatGitHub{}, false
	}
	ran := strings.Contains(it.Input, "gh pr create") || strings.Contains(it.Title, "gh pr create")
	tool := strings.Contains(strings.ToLower(it.Tool+" "+it.Title), "create_pull_request")
	if !ran && !tool {
		return model.ChatGitHub{}, false
	}
	for _, out := range []string{it.Text, it.RawOutput} {
		for _, m := range pullAddressRE.FindAllStringSubmatch(out, -1) {
			n, err := strconv.Atoi(m[3])
			host := strings.ToLower(m[1])
			if err != nil || n <= 0 || !known(host) {
				continue
			}
			return model.ChatGitHub{Host: host, Repo: m[2], Number: n, Pull: true, Opened: true}, true
		}
	}
	return model.ChatGitHub{}, false
}

// openedPullLocked links the pull request a tool call of the chat opened
// as it completes (not as a reopen replays it).
func (c *chat) openedPullLocked(it model.Item) {
	if c.replaying || c.quiet || c.parent != nil || c.gitHubHost == nil {
		return
	}
	p, ok := openedPull(it, c.gitHubHost)
	if !ok {
		return
	}
	if err := c.addPullLocked(p, false); err != nil {
		c.logLocked().Info("linking an opened pull request", "err", err)
	}
}
