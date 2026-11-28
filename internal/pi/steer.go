package pi

import (
	"context"
	"slices"
	"strings"

	acp "github.com/afrase/acp-go/unstable"
)

// steered is a steer pi has queued: taken says, once known, whether pi
// brought it into the run.
type steered struct {
	text  string
	taken chan bool
}

// steer hands text to the running turn, which takes it after the tools
// running now, and says whether pi brought it into the run: false when
// no turn runs (a stopped one that waits for pi's abort, or one ending,
// doesn't), and when the turn ended with it still queued (unqueue), so
// the client sends it again as a prompt; the chat puts it back in its
// queue after a Stop. The answer waits for pi's word. One of
// ownCommands isn't taken: it waits for the turn to end, then runs as
// the next.
func (s *session) steer(ctx context.Context, text string, images []image) (bool, error) {
	s.mu.Lock()
	running, idle := s.turn != nil && !s.turn.answered && !s.turn.closing, s.idle
	s.mu.Unlock()
	if !running {
		return false, nil
	}
	if _, _, own := ownCommand(text); own { // a turn of its own, once this one ends
		if waits := steerWaits.Load(); waits != nil {
			(*waits)()
		}
		select {
		case <-idle:
		case <-s.ended:
		case <-ctx.Done():
		}
		return false, nil
	}
	st, err := s.queueSteer(ctx, text, images)
	if st == nil || err != nil {
		return false, err
	}
	select {
	case taken := <-st.taken:
		return taken, nil
	case <-ctx.Done():
		return false, ctx.Err()
	}
}

// queueSteer has pi queue text for the running turn: nil when the turn
// has ended or its end has begun.
func (s *session) queueSteer(ctx context.Context, text string, images []image) (*steered, error) {
	s.steerMu.Lock()
	defer s.steerMu.Unlock()
	s.mu.Lock()
	if t := s.turn; t == nil || t.answered || t.closing {
		s.mu.Unlock()
		return nil, nil //nolint:nilnil // no turn takes it: the caller's false
	}
	st := &steered{text: text, taken: make(chan bool, 1)}
	s.steers = append(s.steers, st) // before the write: pi may bring it in before its answer is read
	s.mu.Unlock()
	if err := s.p.call(ctx, map[string]any{"type": "steer", "message": text, "images": images}, nil); err != nil {
		s.mu.Lock()
		s.steers = slices.DeleteFunc(s.steers, func(o *steered) bool { return o == st })
		s.mu.Unlock()
		return nil, err
	}
	return st, nil
}

// tookLocked follows the user's messages pi brings into the turn: the
// one the turn began with first, then its steers, in the order queued.
// A steer pi changed on the way (a template it expanded) isn't matched
// here: its turn's end counts it (unqueue).
func (s *session) tookLocked(m *message) {
	t := s.turn
	if t == nil {
		return
	}
	if !t.own {
		t.own = true
		return
	}
	if len(s.steers) > 0 && userText(m) == s.steers[0].text {
		s.steers[0].taken <- true
		s.steers = s.steers[1:]
	}
}

// userText is the text of a user's message as the bridge sent it.
func userText(m *message) string {
	var b strings.Builder
	for _, bl := range m.blocks() {
		if bl.Type == "text" {
			b.WriteString(bl.Text)
		}
	}
	return b.String()
}

// unqueue begins turn t's end: no steer joins it from now, and the steers
// pi hasn't brought into its run are cleared from pi's queue
// (clear_queue), so they can't reach the model a turn late (PiG 0.8.0
// brings a steer left queued into the next run, after that run's own
// prompt; docs/facts/pig.md), and answered as not taken. PiG 0.5.3 has
// brought every one in by then, and clears nothing. clear_queue answers
// what it cleared: the last ones queued; any before them pi brought in
// unmatched (tookLocked).
//
//nolint:contextcheck // the clear goes out on its own: a turn's end, not a request, needs it
func (s *session) unqueue(t *turn) {
	s.steerMu.Lock()
	defer s.steerMu.Unlock()
	s.mu.Lock()
	t.closing = true
	n := len(s.steers)
	s.mu.Unlock()
	if n == 0 {
		return
	}
	var r struct {
		Steering []string `json:"steering"`
	}
	ctx, cancel := context.WithTimeout(context.Background(), clearWait)
	err := s.p.call(ctx, map[string]any{"type": "clear_queue"}, &r)
	cancel()
	s.mu.Lock()
	defer s.mu.Unlock()
	taken := 0 // pi gone or no answer: none known to have reached the model
	if err == nil {
		taken = max(len(s.steers)-len(r.Steering), 0)
	} else {
		warnf("clearing the steers a turn left: %v", err)
	}
	s.answerSteersLocked(taken)
}

// answerSteersLocked answers the steers still queued: the first taken as
// brought in, the rest as not.
func (s *session) answerSteersLocked(taken int) {
	for i, st := range s.steers {
		st.taken <- i < taken
	}
	s.steers = nil
}

// end ends turn t as endLocked does, once pi's queue holds nothing of it
// (unqueue).
func (s *session) end(t *turn, resp *acp.PromptResponse, err error) {
	s.unqueue(t)
	s.mu.Lock()
	defer s.mu.Unlock()
	s.endLocked(t, resp, err)
}
