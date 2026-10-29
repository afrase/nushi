package claudeagent

import (
	"context"
	"errors"
	"iter"
)

// Query is the one-shot form: it starts claude, sends prompt, and yields
// claude's messages up to and including the turn's result; then it
// closes the session. An error ends the sequence: the start's, ctx's, or
// claude's exit before a result. Stopping early closes the session too.
func Query(ctx context.Context, prompt string, o Options) iter.Seq2[Message, error] {
	return func(yield func(Message, error) bool) {
		s, err := Start(ctx, o)
		if err != nil {
			yield(nil, err)
			return
		}
		defer func() { _ = s.Close() }()
		if _, err := s.Send(ctx, UserInput{Text: prompt}); err != nil {
			yield(nil, err)
			return
		}
		for {
			select {
			case <-ctx.Done():
				yield(nil, ctx.Err())
				return
			case m, ok := <-s.Messages():
				if !ok {
					err := s.Wait()
					if err == nil {
						err = errors.New("claudeagent: claude ended before the result")
					}
					yield(nil, err)
					return
				}
				if !yield(m, nil) {
					return
				}
				if _, done := m.(*Result); done {
					return
				}
			}
		}
	}
}
