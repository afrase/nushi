package servers

import (
	"crypto/rand"
	"slices"
	"strconv"
	"strings"
	"time"
	"unicode"

	"github.com/afrase/nushi/internal/launchfile"
)

// The asks to run an agent's preview_start (ADR 0100): the harness asks
// before each call, and the card shows the command the named entry runs
// (Command). Each ask keeps the hash of the entry it showed until the
// user answers it (Answered): a refused or cancelled one goes, an allowed
// one holds the start that follows, which takes the first allowed ask of
// its chat and name and runs only that entry as shown.

// ask is a chat's ask to run the entry of a name.
type ask struct {
	id, chat string
	name     string    // without case; "" when the card couldn't tell which (none, or one no entry can have), and it holds any start of the chat
	hash     string    // the entry's as the card showed it; noEntry when none could run
	allowed  time.Time // when the user allowed it; zero while the card waits
}

// noEntry is an ask's hash when no entry of its name could run, and the
// card said the start would be refused: no entry's hash is it, so the
// start is, whatever the file says by then.
const noEntry = "none"

// allowedFor is how long an allowed ask holds a start: the harness runs a
// call once it's allowed, so an older one is a call that never came (its
// agent stopped), whose ask would refuse the next start for nothing.
const allowedFor = 10 * time.Minute

// Command is the command a chat's folder's entry of name runs, as Start
// would run it, for the card that asks to run the agent's preview_start:
// the entry's env, the program as the login shell's PATH finds it, its
// arguments, each quoted so a control or bidi character shows; "" when no
// entry fit for the agent has the name, or it runs nothing. It keeps the
// ask, and its id goes to Answered with the user's answer.
func (s *Service) Command(chatID, name string) (command, askID string) {
	a := ask{id: rand.Text()[:12], chat: chatID, name: strings.ToLower(name), hash: noEntry}
	if !launchfile.ValidName(name) {
		// No entry can have it (a name masked on the card, say), so the
		// card says none runs, and the ask holds any start of the chat to
		// that: one under the real name is refused, not run unchecked.
		a.name = ""
	}
	if e, ok := s.runnable(chatID, name); ok {
		a.hash, command = e.Hash, s.commandLine(e)
	}
	s.mu.Lock()
	s.asks = append(s.asks, a)
	s.mu.Unlock()
	return command, a.id
}

// runnable is the entry of name a chat's agent could start.
func (s *Service) runnable(chatID, name string) (launchfile.Entry, bool) {
	if !launchfile.ValidName(name) {
		return launchfile.Entry{}, false
	}
	folder, main, err := s.place(chatID)
	if err != nil {
		return launchfile.Entry{}, false
	}
	l, err := launchfile.Read(folder, main)
	if err != nil {
		return launchfile.Entry{}, false
	}
	i := slices.IndexFunc(l.Entries, func(e launchfile.Entry) bool { return strings.EqualFold(e.Name, name) })
	if i < 0 || !launchfile.ValidName(l.Entries[i].Name) || l.Entries[i].Problem != "" || l.Entries[i].Command == "" {
		return launchfile.Entry{}, false
	}
	return l.Entries[i], true
}

// commandLine is e's command as the card shows it.
func (s *Service) commandLine(e launchfile.Entry) string {
	program, _ := resolve(e, s.Env.Environ())
	if program == "" {
		program = e.Command
	}
	parts := make([]string, 0, len(e.Env)+1+len(e.Args))
	for k, v := range e.Env {
		parts = append(parts, quote(k)+"="+quote(v))
	}
	slices.Sort(parts)
	parts = append(parts, quote(program))
	for _, a := range e.Args {
		parts = append(parts, quote(a))
	}
	return strings.Join(parts, " ")
}

// Answered takes the user's answer to the ask of id, before the agent
// hears it: a refused or cancelled ask goes, an allowed one waits for its
// start (takeAsked).
func (s *Service) Answered(askID string, allowed bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	i := slices.IndexFunc(s.asks, func(a ask) bool { return a.id == askID })
	switch {
	case i < 0:
	case allowed:
		s.asks[i].allowed = time.Now()
	default:
		s.asks = slices.Delete(s.asks, i, i+1)
	}
}

// takeAsked is the hash of the ask of a chat's to run name that the user
// allowed last, and forgets that one ask: a start runs the entry as the
// newest card showed it, and each start takes one ask, so two calls
// allowed at once each keep theirs. An older one whose call never came
// waits out allowedFor, refusing a later start if the file changed since.
// "" when none was allowed (the harness didn't ask: the user allowed the
// tool).
func (s *Service) takeAsked(chatID, name string) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	s.asks = slices.DeleteFunc(s.asks, func(a ask) bool { return !a.allowed.IsZero() && now.Sub(a.allowed) > allowedFor })
	name = strings.ToLower(name)
	held := func(a ask) bool { return a.chat == chatID && !a.allowed.IsZero() && (a.name == name || a.name == "") }
	newest := -1
	for i, a := range s.asks {
		if held(a) && (newest < 0 || !a.allowed.Before(s.asks[newest].allowed)) {
			newest = i
		}
	}
	if newest < 0 {
		return ""
	}
	h := s.asks[newest].hash
	s.asks = slices.Delete(s.asks, newest, newest+1)
	return h
}

// forget drops a removed chat's asks.
func (s *Service) forget(chatID string) {
	s.mu.Lock()
	s.asks = slices.DeleteFunc(s.asks, func(a ask) bool { return a.chat == chatID })
	s.mu.Unlock()
}

// quote is s for the card: bare when plain, else in single quotes as a
// shell takes it, or in Go's escaped form when it holds what wouldn't
// show (control, format and bidi characters), so the card can't be made
// to read as another command.
func quote(s string) string {
	if s != "" && strings.Trim(s, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-") == "" {
		return s
	}
	if strings.ContainsFunc(s, func(r rune) bool { return !unicode.IsGraphic(r) || unicode.Is(unicode.Cf, r) }) {
		return strconv.QuoteToASCII(s)
	}
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}
