package claudeagent

import "encoding/json"

// received answers a request from claude. The session handles none yet:
// each is told its subtype is unsupported, which claude takes for a
// missing feature rather than a failure.
func (s *Session) received(raw json.RawMessage) {
	var f struct {
		RequestID string `json:"request_id"`
		Request   struct {
			Subtype string `json:"subtype"`
		} `json:"request"`
	}
	if err := json.Unmarshal(raw, &f); err != nil || f.RequestID == "" {
		s.log.Warn("claude wrote a control request that doesn't decode", "err", err)
		return
	}
	s.handlers.Add(1)
	go func() {
		defer s.handlers.Done()
		_ = s.write(s.ctx, map[string]any{"type": "control_response", "response": map[string]any{
			"subtype": "error", "request_id": f.RequestID, "error": "Unsupported control request subtype: " + f.Request.Subtype,
		}})
	}()
}

// withdrawn has nothing to withdraw: every request is answered at once.
func (s *Session) withdrawn(json.RawMessage) {}
