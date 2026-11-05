package api

import (
	"bytes"
	"errors"
	"log/slog"
	"os"
	"strings"
	"syscall"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/logs"
)

// An upload refused or not saved reaches the app with its file's name,
// never the daemon's log: a name can say what a file holds.
func TestAnUploadsNameStaysOutOfTheLog(t *testing.T) {
	const name = "divorce-filing-final.pdf"
	for _, c := range []struct {
		err  error
		want string
	}{
		{&chats.UploadError{Name: name, Large: true}, "an upload was too large"},
		{&chats.UploadError{Name: name, Err: &os.PathError{Op: "open", Path: "/u/c/r/" + name, Err: syscall.ENOSPC}}, "an upload couldn't be saved: no space left on device"},
		{&chats.UploadError{Name: name, Err: errors.New("the folder " + name + " went")}, "an upload couldn't be saved"},
	} {
		if !strings.Contains(c.err.Error(), name) {
			t.Fatalf("the app isn't told which file: %v", c.err)
		}
		var buf bytes.Buffer
		old := slog.Default()
		slog.SetDefault(slog.New(logs.Handler(&buf)))
		logCalls{"socket"}.ended("/nushi.v1.NushiService/SendPrompt", 0, connect.NewError(connect.CodeUnknown, c.err))
		slog.SetDefault(old)
		if strings.Contains(buf.String(), "divorce") || !strings.Contains(buf.String(), c.want) {
			t.Errorf("logged %s", buf.String())
		}
	}
}
