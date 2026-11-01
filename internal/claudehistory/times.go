package claudehistory

import (
	"encoding/json"
	"os"
	"time"
)

// MessageTimes says when Claude wrote each message of session id's transcript in
// folder's history, by the id ACP gives it: the API's message id for its
// own (the first of the records one is split into), the record's uuid for
// the user's. Empty when the transcript can't be read; what it could read
// of one that ends short.
func (l Local) MessageTimes(id, folder string) map[string]time.Time {
	src, _, err := paths(l.Projects, id, folder, folder)
	if err != nil {
		return nil
	}
	f, err := os.Open(src)
	if err != nil {
		return nil
	}
	defer f.Close() //nolint:errcheck // read-only
	out := map[string]time.Time{}
	for d := json.NewDecoder(f); ; { // not by line: a record with an image can be long
		var r struct {
			Type      string    `json:"type"`
			UUID      string    `json:"uuid"`
			Timestamp time.Time `json:"timestamp"`
			Message   struct {
				ID string `json:"id"`
			} `json:"message"`
		}
		if d.Decode(&r) != nil {
			return out
		}
		key := r.UUID
		if r.Type == "assistant" {
			key = r.Message.ID
		} else if r.Type != "user" {
			continue
		}
		if _, seen := out[key]; !seen && key != "" && !r.Timestamp.IsZero() {
			out[key] = r.Timestamp
		}
	}
}
