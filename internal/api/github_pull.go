package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

func linkProto(g *model.ChatGitHub) *nushiv1.GitHubLink {
	if g == nil {
		return nil
	}
	return &nushiv1.GitHubLink{Host: g.Host, Id: g.ID, Repo: g.Repo, Number: int32(g.Number), Pull: g.Pull}
}

// FindChatPull looks for the pull request of a chat's branch and links it
// when found: one linked by hand or unlinked stays as it is, and one found
// for a branch the folder has left goes.
func (s *server) FindChatPull(ctx context.Context, req *connect.Request[nushiv1.FindChatPullRequest]) (*connect.Response[nushiv1.FindChatPullResponse], error) {
	sess, err := s.chats.Session(req.Msg.ChatId)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, err)
	}
	if sess.Scratch {
		return connect.NewResponse(&nushiv1.FindChatPullResponse{Pull: linkProto(sess.PullLink())}), nil
	}
	found, err := s.github.FindPull(ctx, sess.Folder, req.Msg.Quiet)
	out := &nushiv1.FindChatPullResponse{Host: found.Host, Repo: found.Repo, Branch: found.Branch, DefaultBranch: found.Default}
	if err != nil {
		out.Error = err.Error()
	}
	if err == nil && found.Host != "" {
		if found.Pull != nil {
			err = s.chats.LinkPull(req.Msg.ChatId, found.Pull)
		} else {
			s.chats.DropFoundPull(req.Msg.ChatId, found.Branch)
		}
		if err == nil {
			sess, err = s.chats.Session(req.Msg.ChatId)
		}
		if err != nil {
			return nil, connect.NewError(connect.CodeNotFound, err)
		}
	}
	out.Pull = linkProto(sess.PullLink())
	return connect.NewResponse(out), nil
}

// LinkChatPull links the pull request picked by hand, or unlinks the
// chat's.
func (s *server) LinkChatPull(_ context.Context, req *connect.Request[nushiv1.LinkChatPullRequest]) (*connect.Response[nushiv1.LinkChatPullResponse], error) {
	var pull *model.ChatGitHub
	if l := req.Msg.Pull; l != nil {
		if !l.Pull {
			return nil, connect.NewError(connect.CodeInvalidArgument, errors.New("not a pull request"))
		}
		link, err := s.github.Link(model.ChatGitHub{Host: l.Host, Repo: l.Repo, Number: int(l.Number), Pull: true, ID: l.Id})
		if err != nil {
			return nil, connect.NewError(connect.CodeInvalidArgument, err)
		}
		pull = &link
	}
	if err := s.chats.LinkPull(req.Msg.ChatId, pull); err != nil {
		return nil, connect.NewError(connect.CodeNotFound, err)
	}
	return connect.NewResponse(&nushiv1.LinkChatPullResponse{}), nil
}
