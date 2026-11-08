package servers

import (
	"bytes"
	"errors"
	"slices"
)

// A server's log is its output as its terminal wrote it, escapes and
// colours kept, for the logs drawer (WatchServerLog, ADR 0100): the last
// logBytes while it runs (its terminal keeps more), and as much once it
// ended, for the PerFolder ended servers a folder keeps.

// logBytes is how much of a server's output its log holds.
const logBytes = 256 << 10

// logTail is the last logBytes of raw, from a line's start when one
// starts near the cut; never nil.
func logTail(raw []byte) []byte {
	if len(raw) <= logBytes {
		return append([]byte{}, raw...)
	}
	cut := len(raw) - logBytes
	if i := bytes.IndexByte(raw[cut:], '\n'); i >= 0 && i < 4096 {
		cut += i + 1
	}
	return bytes.Clone(raw[cut:])
}

// errNoLog is a server that isn't the chat's folder's, or whose log is
// gone (the folder kept PerFolder ended servers since).
var errNoLog = errors.New("no such server's output is kept in this chat's folder")

// errNotYet is a server whose program hasn't started.
var errNotYet = errors.New("the server's program hasn't started yet")

// logged is the server of id in a chat's folder, live or ended.
func (s *Service) logged(chatID, id string) (*server, error) {
	folder, _, err := s.place(chatID)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	is := func(sv *server) bool { return sv.id == id && sv.folder == folder }
	if i := slices.IndexFunc(s.alive, is); i >= 0 {
		if s.alive[i].proc == nil {
			return nil, errNotYet
		}
		return s.alive[i], nil
	}
	if i := slices.IndexFunc(s.ended, is); i >= 0 && s.ended[i].log != nil {
		return s.ended[i], nil
	}
	return nil, errNoLog
}

// Watch gives fn a server of a chat's folder's output (Row.LogID): its
// log, then what it writes as it comes, until it ends (ended), stop is
// closed, fn returns false or fn falls too far behind (the terminal drops
// it). An ended server's is its log alone.
func (s *Service) Watch(chatID, serverID string, stop <-chan struct{}, fn func([]byte) bool) (ended bool, err error) {
	sv, err := s.logged(chatID, serverID)
	if err != nil {
		return false, err
	}
	s.mu.Lock()
	log, proc := sv.log, sv.proc
	s.mu.Unlock()
	if log != nil { // it ended
		return fn(log), nil // false: fn is gone, and hears no end
	}
	if proc == nil { // it ended before its program started: nothing to give
		return false, errNoLog
	}
	first, more := true, true
	proc.Attach(stop, func(b []byte) bool {
		if first {
			first, b = false, logTail(b)
		}
		more = fn(b)
		return more
	})
	select {
	case <-proc.Done():
		return more, nil
	default:
		return false, nil
	}
}

// tail is a server's output as plain text, at most so many of its last
// lines and size bytes: an ended one's log, a live one's terminal.
func (s *Service) tail(sv *server, lines, size int) string {
	s.mu.Lock()
	log, proc := sv.log, sv.proc
	s.mu.Unlock()
	if log == nil && proc != nil {
		log = logTail(written(proc))
	}
	return lastLines(log, lines, size)
}
