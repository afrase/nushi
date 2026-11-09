package transcripts

import (
	"errors"
	"fmt"
	"log/slog"
	"path"

	"github.com/afrase/nushi/internal/imagesize"
	"github.com/afrase/nushi/internal/model"
)

// An item read from a copy holds its larger images as references (ADR
// 0105): their hashes, lengths and pixels, from the record, without their
// bytes, which ImageData reads when something needs them. A small one
// (model.SmallImage at most) comes with its bytes, as the chat holds it.

// withImagesLocked is st as an item, its images as the chat holds them. A
// picture whose file is gone is left out, with a warning; one whose
// record is an older daemon's (no size) has its length and pixels read
// from its file (its header only, for a large one).
func (s *Store) withImagesLocked(chat string, st *stored) model.Item {
	it := st.Item
	for _, p := range st.Pictures {
		img, err := s.pictureLocked(chat, p)
		if err != nil {
			slog.Warn("transcript copy: image left out", "chat", chat, "image", p.Hash, "err", err)
			continue
		}
		it.Images = append(it.Images, img)
	}
	return it
}

// pictureLocked is p as the chat holds it.
func (s *Store) pictureLocked(chat string, p picture) (model.Image, error) {
	if !validHash.MatchString(p.Hash) {
		return model.Image{}, errors.New("not an image's hash")
	}
	img := model.Image{MimeType: p.MimeType, Hash: p.Hash, Size: p.Size, Width: p.Width, Height: p.Height}
	name := path.Join(chat, imagesDir, p.Hash)
	if img.Size == 0 {
		fi, err := s.root.Stat(name)
		if err != nil {
			return model.Image{}, err
		}
		img.Size = fi.Size()
		if img.Size > model.SmallImage {
			f, err := s.root.Open(name)
			if err != nil {
				return model.Image{}, err
			}
			img.Width, img.Height = imagesize.Of(f)
			_ = f.Close()
		}
	}
	if img.Size > model.SmallImage {
		return img, nil
	}
	data, err := s.root.ReadFile(name)
	if err != nil {
		return model.Image{}, err
	}
	switch {
	case p.Size == 0:
		img.Width, img.Height = imagesize.OfBytes(data)
	case int64(len(data)) != p.Size:
		return model.Image{}, fmt.Errorf("the file is %d bytes, not %d", len(data), p.Size)
	}
	img.Data, img.Size = data, int64(len(data))
	return img, nil
}

// ImageData returns the bytes of chat's image of hash, from its file; an
// error when there is none, or its length isn't size (a file cut short:
// never bytes that aren't the image). It reads only that file, without
// the store's lock, so fetching images doesn't wait on writes.
func (s *Store) ImageData(chat, hash string, size int64) ([]byte, error) {
	if err := checkChat(chat); err != nil {
		return nil, err
	}
	if !validHash.MatchString(hash) {
		return nil, errors.New("not an image's hash")
	}
	data, err := s.root.ReadFile(path.Join(chat, imagesDir, hash))
	if err != nil {
		return nil, fmt.Errorf("reading an image of the transcript copy: %w", err)
	}
	if size > 0 && int64(len(data)) != size {
		return nil, fmt.Errorf("an image of the transcript copy is %d bytes, not %d", len(data), size)
	}
	return data, nil
}
