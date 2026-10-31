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
	guard := deviceGuard{}
	review := guard.macs(connect.Spec{Procedure: nushiv1connect.NushiServiceSubmitGitHubReviewProcedure})
	for _, proc := range []string{
		nushiv1connect.NushiServiceGetGitHubMergeTextProcedure,
		nushiv1connect.NushiServiceMergeGitHubPullProcedure,
		nushiv1connect.NushiServiceEnableGitHubAutoMergeProcedure,
		nushiv1connect.NushiServiceDisableGitHubAutoMergeProcedure,
		nushiv1connect.NushiServiceEnqueueGitHubPullProcedure,
		nushiv1connect.NushiServiceDequeueGitHubPullProcedure,
	} {
		if err := guard.macs(connect.Spec{Procedure: proc}); (err == nil) != (review == nil) {
			t.Errorf("%s: %v; a review: %v", proc, err, review)
		}
	}
	// What the guard refuses, a device gets as this.
	if err := guard.macs(connect.Spec{Procedure: nushiv1connect.NushiServiceStartPairingProcedure}); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Fatalf("%v", err)
	}
}
