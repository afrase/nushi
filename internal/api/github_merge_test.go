package api

import (
	"errors"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/githubapi"
)

// A head that moved is its own reason, which the app reads the pull request
// again on; a guard's refusal and GitHub's are refused in their own words.
func TestMergeErr(t *testing.T) {
	var ce *connect.Error
	if err := mergeErr(github.ErrHeadMoved); !errors.As(err, &ce) || ce.Code() != connect.CodeAborted || ce.Meta().Get(ReasonHeader) != ReasonHeadMoved {
		t.Fatalf("%v", err)
	}
	if err := mergeErr(github.ErrMergeRefused); connect.CodeOf(err) != connect.CodeFailedPrecondition {
		t.Fatalf("%v", err)
	}
	if err := mergeErr(githubapi.ErrNotFound); connect.CodeOf(err) != connect.CodeNotFound {
		t.Fatalf("%v", err)
	}
}

// GitHub's refusal is logged by its status, never its words; it reaches the
// app whole.
func TestLoggable(t *testing.T) {
	gh := refused(&githubapi.APIError{Status: 422, Message: "branch evil\nname"})
	if got := loggable(gh); got != "GitHub answered 422" {
		t.Fatalf("%v", got)
	}
	if ours := errors.New("mine"); loggable(ours) != any(ours) {
		t.Fatal("another error was changed")
	}
	if connect.CodeOf(gh) != connect.CodeFailedPrecondition {
		t.Fatalf("%v", gh)
	}
}

// ADR 0069: a phone may merge, as it may post a review. Should a review
// become the Mac's alone, this says the merges go with it.
func TestPhoneMergesAsItReviews(t *testing.T) {
	guard := localGuard{}
	review := guard.refuse(connect.Spec{Procedure: nushiv1connect.NushiServiceSubmitGitHubReviewProcedure})
	for _, proc := range []string{
		nushiv1connect.NushiServiceGetGitHubMergeTextProcedure,
		nushiv1connect.NushiServiceMergeGitHubPullProcedure,
		nushiv1connect.NushiServiceEnableGitHubAutoMergeProcedure,
		nushiv1connect.NushiServiceDisableGitHubAutoMergeProcedure,
		nushiv1connect.NushiServiceEnqueueGitHubPullProcedure,
		nushiv1connect.NushiServiceDequeueGitHubPullProcedure,
	} {
		if err := guard.refuse(connect.Spec{Procedure: proc}); (err == nil) != (review == nil) {
			t.Errorf("%s: %v; a review: %v", proc, err, review)
		}
	}
}

// An edit refused because GitHub changed it since is its own reason, on
// which the app keeps the user's text and offers GitHub's; GitHub not
// letting the user edit it is PermissionDenied.
func TestEditErr(t *testing.T) {
	var ce *connect.Error
	if err := editErr(github.ErrChangedSince); !errors.As(err, &ce) || ce.Code() != connect.CodeFailedPrecondition || ce.Meta().Get(ReasonHeader) != ReasonChangedSince {
		t.Fatalf("%v", err)
	}
	if err := editErr(github.ErrCantEdit); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Fatalf("%v", err)
	}
	if err := editErr(githubapi.ErrNotFound); connect.CodeOf(err) != connect.CodeNotFound {
		t.Fatalf("%v", err)
	}
}

// A phone may edit a pull request's text, as it may post a review.
func TestPhoneEditsAsItReviews(t *testing.T) {
	guard := localGuard{}
	review := guard.refuse(connect.Spec{Procedure: nushiv1connect.NushiServiceSubmitGitHubReviewProcedure})
	edit := guard.refuse(connect.Spec{Procedure: nushiv1connect.NushiServiceEditGitHubPullProcedure})
	if (edit == nil) != (review == nil) {
		t.Fatalf("an edit: %v; a review: %v", edit, review)
	}
}
