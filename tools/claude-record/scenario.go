package main

import (
	"encoding/json"
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"time"
)

// clientScript is a scenario's client.json: what the recorder, as Nushi,
// sends the agent and when (the scenarios' README says it in full).
type clientScript struct {
	// Timeout bounds each wait; "" is a minute.
	Timeout string `json:"timeout,omitempty"`
	Steps   []step `json:"steps"`
}

// step is one thing the client does; exactly one of its verbs is set.
// Sessions are named by the scenario (New, Fork's As) and given by name;
// "$<name>" in Params is the session's id, "$cwd" the folder sessions
// run in.
type step struct {
	Initialize json.RawMessage `json:"initialize,omitempty"` // {} sends Nushi's; params otherwise
	New        string          `json:"new,omitempty"`        // session/new, named so
	Load       string          `json:"load,omitempty"`       // session/load of this session
	Resume     string          `json:"resume,omitempty"`     // session/resume
	Fork       string          `json:"fork,omitempty"`       // session/fork; As names the fork
	List       json.RawMessage `json:"list,omitempty"`       // session/list in $cwd
	Close      string          `json:"close,omitempty"`      // session/close
	Delete     string          `json:"delete,omitempty"`     // session/delete
	Prompt     string          `json:"prompt,omitempty"`     // session/prompt of this text on Session
	Steer      string          `json:"steer,omitempty"`      // _session/steering of this text on Session
	Cancel     string          `json:"cancel,omitempty"`     // session/cancel of this session
	Request    string          `json:"request,omitempty"`    // any request, with Params
	Notify     string          `json:"notify,omitempty"`     // any notification, with Params
	Answer     string          `json:"answer,omitempty"`     // the method of the agent's next request to answer
	Await      string          `json:"await,omitempty"`      // the Async request to wait for
	WaitFor    json.RawMessage `json:"waitFor,omitempty"`    // a message from the agent to wait for
	Pause      string          `json:"pause,omitempty"`      // a wait of this long (a duration)

	Session     string          `json:"session,omitempty"`     // Prompt's and Steer's session
	As          string          `json:"as,omitempty"`          // Fork's name for the fork
	Meta        json.RawMessage `json:"meta,omitempty"`        // joins a session request's _meta (Nushi's)
	Params      json.RawMessage `json:"params,omitempty"`      // Request's and Notify's
	Async       string          `json:"async,omitempty"`       // don't wait for the answer; Await waits for it by this name
	ExpectError bool            `json:"expectError,omitempty"` // the request's answer is an error
	Option      string          `json:"option,omitempty"`      // Answer's permission option: its kind or id, or "cancelled"
	Result      json.RawMessage `json:"result,omitempty"`      // Answer's result, as it is
}

// verb is the step's verb, for messages.
func (s *step) verb() string {
	verbs := map[string]bool{
		"initialize": s.Initialize != nil, "new": s.New != "", "load": s.Load != "", "resume": s.Resume != "",
		"fork": s.Fork != "", "list": s.List != nil, "close": s.Close != "", "delete": s.Delete != "",
		"prompt": s.Prompt != "", "steer": s.Steer != "", "cancel": s.Cancel != "", "request": s.Request != "",
		"notify": s.Notify != "", "answer": s.Answer != "", "await": s.Await != "", "waitFor": s.WaitFor != nil,
		"pause": s.Pause != "",
	}
	var out string
	for _, v := range slices.Sorted(maps.Keys(verbs)) {
		if verbs[v] {
			if out != "" {
				return "" // more than one
			}
			out = v
		}
	}
	return out
}

// loadClient reads dir's client.json and checks each step has one verb.
func loadClient(dir string) (*clientScript, time.Duration, error) {
	path := filepath.Join(dir, "client.json")
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, 0, err
	}
	var c clientScript
	if err := json.Unmarshal(b, &c); err != nil {
		return nil, 0, fmt.Errorf("%s: %w", path, err)
	}
	timeout := time.Minute
	if c.Timeout != "" {
		if timeout, err = time.ParseDuration(c.Timeout); err != nil {
			return nil, 0, fmt.Errorf("%s: timeout: %w", path, err)
		}
	}
	for i := range c.Steps {
		s := &c.Steps[i]
		switch s.verb() {
		case "":
			return nil, 0, fmt.Errorf("%s: step %d has no verb, or more than one", path, i+1)
		case "prompt", "steer":
			if s.Session == "" {
				return nil, 0, fmt.Errorf("%s: step %d: %s without a session", path, i+1, s.verb())
			}
		case "pause":
			if _, err := time.ParseDuration(s.Pause); err != nil {
				return nil, 0, fmt.Errorf("%s: step %d: %w", path, i+1, err)
			}
		}
	}
	return &c, timeout, nil
}
