package chats

import "log/slog"

// logLocked is the chat's logger (ADR 0038): its id, agent, session and
// folder on each line; a side chat's name its chat too.
func (c *chat) logLocked() *slog.Logger { return c.logger(c.sid, c.record.Folder) }

// log is logLocked, taking the lock.
func (c *chat) log() *slog.Logger {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.logLocked()
}

// logger is the chat's logger with session sid in folder ("": not known).
func (c *chat) logger(sid, folder string) *slog.Logger {
	args := []any{"chat", c.id, "agent", c.kind.Name}
	if c.parent != nil {
		args = []any{"chat", c.parent.id, "side", c.id, "agent", c.kind.Name}
	}
	if sid != "" {
		args = append(args, "session", sid)
	}
	if folder != "" {
		args = append(args, "folder", folder)
	}
	return slog.With(args...)
}
