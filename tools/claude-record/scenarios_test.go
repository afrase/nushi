package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/claudeagent/claudetest/fakeapi"
)

// parity is the parity scenarios' folder.
var parity = filepath.Join("..", "..", "internal", "features", "chats", "testdata", "claude-parity")

// Every parity scenario's scripts load, and name no session before a
// step makes it: they wait for the owner's recording, which shouldn't be
// the first to find a typo.
func TestParityScenariosLoad(t *testing.T) {
	dirs, err := pick(parity, "all")
	if err != nil {
		t.Fatal(err)
	}
	if len(dirs) < 20 {
		t.Errorf("only %d scenarios", len(dirs))
	}
	for _, dir := range dirs {
		if _, err := fakeapi.Load(dir); err != nil {
			t.Error(err)
		}
		if _, _, err := loadClient(dir); err != nil {
			t.Error(err)
		}
	}
}

// The scenarios the fake claude can take run through on it, with Nushi's
// Go agent: their client scripts fit an agent's flow, as far as one that
// asks about every tool and runs none shows.
func TestParityScenariosPlay(t *testing.T) {
	names := []string{"hello", "question", "fork", "list"}
	if os.Getenv("RECORD_TEST_ALL") != "" {
		names = nil
		dirs, _ := pick(parity, "all")
		for _, d := range dirs {
			names = append(names, filepath.Base(d))
		}
	}
	r := testRecorder(t)
	for _, name := range names {
		t.Run(name, func(t *testing.T) {
			b, err := os.ReadFile(filepath.Join(parity, name, "client.json"))
			if err != nil {
				t.Fatal(err)
			}
			var client map[string]any
			if err := json.Unmarshal(b, &client); err != nil {
				t.Fatal(err)
			}
			client["timeout"] = "10s" // the fake answers at once
			b, _ = json.Marshal(client)
			dir := scenario(t, filepath.Join(parity, name), map[string]string{"client.json": string(b)})
			if err := r.record(context.Background(), dir); err != nil {
				t.Fatal(err)
			}
		})
	}
}
