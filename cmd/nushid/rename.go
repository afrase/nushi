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
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
)

// moveData moves the data folder of the app's old name ("Nushi Next") to
// dir, once: when dir doesn't exist yet and old does. Chats in scratch
// folders get their folders' new paths. It refuses while a daemon still
// listens in old. Then (every start) it moves the agent's history of each
// scratch chat's sessions to where the agent looks for the new path.
func moveData(old, dir, projects string) error {
	if _, err := os.Stat(dir); errors.Is(err, fs.ErrNotExist) {
		if err := renameData(old, dir); err != nil {
			return err
		}
	} else if err != nil {
		return err
	}
	return moveHistory(old, dir, projects)
}

func renameData(old, dir string) error {
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
	moved := func(folder *string) bool {
		rest, ok := strings.CutPrefix(*folder, old+string(filepath.Separator))
		if ok {
			*folder = filepath.Join(dir, rest)
		}
		return ok
	}
	for _, s := range sessions {
		changed := false
		for i := range s.Earlier {
			changed = moved(&s.Earlier[i].Folder) || changed
		}
		if moved(&s.Folder) || changed {
			if err := st.SaveSession(s); err != nil {
				return err
			}
		}
	}
	return nil
}

// moveHistory moves the agent's history of the scratch chats' sessions from
// their folders' old paths to their new ones. Before, it was copied, under
// the same id: the agent found either copy, the old one first. A copy the
// new one holds all of goes.
func moveHistory(old, dir, projects string) error {
	sessions, err := store.New(dir).Sessions()
	if err != nil {
		return err
	}
	scratch := filepath.Join(dir, "scratch") + string(filepath.Separator)
	for _, s := range sessions {
		for _, sess := range append(s.Earlier, model.AgentSession{ID: s.SessionID, Folder: s.Folder}) {
			if rest, ok := strings.CutPrefix(sess.Folder, scratch); ok {
				if err := claudehistory.Move(projects, sess.ID, filepath.Join(old, "scratch", rest), sess.Folder); err != nil {
					log.Printf("session %s: %v", sess.ID, err)
				}
			}
		}
	}
	return nil
}
