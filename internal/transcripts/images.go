package transcripts

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"path"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/imagesize"
	"github.com/afrase/nushi/internal/model"
)

// An item read from a copy holds its larger images as references (ADR
// 0105): their hashes, lengths and pixels, from the record, without their
// bytes, which ImageData reads when something needs them. A small one
// (model.SmallImage at most) comes with its bytes, as the chat holds it.
// An image whose file is gone is left out, with a warning, both reading
// and writing: one lost file mustn't stop the rest of a copy being read
// or written (a move's names, a reopen's write, the items written beside
// it), and the chat's own reference to it fails where its bytes are asked
// for.

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

// pictureLocked is p as the chat holds it. A large one's file is only
// looked at (a stat), not read.
func (s *Store) pictureLocked(chat string, p picture) (model.Image, error) {
	if !validHash.MatchString(p.Hash) {
		return model.Image{}, errors.New("not an image's hash")
	}
	img := model.Image{MimeType: p.MimeType, Hash: p.Hash, Size: p.Size, Width: p.Width, Height: p.Height}
	name := path.Join(chat, imagesDir, p.Hash)
	if img.Size == 0 || img.Size > model.SmallImage {
		fi, err := s.root.Stat(name)
		if err != nil {
			return model.Image{}, err
		}
		if img.Size == 0 {
			img.Size = fi.Size()
			if img.Size > model.SmallImage {
				img.Width, img.Height = s.pixelsLocked(name)
			}
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

// pixelsLocked is the size in pixels of the image file name, from its
// header; none when it can't be read.
func (s *Store) pixelsLocked(name string) (w, h int) {
	f, err := s.root.Open(name)
	if err != nil {
		return 0, 0
	}
	defer func() { _ = f.Close() }()
	return imagesize.Of(f)
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

// storeImagesLocked writes an item's images beside chat's file (each once,
// by its hash) and returns the item as written. An image held as a
// reference (model.Image.Ref) is written only as a record naming one of
// chat's files: one whose file isn't there is left out, with a warning,
// never an empty file in its place.
func (s *Store) storeImagesLocked(chat string, it model.Item) (*stored, error) {
	st := &stored{Item: it}
	st.Images = nil
	for _, img := range it.Images {
		p := picture{MimeType: img.MimeType, Hash: img.Hash, Size: img.Size, Width: img.Width, Height: img.Height}
		if img.Ref() {
			err := s.hasImageLocked(chat, p.Hash)
			if errors.Is(err, fs.ErrNotExist) {
				slog.Warn("transcript copy: an image held as a reference left out, its file gone", "chat", chat, "item", it.ID, "image", p.Hash)
				continue
			}
			if err != nil {
				return nil, err
			}
			st.Pictures = append(st.Pictures, p)
			continue
		}
		if p.Hash == "" { // else taken as the image came in
			sum := sha256.Sum256(img.Data)
			p.Hash = hex.EncodeToString(sum[:])
		}
		if p.Size = int64(len(img.Data)); p.Width == 0 {
			p.Width, p.Height = imagesize.OfBytes(img.Data)
		}
		if err := s.writeImageLocked(chat, p.Hash, img.Data); err != nil {
			return nil, err
		}
		st.Pictures = append(st.Pictures, p)
	}
	return st, nil
}

// hasImageLocked says chat's copy has the image of hash, or why not
// (fs.ErrNotExist when its file isn't there).
func (s *Store) hasImageLocked(chat, hash string) error {
	if err := checkChat(chat); err != nil {
		return err
	}
	if !validHash.MatchString(hash) {
		return fmt.Errorf("an image held by %q, not a hash", hash)
	}
	if _, err := s.root.Lstat(path.Join(chat, imagesDir, hash)); err != nil {
		return fmt.Errorf("an image held as a reference isn't in the transcript copy: %w", err)
	}
	return nil
}

// writeImageLocked writes an image under its hash, whole or not at all
// (atomicfile.ReplaceIn): one there is never written again, so it must
// never be there empty.
func (s *Store) writeImageLocked(chat, hash string, data []byte) error {
	if err := checkChat(chat); err != nil {
		return err
	}
	dir := path.Join(chat, imagesDir)
	name := path.Join(dir, hash)
	if _, err := s.root.Lstat(name); err == nil {
		return nil
	}
	if err := s.root.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	return atomicfile.ReplaceIn(s.root, name, data, 0o600)
}
