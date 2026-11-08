package chats

import (
	"errors"
	"fmt"
	"slices"

	"github.com/afrase/nushi/internal/model"
)

// ErrColor is SetColor's refusal of a name that isn't one of chatColors.
var ErrColor = errors.New("not a chat color")

// chatColors are the names a chat's color can have: the app's ChatColor, the
// Chat message's color. A name reaches the daemon from any client, so only
// these are kept.
var chatColors = []string{"blue", "teal", "violet", "amber", "rust", "magenta", "slate", "green"}

// SetColor sets a chat's color; "" clears it. A forked or kept side chat
// starts with its chat's (forkRecord). Saving tells the clients.
func (s *Service) SetColor(chatID, color string) error {
	if color != "" && !slices.Contains(chatColors, color) {
		return ErrColor // says nothing of the name: it's the client's text
	}
	c, err := s.listed(chatID)
	if err != nil {
		return fmt.Errorf("setting the chat's color: %w", err)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.saveLocked(func(s *model.ChatRecord) { s.Color = color })
	return nil
}
