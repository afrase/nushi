package sessions

import "os"

// LastRecord returns the uuid of the last record of a message in session
// id's transcript, to fork at it (ForkOptions.UpTo): messageID is a user
// or assistant record's uuid, or an assistant message's API id (the CLI
// writes one record per content block, all with that id). Every record
// counts, on abandoned branches and from before a compaction too, but a
// subagent's. An error matching fs.ErrNotExist says the session or the
// message isn't there.
func (s Store) LastRecord(id, cwd, messageID string) (string, error) {
	path, err := s.find(id, cwd)
	if err != nil {
		return "", err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	var last string
	for _, e := range parseEntries(data) {
		switch {
		case e.sidechain || e.typ != "user" && e.typ != "assistant":
		case e.uuid == messageID:
			return e.uuid, nil
		case e.typ == "assistant" && e.msgID == messageID:
			last = e.uuid
		}
	}
	if last == "" {
		return "", notFound("message " + messageID + " of session " + id)
	}
	return last, nil
}
