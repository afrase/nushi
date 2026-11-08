package chats

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"

	"github.com/afrase/nushi/internal/model"
)

// ErrNoImage is an image asked for by a hash none of the chat's items has.
var ErrNoImage = errors.New("no such image in this chat")

// imageSum is SHA-256, apart so a test can count the images hashed.
var imageSum = sha256.Sum256

// ImageHash is the lowercase hex SHA-256 of an image's bytes: how a client
// that took a chat's images as references names one (ADR 0099), and how
// the transcript copy names its files.
func ImageHash(data []byte) string {
	sum := imageSum(data)
	return hex.EncodeToString(sum[:])
}

// HashOf is img's hash: the one taken as it came in (model.Image.Hash),
// or, for one made without it, its bytes hashed now.
func HashOf(img model.Image) string {
	if img.Hash != "" {
		return img.Hash
	}
	return ImageHash(img.Data)
}

// hashed is images with their hashes taken (model.Image.Hash): a new
// slice, so the caller's isn't changed under it.
func hashed(images []model.Image) []model.Image {
	if len(images) == 0 {
		return images
	}
	out := make([]model.Image, len(images))
	for i, img := range images {
		img.Hash = HashOf(img)
		out[i] = img
	}
	return out
}

// Image returns the image of one of the chat's items whose bytes hash to
// hash: only the chat's own, so a hash never reaches another chat's image
// or a file. Each image's hash was taken as it came in, so this only
// compares them under the chat's lock; one made without it (none should
// be) is hashed after the lock, so a chat of many screenshots isn't held
// while they are.
func (s *Service) Image(chatID, hash string) (model.Image, error) {
	c, err := s.open(chatID)
	if err != nil {
		return model.Image{}, err
	}
	var unhashed []model.Image
	c.mu.Lock()
	for i := range c.items {
		for _, img := range c.items[i].Images {
			switch img.Hash {
			case hash:
				c.mu.Unlock()
				return img, nil
			case "":
				unhashed = append(unhashed, img)
			}
		}
	}
	c.mu.Unlock()
	for _, img := range unhashed {
		if ImageHash(img.Data) == hash {
			return img, nil
		}
	}
	return model.Image{}, ErrNoImage
}
