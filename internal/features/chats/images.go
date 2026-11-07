package chats

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"

	"github.com/afrase/nushi/internal/model"
)

// ErrNoImage is an image asked for by a hash none of the chat's items has.
var ErrNoImage = errors.New("no such image in this chat")

// ImageHash is the lowercase hex SHA-256 of an image's bytes: how a client
// that took a chat's images as references names one (ADR 0099), and how
// the transcript copy names its files.
func ImageHash(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

// Image returns the image of one of the chat's items whose bytes hash to
// hash: only the chat's own, so a hash never reaches another chat's image
// or a file. The items' images are gathered under the chat's lock and
// hashed after it (an item's image bytes are never changed in place), so a
// chat of many screenshots isn't held while they are.
func (s *Service) Image(chatID, hash string) (model.Image, error) {
	c, err := s.open(chatID)
	if err != nil {
		return model.Image{}, err
	}
	var images []model.Image
	c.mu.Lock()
	for i := range c.items {
		images = append(images, c.items[i].Images...)
	}
	c.mu.Unlock()
	for _, img := range images {
		if ImageHash(img.Data) == hash {
			return img, nil
		}
	}
	return model.Image{}, ErrNoImage
}
