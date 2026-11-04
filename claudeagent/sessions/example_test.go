package sessions_test

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/afrase/nushi/claudeagent/sessions"
)

// A Store reads the transcripts claude keeps in its config folder: here a
// throwaway one with one session, as claude writes it.
func ExampleStore_List() {
	config, err := os.MkdirTemp("", "claude-config")
	if err != nil {
		fmt.Println(err)
		return
	}
	defer func() { _ = os.RemoveAll(config) }()
	store := sessions.Store{ConfigDir: config}
	const cwd, id = "/home/me/project", "0f5e2c1a-8b7d-4c3e-9a21-6d4f8e7b3c10"
	transcript := `{"type":"user","uuid":"u1","sessionId":"` + id + `","cwd":"` + cwd + `","message":{"role":"user","content":"Fix the build"}}
{"type":"assistant","uuid":"u2","parentUuid":"u1","sessionId":"` + id + `","message":{"id":"msg_1","role":"assistant","content":[{"type":"text","text":"Done."}]}}
`
	dir := store.ProjectDir(cwd)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		fmt.Println(err)
		return
	}
	if err := os.WriteFile(filepath.Join(dir, id+".jsonl"), []byte(transcript), 0o600); err != nil {
		fmt.Println(err)
		return
	}

	list, err := store.List(cwd, 0, 0)
	if err != nil {
		fmt.Println(err)
		return
	}
	for _, s := range list {
		fmt.Printf("%s %q\n", s.ID, s.Summary)
	}
	messages, err := store.Messages(id, cwd)
	if err != nil {
		fmt.Println(err)
		return
	}
	for _, m := range messages {
		fmt.Println(m.Type, m.UUID)
	}
	// Output:
	// 0f5e2c1a-8b7d-4c3e-9a21-6d4f8e7b3c10 "Fix the build"
	// user u1
	// assistant u2
}
