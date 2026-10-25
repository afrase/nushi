package acptest

import "strings"

// Omp makes an Agent answer as omp 18.12.6 does where Nushi's features
// follow it: it names itself "fake-omp", forks whole sessions, can't delete
// one, and its question has an "Other" field named "<id>__other".

func ompInit() map[string]any {
	return map[string]any{"protocolVersion": 1, "agentInfo": map[string]any{"name": "fake-omp", "title": "omp"},
		"agentCapabilities": map[string]any{"loadSession": true, "promptCapabilities": map[string]any{"image": true},
			"sessionCapabilities": map[string]any{"fork": map[string]any{}, "close": map[string]any{}, "list": map[string]any{}, "resume": map[string]any{}}}}
}

// ompQuestion asks as omp's ask tool does, and says what came back.
func (a *Agent) ompQuestion(session string) {
	res := a.request("elicitation/create", map[string]any{
		"sessionId": session, "mode": "form", "message": "Red or blue?",
		"requestedSchema": map[string]any{"type": "object", "properties": map[string]any{
			"q0":        map[string]any{"type": "string", "title": "Red or blue?", "oneOf": []map[string]any{{"const": "Red", "title": "Red"}, {"const": "Blue", "title": "Blue"}}},
			"q0__other": map[string]any{"type": "string", "title": "Other (type your own)"},
		}},
	})
	a.say(session, "Answer: "+strings.TrimSpace(string(res)))
}
