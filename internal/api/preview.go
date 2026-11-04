package api

import (
	"context"
	"errors"
	"fmt"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/filewatch"
	"github.com/afrase/nushi/internal/folderlist"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// WatchChatFile sends a file of a chat's, and again each time it changes:
// the preview pane, while it's open.
func (s *server) WatchChatFile(ctx context.Context, req *connect.Request[nushiv1.WatchChatFileRequest], stream *connect.ServerStream[nushiv1.WatchChatFileResponse]) error {
	roots, err := s.chats.Roots(req.Msg.ChatId)
	if err != nil {
		return notFound(err)
	}
	root, rel, err := s.chatFile(req.Msg.ChatId, roots, req.Msg.Path)
	if err != nil {
		return connect.NewError(connect.CodePermissionDenied, err)
	}
	var sendErr error
	err = filewatch.Watch(ctx, root, rel, time.Second, func(f filewatch.File) error {
		sendErr = stream.Send(&nushiv1.WatchChatFileResponse{Path: f.Path, Data: f.Data, Size: f.Size,
			TooLarge: f.TooLarge, Missing: f.Missing})
		return sendErr
	})
	if err == nil || sendErr != nil {
		return err
	}
	// A link out of the folder, or a read that failed.
	return refused(err)
}

// chatFile is where the preview may read path from (filewatch.Allowed):
// the answer the agent's show tool gets too.
func (s *server) chatFile(chatID string, roots []string, path string) (root, rel string, err error) {
	return filewatch.Allowed(roots, path, func(p string) bool { return s.chats.Wrote(chatID, p) })
}

// maxFindFiles is how many paths FindChatFiles takes at once.
const maxFindFiles = 200

// FindChatFiles says which of the paths an agent's message names are
// files the preview opens: the app links only those.
func (s *server) FindChatFiles(_ context.Context, req *connect.Request[nushiv1.FindChatFilesRequest]) (*connect.Response[nushiv1.FindChatFilesResponse], error) {
	if len(req.Msg.Paths) > maxFindFiles {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("%d paths, %d at most", len(req.Msg.Paths), maxFindFiles))
	}
	roots, err := s.chats.Roots(req.Msg.ChatId)
	if err != nil {
		return nil, notFound(err)
	}
	found := []string{}
	for _, p := range req.Msg.Paths {
		if root, rel, err := s.chatFile(req.Msg.ChatId, roots, p); err == nil && filewatch.Exists(root, rel) {
			found = append(found, p)
		}
	}
	return connect.NewResponse(&nushiv1.FindChatFilesResponse{Found: found}), nil
}

// WatchChatFolder lists a folder inside a chat's folder for the Files
// pane, and again each time it changes (folderlist.Watch). The path is a
// client's, the phone's too: folderlist.Clean checks it, and os.Root
// keeps every read inside the chat's folder.
func (s *server) WatchChatFolder(ctx context.Context, req *connect.Request[nushiv1.WatchChatFolderRequest], stream *connect.ServerStream[nushiv1.WatchChatFolderResponse]) error {
	rel, err := folderlist.Clean(req.Msg.Path)
	if err != nil {
		return invalid(err)
	}
	roots, err := s.chats.Roots(req.Msg.ChatId)
	if err != nil {
		return notFound(err)
	}
	o := folderlist.Options{Depth: int(req.Msg.Depth), Ignored: req.Msg.Ignored, Limit: int(req.Msg.Limit)}
	var sendErr error
	err = folderlist.Watch(ctx, roots[0], rel, o, time.Second, func(ls []folderlist.Listing) error {
		sendErr = stream.Send(&nushiv1.WatchChatFolderResponse{Folders: folderListings(ls)})
		return sendErr
	})
	switch {
	case err == nil || sendErr != nil:
		return err
	case errors.Is(err, folderlist.ErrFolder):
		return connect.NewError(connect.CodePermissionDenied, err)
	}
	return refused(errors.New("the folder can't be read")) // its error names the path
}

func folderListings(ls []folderlist.Listing) []*nushiv1.FolderListing {
	out := make([]*nushiv1.FolderListing, 0, len(ls))
	for _, l := range ls {
		p := &nushiv1.FolderListing{Path: l.Path, More: int32(l.More), Missing: l.Missing}
		for _, e := range l.Entries {
			p.Entries = append(p.Entries, &nushiv1.FolderEntry{Name: e.Name, Kind: string(e.Kind), Size: e.Size,
				ModifiedMs: e.Modified.UnixMilli(), Ignored: e.Ignored, Linked: e.Linked})
		}
		out = append(out, p)
	}
	return out
}
