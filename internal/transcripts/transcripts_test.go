package transcripts

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

func open(t *testing.T) (*Store, string) {
	t.Helper()
	dir := filepath.Join(t.TempDir(), "transcripts")
	s, err := Open(dir)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })
	return s, dir
}

func ids(items []model.Item) string {
	var out []string
	for _, it := range items {
		out = append(out, it.ID+"="+it.Text)
	}
	return strings.Join(out, " ")
}

func msg(id, text string) model.Item { return model.Item{ID: id, Kind: model.AgentMessage, Text: text} }

// add appends items in order, each after the one before it.
func add(t *testing.T, s *Store, chat, after string, items ...model.Item) {
	t.Helper()
	afters := make([]string, len(items))
	for i := range items {
		afters[i] = after
		after = items[i].ID
	}
	if err := s.Append(chat, items, afters); err != nil {
		t.Fatal(err)
	}
}

func read(t *testing.T, s *Store, chat string) []model.Item {
	t.Helper()
	items, err := s.Read(chat)
	if err != nil {
		t.Fatal(err)
	}
	return items
}

func TestAppendReadBack(t *testing.T) {
	s, dir := open(t)
	if items := read(t, s, "CHAT"); items != nil || s.Has("CHAT") {
		t.Fatalf("a chat without a copy reads %v", items)
	}
	img := model.Image{MimeType: "image/png", Data: []byte("png bytes")}
	add(t, s, "CHAT", "", model.Item{ID: "item-1", Kind: model.UserMessage, Text: "hi", Images: []model.Image{img}}, msg("m1", "hello"))
	add(t, s, "CHAT", "m1", msg("m1", "hello, whole"), model.Item{ID: "t1", Kind: model.ToolCall, Status: "completed", Images: []model.Image{img}})
	got := read(t, s, "CHAT")
	if ids(got) != "item-1=hi m1=hello, whole t1=" {
		t.Fatalf("read %s", ids(got))
	}
	if len(got[0].Images) != 1 || string(got[0].Images[0].Data) != "png bytes" || got[2].Images[0].MimeType != "image/png" {
		t.Errorf("images %+v", got[0].Images)
	}
	pics, _ := os.ReadDir(filepath.Join(dir, "CHAT", imagesDir))
	if len(pics) != 1 { // the same image once
		t.Errorf("%d image files", len(pics))
	}
	for _, p := range []string{filepath.Join(dir, "CHAT", itemsFile), filepath.Join(dir, "CHAT", imagesDir, pics[0].Name())} {
		if fi, _ := os.Stat(p); fi.Mode().Perm() != 0o600 {
			t.Errorf("%s is %v", p, fi.Mode())
		}
	}
	for _, p := range []string{dir, filepath.Join(dir, "CHAT"), filepath.Join(dir, "CHAT", imagesDir)} {
		if fi, _ := os.Stat(p); fi.Mode().Perm() != 0o700 {
			t.Errorf("%s is %v", p, fi.Mode())
		}
	}
}

// An item written after items that came later in the transcript (a tool
// call written once it ended) still takes its place, and one waiting for
// an item never written goes last.
func TestOrder(t *testing.T) {
	s, _ := open(t)
	add(t, s, "C", "", msg("a", "A"))
	if err := s.Append("C", []model.Item{msg("c", "C"), msg("d", "D")}, []string{"b", "c"}); err != nil {
		t.Fatal(err)
	}
	if got := ids(read(t, s, "C")); got != "a=A c=C d=D" {
		t.Fatalf("before b: %s", got)
	}
	add(t, s, "C", "a", msg("b", "B"))
	add(t, s, "C", "zz", msg("e", "E"))
	if got := ids(read(t, s, "C")); got != "a=A b=B c=C d=D e=E" {
		t.Fatalf("got %s", got)
	}
}

// An item written again while it waits is there once, as written last:
// placed when its After comes, at the end if it never does, and at once
// if it was written again after an item that is there.
func TestOrderWrittenAgainWhileWaiting(t *testing.T) {
	s, _ := open(t)
	add(t, s, "C", "", msg("a", "A"))
	add(t, s, "C", "b", msg("c", "C"))
	add(t, s, "C", "b", msg("c", "C again"))
	add(t, s, "C", "zz", msg("e", "E"))
	add(t, s, "C", "zz", msg("e", "E again"))
	if got := ids(read(t, s, "C")); got != "a=A c=C again e=E again" {
		t.Fatalf("waiting: %s", got)
	}
	add(t, s, "C", "a", msg("b", "B"))
	if got := ids(read(t, s, "C")); got != "a=A b=B c=C again e=E again" {
		t.Fatalf("placed: %s", got)
	}
	add(t, s, "D", "", msg("a", "A"))
	add(t, s, "D", "b", msg("c", "C"))
	add(t, s, "D", "a", msg("c", "C again"))
	add(t, s, "D", "a", msg("b", "B"))
	if got := ids(read(t, s, "D")); got != "a=A b=B c=C again" {
		t.Fatalf("written again after an item there: %s", got)
	}
}

// A copy written anew while an item was there twice (before step 443)
// reads with the item once, as written last.
func TestReadDuplicates(t *testing.T) {
	s, dir := open(t)
	noErr(t, os.MkdirAll(filepath.Join(dir, "C"), 0o700))
	lines := `{"item":{"ID":"a","Text":"A"}}
{"item":{"ID":"b","Text":"B"},"after":"a"}
{"item":{"ID":"c","Text":"C"},"after":"b"}
{"item":{"ID":"b","Text":"B again"},"after":"c"}
`
	noErr(t, os.WriteFile(filepath.Join(dir, "C", itemsFile), []byte(lines), 0o600))
	if got := ids(read(t, s, "C")); got != "a=A b=B again c=C" {
		t.Fatalf("got %s", got)
	}
}

func TestCutAndDrop(t *testing.T) {
	s, _ := open(t)
	add(t, s, "C", "", msg("a", "A"), msg("b", "B"), msg("c", "C"), msg("d", "D"))
	noErr(t, s.Drop("C", "b"))
	noErr(t, s.Cut("C", "d"))
	add(t, s, "C", "c", msg("e", "E"))
	if got := ids(read(t, s, "C")); got != "a=A c=C e=E" {
		t.Fatalf("got %s", got)
	}
	noErr(t, s.Cut("NONE", "a")) // a chat without a copy gets none
	if s.Has("NONE") {
		t.Error("a cut made a copy")
	}
}

// A crash in the middle of a write leaves a last line without its end:
// reading skips it, and the next write starts a line of its own.
func TestCrashMidWrite(t *testing.T) {
	s, dir := open(t)
	add(t, s, "C", "", msg("a", "A"))
	f, err := os.OpenFile(filepath.Join(dir, "C", itemsFile), os.O_WRONLY|os.O_APPEND, 0)
	noErr(t, err)
	_, err = f.WriteString(`{"item":{"ID":"b","Kind":2,"Te`)
	noErr(t, err)
	noErr(t, f.Close())
	if got := ids(read(t, s, "C")); got != "a=A" {
		t.Fatalf("after the crash: %s", got)
	}
	s2, err := Open(dir) // the daemon again
	noErr(t, err)
	add(t, s2, "C", "a", msg("b", "B"))
	if got := ids(read(t, s2, "C")); got != "a=A b=B" {
		t.Fatalf("written after the crash: %s", got)
	}
	// A crash while an image was written leaves only its temporary file,
	// which the next start removes; the names before step 443 too.
	tmp := filepath.Join(dir, "C", imagesDir, ".nushi-XXXX")
	half := filepath.Join(dir, "C", ".nushi-YYYY") // a copy being written anew
	oldTmp := filepath.Join(dir, "C", imagesDir, strings.Repeat("0", 64)+".tmpXXXX")
	oldHalf := filepath.Join(dir, "C", itemsFile+".tmp")
	noErr(t, os.MkdirAll(filepath.Dir(tmp), 0o700))
	for _, p := range []string{tmp, half, oldTmp, oldHalf} {
		noErr(t, os.WriteFile(p, []byte("half"), 0o600))
	}
	_, err = Open(dir)
	noErr(t, err)
	if got := ids(read(t, s2, "C")); got != "a=A b=B" {
		t.Fatalf("after the clean-up: %s", got)
	}
	for _, p := range []string{tmp, half, oldTmp, oldHalf} {
		if _, err := os.Stat(p); !os.IsNotExist(err) {
			t.Errorf("%s stayed: %v", p, err)
		}
	}
}

func TestReplaceAndList(t *testing.T) {
	s, dir := open(t)
	img := model.Image{MimeType: "image/png", Data: []byte("old")}
	add(t, s, "BIG", "", model.Item{ID: "a", Kind: model.UserMessage, Text: strings.Repeat("x", 4000), Images: []model.Image{img}})
	add(t, s, "SMALL", "", msg("a", "A"))
	noErr(t, s.Replace("BIG", []model.Item{msg("n", "N"), msg("m", "M")}))
	if got := ids(read(t, s, "BIG")); got != "n=N m=M" {
		t.Fatalf("replaced: %s", got)
	}
	if pics, _ := os.ReadDir(filepath.Join(dir, "BIG", imagesDir)); len(pics) != 0 {
		t.Errorf("an image nothing names stayed: %v", pics)
	}
	add(t, s, "BIG", "m", msg("p", strings.Repeat("y", 5000)))
	list, err := s.List()
	noErr(t, err)
	if len(list) != 2 || list[0].Chat != "BIG" || list[1].Chat != "SMALL" || list[0].Bytes < 5000 || time.Since(list[0].Modified) > time.Minute {
		t.Fatalf("list %+v", list)
	}
	noErr(t, s.Delete("BIG"))
	if s.Has("BIG") || read(t, s, "BIG") != nil {
		t.Error("deleted, still there")
	}
	if _, err := os.Stat(filepath.Join(dir, "BIG")); !os.IsNotExist(err) {
		t.Errorf("the chat's folder stayed: %v", err)
	}
}

// A file mostly of items written again is written anew when read.
func TestReadRewrites(t *testing.T) {
	s, dir := open(t)
	long := strings.Repeat("z", 64<<10)
	for i := range 40 {
		add(t, s, "C", "", msg("a", long+strings.Repeat("!", i)))
	}
	path := filepath.Join(dir, "C", itemsFile)
	before, _ := os.Stat(path)
	got := read(t, s, "C")
	after, _ := os.Stat(path)
	if len(got) != 1 || got[0].Text != long+strings.Repeat("!", 39) || after.Size() >= before.Size()/10 {
		t.Fatalf("%d items; %d bytes, then %d", len(got), before.Size(), after.Size())
	}
	if got := read(t, s, "C"); len(got) != 1 || got[0].Text != long+strings.Repeat("!", 39) {
		t.Fatal("rewritten wrong")
	}
}

// Names come only from checked chat ids: nothing outside the store's
// folder is touched.
func TestNames(t *testing.T) {
	s, dir := open(t)
	outside := filepath.Join(filepath.Dir(dir), "outside")
	noErr(t, os.MkdirAll(outside, 0o700))
	for _, bad := range []string{"", "..", "../outside", "a/b", ".", strings.Repeat("a", 65)} {
		if err := s.Append(bad, []model.Item{msg("a", "A")}, []string{""}); err == nil {
			t.Errorf("Append(%q) worked", bad)
		}
		if err := s.Delete(bad); err == nil {
			t.Errorf("Delete(%q) worked", bad)
		}
		if _, err := s.Read(bad); err == nil {
			t.Errorf("Read(%q) worked", bad)
		}
	}
	// A link planted in the store doesn't lead out of it.
	noErr(t, os.Symlink(outside, filepath.Join(dir, "LINK")))
	if err := s.Append("LINK", []model.Item{msg("a", "A")}, []string{""}); err == nil {
		t.Error("wrote through a link")
	}
	if files, _ := os.ReadDir(outside); len(files) != 0 {
		t.Errorf("wrote outside: %v", files)
	}
	list, err := s.List()
	noErr(t, err)
	if slices.ContainsFunc(list, func(c model.TranscriptCopy) bool { return c.Chat == "LINK" }) {
		t.Error("a link listed as a copy")
	}
}

func noErr(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}
