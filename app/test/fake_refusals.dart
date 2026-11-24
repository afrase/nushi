import 'package:connectrpc/connect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart' show FakeDaemon;

/// What [FakeDaemon] refuses, and how a refusal fails the test: the calls
/// it answers empty when nothing else does, and the calls and streams it
/// refused.
mixin Refusals {
  /// The calls the fake refused, by request type: none it knows, nor the
  /// test's [FakeDaemon.answer], nor one of [answersEmpty]; and the
  /// streams none answered, the fake's own nor [FakeDaemon.streams].
  final refused = <String>[];

  /// Refuses [input] as a daemon that lacks its call does, and keeps it in
  /// [refused]: the app may swallow the error, the test's end won't.
  Never refuse(Object input) {
    final what = '${input.runtimeType}';
    refused.add(what);
    throw ConnectException(Code.unimplemented, 'FakeDaemon has no $what');
  }

  /// Fails the test if the fake refused a call: a test whose app makes a
  /// call needs an answer for it, [FakeDaemon.answer]'s or the fake's
  /// own, or the call a place in [answersEmpty].
  void checkRefused() {
    if (refused.isEmpty) return;
    fail(
      'FakeDaemon refused ${{...refused}.join(', ')}: give the test an '
      'answer for it (FakeDaemon.on), or the fake one, or, if an empty '
      'message is what the daemon answers when it has nothing to say, a '
      'place in answersEmpty',
    );
  }
}

/// The calls whose empty message is what a daemon with nothing to say
/// answers (a list with no entries, a get of something optional, a call
/// that only acts), so [FakeDaemon] answers them so unless a test says
/// otherwise. Any other call it doesn't know it refuses as Unimplemented
/// and fails the test.
const answersEmpty = <Type>{
  // Calls that only act: on success the daemon's answer is empty (its
  // handlers' `done`), and a test that cares looks at [FakeDaemon.calls].
  // Chats.
  AnswerQuestionRequest,
  ArchiveChatRequest,
  CloseSideChatRequest,
  DeleteChatBranchRequest,
  DeleteChatRequest,
  DismissRemovedChatsRequest,
  MoveChatRequest,
  PinChatsRequest,
  PinMessageRequest,
  ReloadChatRequest,
  RemoveChatWorktreeRequest,
  RenameBranchRequest,
  RenameChatRequest,
  ReopenChatRequest,
  WakeChatRequest,
  SetChatColorRequest,
  SetConfigOptionRequest,
  SetDeviceViewRequest,
  StopTaskRequest,
  // Nothing taken back to edit, a message that ran no command.
  CancelTurnRequest,
  SendPromptRequest,
  // Terminals, dev servers, the app's log, the daemon's own.
  CloseTerminalRequest,
  ResizeTerminalRequest,
  StopAllServersRequest,
  StopServerRequest,
  LogRequest,
  ClearTranscriptsRequest,
  InstallUpdateRequest,
  SetSettingsRequest,
  // Agents, MCP servers, skills and trust.
  AddMcpServerRequest,
  LogoutMcpServerRequest,
  RemoveAgentRequest,
  SetMcpServerOnRequest,
  SetPluginOnRequest,
  SetSkillOnRequest,
  SetUpAgentRequest,
  LinkSkillRequest,
  TrashSkillRequest,
  TrustFolderRequest,
  // The phone: pairing and push.
  ConfirmPairingRequest,
  SendTestPushRequest,
  SetPushSubscriptionRequest,
  UnpairThisDeviceRequest,
  // GitHub and Jira.
  AddGitHubCommentRequest,
  AddJiraCommentRequest,
  AllowGitHubTokenRequest,
  AllowJiraTokenRequest,
  DequeueGitHubPullRequest,
  EnableGitHubAutoMergeRequest,
  LinkChatPullRequest,
  MergeGitHubPullRequest,
  ReplyGitHubThreadRequest,
  ResolveGitHubThreadRequest,
  RestoreGitHubBranchRequest,
  SetGitHubViewedRequest,
  SetJiraSearchesRequest,
  SubmitGitHubReviewRequest,
  TransitionJiraIssueRequest,
  // Nothing to say: a list with no entries, or nothing found.
  // No GitHub host signed in, Jira site set up, repository known, pull
  // request row or state known, file viewed, value to suggest.
  ListGitHubHostsRequest,
  ListJiraSitesRequest,
  ListGitHubReposRequest,
  GetGitHubItemsRequest,
  GetGitHubStatesRequest,
  GetGitHubViewedRequest,
  SuggestJiraJqlRequest,
  // No terminal, MCP server, commit or file; no path found.
  ListTerminalsRequest,
  ListMcpServersRequest,
  ListCommitsRequest,
  ListFilesRequest,
  FindChatFilesRequest,
  // A diff of a span with no change, a folder that runs nothing to
  // trust; no chat holding off a restart.
  GetDiffRequest,
  CheckFolderRequest,
  RestartWhenIdleRequest,
};
