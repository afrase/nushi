package chats

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"slices"

	"github.com/afrase/nushi/internal/imagesize"
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

// described is img with its hash, length and pixels taken from its bytes,
// where they weren't; one held as a reference has them.
func described(img model.Image) model.Image {
	if img.Ref() {
		return img
	}
	img.Hash, img.Size = HashOf(img), int64(len(img.Data))
	if img.Width == 0 {
		img.Width, img.Height = imagesize.OfBytes(img.Data)
	}
	return img
}

// hashed is images described: a new slice, so the caller's isn't changed
// under it.
func hashed(images []model.Image) []model.Image {
	if len(images) == 0 {
		return images
	}
	out := make([]model.Image, len(images))
	for i, img := range images {
		out[i] = described(img)
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
	if c.inCopy {
		defer c.mu.Unlock()
		return c.copyImageLocked(hash)
	}
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

// copyImageLocked is Image for a chat whose items were let go: only an
// item that has the image is read back from the copy (letgo.go).
func (c *chat) copyImageLocked(hash string) (model.Image, error) {
	heads, err := c.copies.Heads(c.id)
	if err != nil {
		return model.Image{}, err
	}
	var ids []string
	for _, h := range heads {
		if slices.ContainsFunc(h.Images, func(img model.Image) bool { return img.Hash == hash }) {
			ids = append(ids, h.ID)
			break
		}
	}
	found, err := c.copies.Pick(c.id, ids)
	if err != nil {
		return model.Image{}, err
	}
	for _, it := range found {
		if i := slices.IndexFunc(it.Images, func(img model.Image) bool { return img.Hash == hash }); i >= 0 {
			return it.Images[i], nil
		}
	}
	return model.Image{}, ErrNoImage
}
