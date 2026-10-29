package claudeagent

import (
	"regexp"
	"testing"
)

// Request ids are req_<count>_<8 hex>, each new.
func TestRequestIDs(t *testing.T) {
	var s Session
	shape := regexp.MustCompile(`^req_\d+_[0-9a-f]{8}$`)
	seen := map[string]bool{}
	for range 100 {
		id := s.newRequestID()
		if !shape.MatchString(id) || seen[id] {
			t.Fatalf("%s", id)
		}
		seen[id] = true
	}
	if id := s.newRequestID(); id[:8] != "req_101_" {
		t.Errorf("%s", id)
	}
}
