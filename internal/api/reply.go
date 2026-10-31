package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"
)

// done answers a call that returns nothing: an empty reply, or err as
// code makes it (refused, notFound, githubErr…).
func done[T any](err error, code func(error) error) (*connect.Response[T], error) {
	if err != nil {
		return nil, code(err)
	}
	return connect.NewResponse(new(T)), nil
}

// refused is a call the daemon won't do as things stand: its error says
// why (FailedPrecondition).
func refused(err error) error { return connect.NewError(connect.CodeFailedPrecondition, err) }

// notFound is a call on something that isn't there.
func notFound(err error) error { return connect.NewError(connect.CodeNotFound, err) }

// invalid is a call whose request is wrong.
func invalid(err error) error { return connect.NewError(connect.CodeInvalidArgument, err) }

// waitErr is a chat call's failure: its context's own when the call gave
// up waiting (connect codes it Canceled or DeadlineExceeded), else
// refused.
func waitErr(ctx context.Context, err error) error {
	if ctx.Err() != nil && errors.Is(err, ctx.Err()) {
		return err
	}
	return refused(err)
}

// ReasonHeader is the metadata a refusal the app acts on carries, so the
// app needn't read its message (which an older daemon's it still reads):
// ReasonRestarting, ReasonAgentStart or ReasonHeadMoved.
const ReasonHeader = "Nushi-Reason"

const (
	// ReasonRestarting is a prompt refused as Unavailable because the
	// daemon is restarting into a newer build (chats.ErrRestarting): the
	// app sends it again to the new one. Another Unavailable (a dropped
	// socket) may have taken it, so isn't sent again.
	ReasonRestarting = "restarting"
	// ReasonAgentStart is a new chat whose agent didn't start
	// (chats.ErrStart): the app marks the agent with why.
	ReasonAgentStart = "agent_start"
	// ReasonHeadMoved is a merge refused because the pull request isn't at
	// the head the user was shown (github.ErrHeadMoved): the app says so
	// and reads it again.
	ReasonHeadMoved = "head_moved"
)

// because is err carrying reason (ReasonHeader).
func because(err *connect.Error, reason string) *connect.Error {
	err.Meta().Set(ReasonHeader, reason)
	return err
}
