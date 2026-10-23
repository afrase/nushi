package main

import (
	"errors"
	"fmt"
	"io/fs"
	"log"
	"net"
	"os"
	"path/filepath"
	"strings"

	"github.com/afrase/nushi/internal/claudehistory"
	"github.com/afrase/nushi/internal/store"
)

// moveData moves the data folder of the app's old name ("Nushi Next") to
// dir, once: when dir doesn't exist yet and old does. Chats in scratch
// folders get their folders' new paths, and the agent's history of each of
// their sessions is copied to where the agent looks for the new path (the
// old copy stays). It refuses while a daemon still listens in old.
func moveData(old, dir, projects string) error {
	if _, err := os.Stat(dir); !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	if _, err := os.Stat(old); errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if c, err := net.Dial("unix", filepath.Join(old, "nushid.sock")); err == nil {
		c.Close()
		return fmt.Errorf("a daemon still runs in %s", old)
	}
	if err := os.Rename(old, dir); err != nil {
		return err
	}
	log.Printf("moved %s to %s", old, dir)
	st := store.New(dir)
	sessions, err := st.Sessions()
	if err != nil {
		return err
	}
	moved := func(id string, folder *string) bool {
		rest, ok := strings.CutPrefix(*folder, old+string(filepath.Separator))
		if !ok {
			return false
		}
		to := filepath.Join(dir, rest)
		if _, err := claudehistory.Copy(projects, id, *folder, to); err != nil {
			log.Printf("session %s: %v", id, err) // an empty session has no history
		}
		*folder = to
		return true
	}
	for _, s := range sessions {
		changed := false
		for i := range s.Earlier {
			changed = moved(s.Earlier[i].ID, &s.Earlier[i].Folder) || changed
		}
		if moved(s.SessionID, &s.Folder) || changed {
			if err := st.SaveSession(s); err != nil {
				return err
			}
		}
	}
	return nil
}
