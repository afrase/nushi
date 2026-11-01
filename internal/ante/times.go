package ante

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

// MessageTimes says when session id's messages were saved, from its events.jsonl,
// by the ids a replay gives them: its input's for the user's, the turn's
// and its number in the turn for the agent's (messageID). Empty when the
// file can't be read; what it could read of one that ends short. Not from
// the replay: Ante's host streams those events, and nothing says it keeps
// their times.
func (Local) MessageTimes(id, _ string) map[string]time.Time {
	if !isSessionID(id) {
		return nil
	}
	f, err := os.Open(filepath.Join(Home(), "sessions", id, "events.jsonl")) //nolint:gosec // isSessionID above
	if err != nil {
		return nil
	}
	defer f.Close() //nolint:errcheck // read-only
	out := map[string]time.Time{}
	var turn string
	var msg int
	for d := json.NewDecoder(f); ; {
		var r struct {
			Timestamp time.Time       `json:"timestamp"`
			Event     json.RawMessage `json:"event"`
			Parent    string          `json:"parent"`
		}
		if d.Decode(&r) != nil {
			return out
		}
		name, payload := variant(r.Event)
		switch name {
		case "TurnStart":
			var p struct {
				TurnID string `json:"turn_id"`
			}
			_ = json.Unmarshal(payload, &p)
			turn, msg = p.TurnID, 0
		case "UserInput":
			out[r.Parent] = r.Timestamp
		case "AgentMessage":
			if turn != "" {
				out[turn+"."+strconv.Itoa(msg)] = r.Timestamp
				msg++
			}
		}
	}
}
