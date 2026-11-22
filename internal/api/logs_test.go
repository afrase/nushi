package api

import (
	"bytes"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/servers"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/logs"
)

// Tech debt review 2026-11-22: loggable's type switch became each error's
// own Logged. A failed call's line says what the switch said for each type
// (a dev server's start only its kind: rpc=StartServer already says what
// was refused), never the words the app gets, wrapped or not.
func TestEachQuietErrorLogsItsFixedWords(t *testing.T) {
	const marker = "MARKER-PRIVATE"
	for _, c := range []struct {
		err  error
		want string
	}{
		{&chats.UploadError{Name: marker, Large: true}, `err="an upload was too large"`},
		{&chats.UploadError{Name: marker, Err: errors.New(marker)}, `err="an upload couldn't be saved"`},
		{&githubapi.APIError{Status: 422, Message: marker}, `err="GitHub answered 422"`},
		{&git.CommitError{Said: "input: " + marker}, `err="git commit failed"`},
		{&servers.StartError{Kind: "its program isn't found", Err: errors.New(marker)}, `err="its program isn't found"`},
	} {
		for _, err := range []error{c.err, fmt.Errorf("doing it: %w", c.err)} {
			var buf bytes.Buffer
			old := slog.Default()
			slog.SetDefault(slog.New(logs.Handler(&buf)))
			logCalls{"socket"}.ended("/nushi.v1.NushiService/Ping", 0, connect.NewError(connect.CodeFailedPrecondition, err))
			slog.SetDefault(old)
			if got := buf.String(); strings.Contains(got, marker) || !strings.Contains(got, c.want) {
				t.Errorf("%T logged %s", c.err, got)
			}
		}
	}
}
