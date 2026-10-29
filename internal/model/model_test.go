package model

import (
	"encoding/json"
	"strings"
	"testing"
)

// Fields renamed to the glossary's words keep their JSON names: chats'
// files and Nushi's transcript copies written before still read, and what
// is written now reads in an older daemon.
func TestRenamedFieldsKeepTheirJSONNames(t *testing.T) {
	it := Item{ToSubagentName: "Explore", ToSubagent: "a1", ToSubagentState: "relayed", PassedOnBy: "sm1", ToSubagentStop: true,
		BackgroundCommand: &BackgroundCommand{ID: "b1"}}
	b, err := json.Marshal(it)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{`"RelayTo":"Explore"`, `"RelayCall":"a1"`, `"RelayState":"relayed"`, `"RelayedBy":"sm1"`, `"RelayStop":true`, `"Shell":{"ID":"b1"`} {
		if !strings.Contains(string(b), want) {
			t.Errorf("no %s in %s", want, b)
		}
	}
	var rec ChatRecord
	if err := json.Unmarshal([]byte(`{"ID":"c1","Unseen":true}`), &rec); err != nil || !rec.Done {
		t.Errorf("an older chat's file: %+v %v", rec, err)
	}
	if b, _ := json.Marshal(rec); !strings.Contains(string(b), `"Unseen":true`) {
		t.Errorf("Done written as %s", b)
	}
}
