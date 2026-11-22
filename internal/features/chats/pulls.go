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

// A chat's pull requests (ADR 0117): found by the head of a branch it
// pushed (they follow the branch; ADR 0059's amendment of 2026-11-16),
// opened by one of its tool calls, or linked by hand; at most
// model.MaxPulls. The record keeps them in Pulls; one written before
// Pulls has its first in Pull, read still, and cleared on the next write.

// errTooManyPulls refuses one pull request too many picked by hand.
var errTooManyPulls = fmt.Errorf("a chat holds at most %d pull requests", model.MaxPulls)

// setPulls writes a chat's linked pull requests, and clears an older
// record's Pull, which they replace.
func setPulls(s *model.ChatRecord, pulls []model.ChatGitHub) {
	s.Pulls, s.Pull = pulls, nil
	if len(pulls) == 0 {
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
		linked[max(0, slices.IndexFunc(linked, func(p model.ChatGitHub) bool { return !p.Done }))] = pull // takes the primary's place
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
	var gone model.ChatGitHub
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
	})
	c.logLocked().Info("pull request unlinked")
	return nil
}

// pullAddressRE is a pull request's address on any host: the host, the
// repository's owner/name and the number.
var pullAddressRE = regexp.MustCompile(`https://([A-Za-z0-9.-]+(?::\d{1,5})?)/([A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._-]{1,100})/pull/(\d{1,9})\b`)

// openedPull is the pull request a completed tool call opened: one whose
// text opensPull says opens one, in any case or spacing, and the first
// pull request's address in its output on a host known says. A link
// merely mentioned elsewhere is never taken.
func openedPull(it model.Item, known func(host string) bool) (model.ChatGitHub, bool) {
	if it.Kind != model.ToolCall || it.Status != "completed" {
		return model.ChatGitHub{}, false
	}
	if !opensPull(callText(it)) {
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
	if c.replaying || c.muted || c.parent != nil || c.gitHubHost == nil {
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

// SawPulls takes what GitHub said of pull requests (states, rows, one read
// whole) as their links' Done in every chat that has them, so the primary
// is the first still open (ADR 0117). No ask of its own: it reads what
// the app asked for anyway (ADR 0045).
func (s *Service) SawPulls(items []model.GitHubItem) {
	done := map[string]bool{} // by node id, and by address
	for _, it := range items {
		if !it.Pull || it.State == "" {
			continue
		}
		d := it.State == "merged" || it.State == "closed"
		done[model.ChatGitHub{GitHubRef: it.GitHubRef}.Key()] = d
		if it.ID != "" {
			done[it.ID] = d
		}
	}
	if len(done) == 0 {
		return
	}
	// The chats open now, and the stored ones whose links it changes.
	s.mu.Lock()
	ids := []string{}
	for id, c := range s.chats {
		if c.parent == nil {
			ids = append(ids, id)
		}
	}
	s.mu.Unlock()
	stored, _ := s.sessions.Sessions()
	for _, r := range stored {
		if !slices.Contains(ids, r.ID) && slices.ContainsFunc(r.LinkedPulls(), func(p model.ChatGitHub) bool {
			d, ok := sawOf(done, p)
			return ok && d != p.Done
		}) {
			ids = append(ids, r.ID)
		}
	}
	for _, id := range ids {
		s.sawPulls(id, done)
	}
}

// sawOf is what done says of p: by its node id, else its address.
func sawOf(done map[string]bool, p model.ChatGitHub) (bool, bool) {
	if d, ok := done[p.ID]; ok && p.ID != "" {
		return d, true
	}
	d, ok := done[p.Key()]
	return d, ok
}

func (s *Service) sawPulls(chatID string, done map[string]bool) {
	c, err := s.listed(chatID)
	if err != nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	linked := c.record.LinkedPulls()
	changed := false
	for i, p := range linked {
		if d, ok := sawOf(done, p); ok && d != p.Done {
			linked[i].Done, changed = d, true
		}
	}
	if changed {
		c.saveLocked(func(s *model.ChatRecord) { setPulls(s, linked) })
	}
}
