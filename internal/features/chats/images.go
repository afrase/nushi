package chats

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"slices"

	"github.com/afrase/nushi/internal/imagesize"
	"github.com/afrase/nushi/internal/model"
)

// An awake chat holds an image its transcript copy has, past
// model.SmallImage, as a reference (ADR 0105): its hash, length and
// pixels, the bytes left to the copy's file. Whatever needs the bytes
// reads them back (withBytes): GetChatImage, a client that takes images
// inline, a message sent again, a fork's copy in another chat's folder.
// An image the copy doesn't have yet keeps its bytes until it does.

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

// unrefLocked reads back every image the chat holds as a reference: its
// copy is about to go. One that can't be read stays a reference, with a
// warning.
func (c *chat) unrefLocked() {
	for i := range c.items {
		imgs, err := c.imagesWithBytes(c.items[i].Images)
		if err != nil {
			c.logLocked().Warn("an image held as a reference not read back before its copy goes", "item", c.items[i].ID, "err", err)
			continue
		}
		c.items[i].Images = imgs
	}
}

// withBytes is img with its bytes: its own, or read back from the chat's
// copy. It needs none of the chat's state but its id and copies, which
// never change, so it runs without the chat's lock. An image the copy
// can't give is an error, never one without bytes.
func (c *chat) withBytes(img model.Image) (model.Image, error) {
	if img.Data != nil {
		return img, nil
	}
	if c.copies == nil || img.Hash == "" {
		return model.Image{}, errors.New("an image without its bytes or a transcript copy to read them from")
	}
	data, err := c.copies.ImageData(c.id, img.Hash, img.Size)
	if err != nil {
		return model.Image{}, fmt.Errorf("image %.12s: %w", img.Hash, err)
	}
	img.Data, img.Size = data, int64(len(data))
	return img, nil
}

// imagesWithBytes is images, each withBytes: the same slice when all have
// theirs, else a new one.
func (c *chat) imagesWithBytes(images []model.Image) ([]model.Image, error) {
	if !slices.ContainsFunc(images, func(img model.Image) bool { return img.Data == nil }) {
		return images, nil
	}
	out := make([]model.Image, len(images))
	for i, img := range images {
		var err error
		if out[i], err = c.withBytes(img); err != nil {
			return nil, err
		}
	}
	return out, nil
}

// itemsWithBytes gives items (the caller's) their images' bytes, in place.
func (c *chat) itemsWithBytes(items []model.Item) error {
	for i := range items {
		imgs, err := c.imagesWithBytes(items[i].Images)
		if err != nil {
			return err
		}
		items[i].Images = imgs
	}
	return nil
}

// Inline gives items, the caller's copies of the chat's, the bytes of the
// images held as references, for a client that takes images inline (it
// didn't ask for references, ADR 0099). One the copy can't give stays a
// reference, with a warning: the client shows it failed, and nothing goes
// as an image's bytes that isn't.
func (s *Service) Inline(chatID string, items []model.Item) {
	var c *chat
	for i := range items {
		if !slices.ContainsFunc(items[i].Images, func(img model.Image) bool { return img.Data == nil }) {
			continue
		}
		if c == nil {
			var err error
			if c, err = s.find(chatID); err != nil {
				slog.Warn("images not read back: no such chat", "chat", chatID, "err", err)
				return
			}
		}
		out := slices.Clone(items[i].Images) // the chat's may be shared
		for j, img := range out {
			got, err := c.withBytes(img)
			if err != nil {
				c.log().Warn("an image held as a reference not read back for a client", "item", items[i].ID, "err", err)
				continue
			}
			out[j] = got
		}
		items[i].Images = out
	}
}

// Image returns the image of one of the chat's items whose bytes hash to
// hash: only the chat's own, so a hash never reaches another chat's image
// or a file. Each image's hash was taken as it came in, so this only
// compares them under the chat's lock, and reads one held as a reference
// after it; one made without it (none should be) is hashed after the
// lock, so a chat of many screenshots isn't held while they are.
func (s *Service) Image(chatID, hash string) (model.Image, error) {
	c, err := s.open(chatID)
	if err != nil {
		return model.Image{}, err
	}
	var unhashed []model.Image
	c.mu.Lock()
	if c.inCopy {
		img, err := c.copyImageLocked(hash)
		c.mu.Unlock()
		if err != nil {
			return model.Image{}, err
		}
		return c.fetched(img)
	}
	for i := range c.items {
		for _, img := range c.items[i].Images {
			switch img.Hash {
			case hash:
				c.mu.Unlock()
				return c.fetched(img)
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

// fetched is img withBytes for a client that asked for it by its hash;
// one its copy lost is logged as well as refused.
func (c *chat) fetched(img model.Image) (model.Image, error) {
	got, err := c.withBytes(img)
	if err != nil {
		c.log().Warn("an image asked for couldn't be read back", "err", err)
	}
	return got, err
}

// copyImageLocked is Image for a chat whose items were let go: the image
// as the copy's heads name it, without its bytes (letgo.go).
func (c *chat) copyImageLocked(hash string) (model.Image, error) {
	heads, err := c.copies.Heads(c.id)
	if err != nil {
		return model.Image{}, err
	}
	for _, h := range heads {
		if i := slices.IndexFunc(h.Images, func(img model.Image) bool { return img.Hash == hash }); i >= 0 {
			return h.Images[i], nil
		}
	}
	return model.Image{}, ErrNoImage
}
