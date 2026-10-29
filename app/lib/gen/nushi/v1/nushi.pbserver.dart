// This is a generated file - do not edit.
//
// Generated from nushi/v1/nushi.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'nushi.pb.dart' as $0;
import 'nushi.pbjson.dart';

export 'nushi.pb.dart';

abstract class NushiServiceBase extends $pb.GeneratedService {
  $async.Future<$0.PingResponse> ping(
      $pb.ServerContext ctx, $0.PingRequest request);
  $async.Future<$0.RestartWhenIdleResponse> restartWhenIdle(
      $pb.ServerContext ctx, $0.RestartWhenIdleRequest request);
  $async.Future<$0.CheckForUpdatesResponse> checkForUpdates(
      $pb.ServerContext ctx, $0.CheckForUpdatesRequest request);
  $async.Future<$0.ListChatsResponse> listChats(
      $pb.ServerContext ctx, $0.ListChatsRequest request);
  $async.Future<$0.GetChatResponse> getChat(
      $pb.ServerContext ctx, $0.GetChatRequest request);
  $async.Future<$0.GetChatItemsResponse> getChatItems(
      $pb.ServerContext ctx, $0.GetChatItemsRequest request);
  $async.Future<$0.StartChatResponse> startChat(
      $pb.ServerContext ctx, $0.StartChatRequest request);
  $async.Future<$0.ListAgentsResponse> listAgents(
      $pb.ServerContext ctx, $0.ListAgentsRequest request);
  $async.Future<$0.SetUpAgentResponse> setUpAgent(
      $pb.ServerContext ctx, $0.SetUpAgentRequest request);
  $async.Future<$0.RemoveAgentResponse> removeAgent(
      $pb.ServerContext ctx, $0.RemoveAgentRequest request);
  $async.Future<$0.ListAgentSessionsResponse> listAgentSessions(
      $pb.ServerContext ctx, $0.ListAgentSessionsRequest request);
  $async.Future<$0.OpenAgentSessionResponse> openAgentSession(
      $pb.ServerContext ctx, $0.OpenAgentSessionRequest request);
  $async.Future<$0.MoveChatResponse> moveChat(
      $pb.ServerContext ctx, $0.MoveChatRequest request);
  $async.Future<$0.SendPromptResponse> sendPrompt(
      $pb.ServerContext ctx, $0.SendPromptRequest request);
  $async.Future<$0.RewindChatResponse> rewindChat(
      $pb.ServerContext ctx, $0.RewindChatRequest request);
  $async.Future<$0.UnqueueResponse> unqueue(
      $pb.ServerContext ctx, $0.UnqueueRequest request);
  $async.Future<$0.CancelTurnResponse> cancelTurn(
      $pb.ServerContext ctx, $0.CancelTurnRequest request);
  $async.Future<$0.StopTaskResponse> stopTask(
      $pb.ServerContext ctx, $0.StopTaskRequest request);
  $async.Future<$0.ForkChatResponse> forkChat(
      $pb.ServerContext ctx, $0.ForkChatRequest request);
  $async.Future<$0.CloseSideChatResponse> closeSideChat(
      $pb.ServerContext ctx, $0.CloseSideChatRequest request);
  $async.Future<$0.RenameChatResponse> renameChat(
      $pb.ServerContext ctx, $0.RenameChatRequest request);
  $async.Future<$0.RenameBranchResponse> renameBranch(
      $pb.ServerContext ctx, $0.RenameBranchRequest request);
  $async.Future<$0.SwitchBranchResponse> switchBranch(
      $pb.ServerContext ctx, $0.SwitchBranchRequest request);
  $async.Future<$0.ArchiveChatResponse> archiveChat(
      $pb.ServerContext ctx, $0.ArchiveChatRequest request);
  $async.Future<$0.SleepChatResponse> sleepChat(
      $pb.ServerContext ctx, $0.SleepChatRequest request);
  $async.Future<$0.ReopenChatResponse> reopenChat(
      $pb.ServerContext ctx, $0.ReopenChatRequest request);
  $async.Future<$0.GetMemoryResponse> getMemory(
      $pb.ServerContext ctx, $0.GetMemoryRequest request);
  $async.Future<$0.GetSettingsResponse> getSettings(
      $pb.ServerContext ctx, $0.GetSettingsRequest request);
  $async.Future<$0.SetSettingsResponse> setSettings(
      $pb.ServerContext ctx, $0.SetSettingsRequest request);
  $async.Future<$0.ListTranscriptsResponse> listTranscripts(
      $pb.ServerContext ctx, $0.ListTranscriptsRequest request);
  $async.Future<$0.ClearTranscriptsResponse> clearTranscripts(
      $pb.ServerContext ctx, $0.ClearTranscriptsRequest request);
  $async.Future<$0.PlanDeleteChatResponse> planDeleteChat(
      $pb.ServerContext ctx, $0.PlanDeleteChatRequest request);
  $async.Future<$0.DeleteChatResponse> deleteChat(
      $pb.ServerContext ctx, $0.DeleteChatRequest request);
  $async.Future<$0.DismissRemovedChatsResponse> dismissRemovedChats(
      $pb.ServerContext ctx, $0.DismissRemovedChatsRequest request);
  $async.Future<$0.AnswerPermissionResponse> answerPermission(
      $pb.ServerContext ctx, $0.AnswerPermissionRequest request);
  $async.Future<$0.AnswerQuestionResponse> answerQuestion(
      $pb.ServerContext ctx, $0.AnswerQuestionRequest request);
  $async.Future<$0.SetConfigOptionResponse> setConfigOption(
      $pb.ServerContext ctx, $0.SetConfigOptionRequest request);
  $async.Future<$0.GetDiffResponse> getDiff(
      $pb.ServerContext ctx, $0.GetDiffRequest request);
  $async.Future<$0.GetFileResponse> getFile(
      $pb.ServerContext ctx, $0.GetFileRequest request);
  $async.Future<$0.WatchChatFileResponse> watchChatFile(
      $pb.ServerContext ctx, $0.WatchChatFileRequest request);
  $async.Future<$0.FindChatFilesResponse> findChatFiles(
      $pb.ServerContext ctx, $0.FindChatFilesRequest request);
  $async.Future<$0.ListCommitsResponse> listCommits(
      $pb.ServerContext ctx, $0.ListCommitsRequest request);
  $async.Future<$0.GetFolderStatusResponse> getFolderStatus(
      $pb.ServerContext ctx, $0.GetFolderStatusRequest request);
  $async.Future<$0.ListBranchesResponse> listBranches(
      $pb.ServerContext ctx, $0.ListBranchesRequest request);
  $async.Future<$0.ListFilesResponse> listFiles(
      $pb.ServerContext ctx, $0.ListFilesRequest request);
  $async.Future<$0.GetContextUsageResponse> getContextUsage(
      $pb.ServerContext ctx, $0.GetContextUsageRequest request);
  $async.Future<$0.ListMcpServersResponse> listMcpServers(
      $pb.ServerContext ctx, $0.ListMcpServersRequest request);
  $async.Future<$0.AddMcpServerResponse> addMcpServer(
      $pb.ServerContext ctx, $0.AddMcpServerRequest request);
  $async.Future<$0.EditMcpServerResponse> editMcpServer(
      $pb.ServerContext ctx, $0.EditMcpServerRequest request);
  $async.Future<$0.RemoveMcpServerResponse> removeMcpServer(
      $pb.ServerContext ctx, $0.RemoveMcpServerRequest request);
  $async.Future<$0.SetMcpServerOnResponse> setMcpServerOn(
      $pb.ServerContext ctx, $0.SetMcpServerOnRequest request);
  $async.Future<$0.LoginMcpServerResponse> loginMcpServer(
      $pb.ServerContext ctx, $0.LoginMcpServerRequest request);
  $async.Future<$0.LogoutMcpServerResponse> logoutMcpServer(
      $pb.ServerContext ctx, $0.LogoutMcpServerRequest request);
  $async.Future<$0.ListSkillsResponse> listSkills(
      $pb.ServerContext ctx, $0.ListSkillsRequest request);
  $async.Future<$0.SetSkillOnResponse> setSkillOn(
      $pb.ServerContext ctx, $0.SetSkillOnRequest request);
  $async.Future<$0.SetPluginOnResponse> setPluginOn(
      $pb.ServerContext ctx, $0.SetPluginOnRequest request);
  $async.Future<$0.UninstallPluginResponse> uninstallPlugin(
      $pb.ServerContext ctx, $0.UninstallPluginRequest request);
  $async.Future<$0.TrashSkillResponse> trashSkill(
      $pb.ServerContext ctx, $0.TrashSkillRequest request);
  $async.Future<$0.LinkSkillResponse> linkSkill(
      $pb.ServerContext ctx, $0.LinkSkillRequest request);
  $async.Future<$0.ReloadChatResponse> reloadChat(
      $pb.ServerContext ctx, $0.ReloadChatRequest request);
  $async.Future<$0.OpenTerminalResponse> openTerminal(
      $pb.ServerContext ctx, $0.OpenTerminalRequest request);
  $async.Future<$0.ListTerminalsResponse> listTerminals(
      $pb.ServerContext ctx, $0.ListTerminalsRequest request);
  $async.Future<$0.AttachTerminalResponse> attachTerminal(
      $pb.ServerContext ctx, $0.AttachTerminalRequest request);
  $async.Future<$0.WriteTerminalResponse> writeTerminal(
      $pb.ServerContext ctx, $0.WriteTerminalRequest request);
  $async.Future<$0.ResizeTerminalResponse> resizeTerminal(
      $pb.ServerContext ctx, $0.ResizeTerminalRequest request);
  $async.Future<$0.RenameTerminalResponse> renameTerminal(
      $pb.ServerContext ctx, $0.RenameTerminalRequest request);
  $async.Future<$0.ArrangeTerminalsResponse> arrangeTerminals(
      $pb.ServerContext ctx, $0.ArrangeTerminalsRequest request);
  $async.Future<$0.RestartTerminalResponse> restartTerminal(
      $pb.ServerContext ctx, $0.RestartTerminalRequest request);
  $async.Future<$0.CloseTerminalResponse> closeTerminal(
      $pb.ServerContext ctx, $0.CloseTerminalRequest request);
  $async.Future<$0.CheckFolderResponse> checkFolder(
      $pb.ServerContext ctx, $0.CheckFolderRequest request);
  $async.Future<$0.TrustFolderResponse> trustFolder(
      $pb.ServerContext ctx, $0.TrustFolderRequest request);
  $async.Future<$0.GetRemoteResponse> getRemote(
      $pb.ServerContext ctx, $0.GetRemoteRequest request);
  $async.Future<$0.SetRemoteResponse> setRemote(
      $pb.ServerContext ctx, $0.SetRemoteRequest request);
  $async.Future<$0.StartPairingResponse> startPairing(
      $pb.ServerContext ctx, $0.StartPairingRequest request);
  $async.Future<$0.ConfirmPairingResponse> confirmPairing(
      $pb.ServerContext ctx, $0.ConfirmPairingRequest request);
  $async.Future<$0.RevokeDeviceResponse> revokeDevice(
      $pb.ServerContext ctx, $0.RevokeDeviceRequest request);
  $async.Future<$0.GetPushKeyResponse> getPushKey(
      $pb.ServerContext ctx, $0.GetPushKeyRequest request);
  $async.Future<$0.SetPushSubscriptionResponse> setPushSubscription(
      $pb.ServerContext ctx, $0.SetPushSubscriptionRequest request);
  $async.Future<$0.SetDeviceViewResponse> setDeviceView(
      $pb.ServerContext ctx, $0.SetDeviceViewRequest request);
  $async.Future<$0.SendTestPushResponse> sendTestPush(
      $pb.ServerContext ctx, $0.SendTestPushRequest request);
  $async.Future<$0.UnpairThisDeviceResponse> unpairThisDevice(
      $pb.ServerContext ctx, $0.UnpairThisDeviceRequest request);
  $async.Future<$0.LogResponse> log(
      $pb.ServerContext ctx, $0.LogRequest request);
  $async.Future<$0.ListJiraSitesResponse> listJiraSites(
      $pb.ServerContext ctx, $0.ListJiraSitesRequest request);
  $async.Future<$0.AddJiraSiteResponse> addJiraSite(
      $pb.ServerContext ctx, $0.AddJiraSiteRequest request);
  $async.Future<$0.RemoveJiraSiteResponse> removeJiraSite(
      $pb.ServerContext ctx, $0.RemoveJiraSiteRequest request);
  $async.Future<$0.CheckJiraSiteResponse> checkJiraSite(
      $pb.ServerContext ctx, $0.CheckJiraSiteRequest request);
  $async.Future<$0.AllowJiraTokenResponse> allowJiraToken(
      $pb.ServerContext ctx, $0.AllowJiraTokenRequest request);
  $async.Future<$0.ListJiraBoardsResponse> listJiraBoards(
      $pb.ServerContext ctx, $0.ListJiraBoardsRequest request);
  $async.Future<$0.SetJiraBoardResponse> setJiraBoard(
      $pb.ServerContext ctx, $0.SetJiraBoardRequest request);
  $async.Future<$0.SetJiraSearchesResponse> setJiraSearches(
      $pb.ServerContext ctx, $0.SetJiraSearchesRequest request);
  $async.Future<$0.ListJiraIssuesResponse> listJiraIssues(
      $pb.ServerContext ctx, $0.ListJiraIssuesRequest request);
  $async.Future<$0.GetJiraJqlResponse> getJiraJql(
      $pb.ServerContext ctx, $0.GetJiraJqlRequest request);
  $async.Future<$0.SuggestJiraJqlResponse> suggestJiraJql(
      $pb.ServerContext ctx, $0.SuggestJiraJqlRequest request);
  $async.Future<$0.GetJiraIssueResponse> getJiraIssue(
      $pb.ServerContext ctx, $0.GetJiraIssueRequest request);
  $async.Future<$0.ListJiraTransitionsResponse> listJiraTransitions(
      $pb.ServerContext ctx, $0.ListJiraTransitionsRequest request);
  $async.Future<$0.TransitionJiraIssueResponse> transitionJiraIssue(
      $pb.ServerContext ctx, $0.TransitionJiraIssueRequest request);
  $async.Future<$0.AddJiraCommentResponse> addJiraComment(
      $pb.ServerContext ctx, $0.AddJiraCommentRequest request);
  $async.Future<$0.FindJiraIssuesResponse> findJiraIssues(
      $pb.ServerContext ctx, $0.FindJiraIssuesRequest request);
  $async.Future<$0.GetJiraAttachmentResponse> getJiraAttachment(
      $pb.ServerContext ctx, $0.GetJiraAttachmentRequest request);
  $async.Future<$0.ListGitHubHostsResponse> listGitHubHosts(
      $pb.ServerContext ctx, $0.ListGitHubHostsRequest request);
  $async.Future<$0.AddGitHubTokenResponse> addGitHubToken(
      $pb.ServerContext ctx, $0.AddGitHubTokenRequest request);
  $async.Future<$0.RemoveGitHubTokenResponse> removeGitHubToken(
      $pb.ServerContext ctx, $0.RemoveGitHubTokenRequest request);
  $async.Future<$0.AllowGitHubTokenResponse> allowGitHubToken(
      $pb.ServerContext ctx, $0.AllowGitHubTokenRequest request);
  $async.Future<$0.ListGitHubReposResponse> listGitHubRepos(
      $pb.ServerContext ctx, $0.ListGitHubReposRequest request);
  $async.Future<$0.ListGitHubInboxResponse> listGitHubInbox(
      $pb.ServerContext ctx, $0.ListGitHubInboxRequest request);
  $async.Future<$0.GetGitHubStatesResponse> getGitHubStates(
      $pb.ServerContext ctx, $0.GetGitHubStatesRequest request);
  $async.Future<$0.GetGitHubPullResponse> getGitHubPull(
      $pb.ServerContext ctx, $0.GetGitHubPullRequest request);
  $async.Future<$0.GetGitHubIssueResponse> getGitHubIssue(
      $pb.ServerContext ctx, $0.GetGitHubIssueRequest request);
  $async.Future<$0.GetGitHubFilesResponse> getGitHubFiles(
      $pb.ServerContext ctx, $0.GetGitHubFilesRequest request);
  $async.Future<$0.GetGitHubJobLogResponse> getGitHubJobLog(
      $pb.ServerContext ctx, $0.GetGitHubJobLogRequest request);
  $async.Future<$0.GetGitHubPromptResponse> getGitHubPrompt(
      $pb.ServerContext ctx, $0.GetGitHubPromptRequest request);
  $async.Future<$0.ReplyGitHubThreadResponse> replyGitHubThread(
      $pb.ServerContext ctx, $0.ReplyGitHubThreadRequest request);
  $async.Future<$0.ResolveGitHubThreadResponse> resolveGitHubThread(
      $pb.ServerContext ctx, $0.ResolveGitHubThreadRequest request);
  $async.Future<$0.AddGitHubCommentResponse> addGitHubComment(
      $pb.ServerContext ctx, $0.AddGitHubCommentRequest request);
  $async.Future<$0.SubmitGitHubReviewResponse> submitGitHubReview(
      $pb.ServerContext ctx, $0.SubmitGitHubReviewRequest request);
  $async.Future<$0.RerunGitHubChecksResponse> rerunGitHubChecks(
      $pb.ServerContext ctx, $0.RerunGitHubChecksRequest request);
  $async.Future<$0.GetCleanUpResponse> getCleanUp(
      $pb.ServerContext ctx, $0.GetCleanUpRequest request);
  $async.Future<$0.RemoveChatWorktreeResponse> removeChatWorktree(
      $pb.ServerContext ctx, $0.RemoveChatWorktreeRequest request);
  $async.Future<$0.DeleteChatBranchResponse> deleteChatBranch(
      $pb.ServerContext ctx, $0.DeleteChatBranchRequest request);
  $async.Future<$0.DeleteGitHubBranchResponse> deleteGitHubBranch(
      $pb.ServerContext ctx, $0.DeleteGitHubBranchRequest request);
  $async.Future<$0.RestoreGitHubBranchResponse> restoreGitHubBranch(
      $pb.ServerContext ctx, $0.RestoreGitHubBranchRequest request);
  $async.Future<$0.FindChatPullResponse> findChatPull(
      $pb.ServerContext ctx, $0.FindChatPullRequest request);
  $async.Future<$0.LinkChatPullResponse> linkChatPull(
      $pb.ServerContext ctx, $0.LinkChatPullRequest request);
  $async.Future<$0.EventsResponse> events(
      $pb.ServerContext ctx, $0.EventsRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'Ping':
        return $0.PingRequest();
      case 'RestartWhenIdle':
        return $0.RestartWhenIdleRequest();
      case 'CheckForUpdates':
        return $0.CheckForUpdatesRequest();
      case 'ListChats':
        return $0.ListChatsRequest();
      case 'GetChat':
        return $0.GetChatRequest();
      case 'GetChatItems':
        return $0.GetChatItemsRequest();
      case 'StartChat':
        return $0.StartChatRequest();
      case 'ListAgents':
        return $0.ListAgentsRequest();
      case 'SetUpAgent':
        return $0.SetUpAgentRequest();
      case 'RemoveAgent':
        return $0.RemoveAgentRequest();
      case 'ListAgentSessions':
        return $0.ListAgentSessionsRequest();
      case 'OpenAgentSession':
        return $0.OpenAgentSessionRequest();
      case 'MoveChat':
        return $0.MoveChatRequest();
      case 'SendPrompt':
        return $0.SendPromptRequest();
      case 'RewindChat':
        return $0.RewindChatRequest();
      case 'Unqueue':
        return $0.UnqueueRequest();
      case 'CancelTurn':
        return $0.CancelTurnRequest();
      case 'StopTask':
        return $0.StopTaskRequest();
      case 'ForkChat':
        return $0.ForkChatRequest();
      case 'CloseSideChat':
        return $0.CloseSideChatRequest();
      case 'RenameChat':
        return $0.RenameChatRequest();
      case 'RenameBranch':
        return $0.RenameBranchRequest();
      case 'SwitchBranch':
        return $0.SwitchBranchRequest();
      case 'ArchiveChat':
        return $0.ArchiveChatRequest();
      case 'SleepChat':
        return $0.SleepChatRequest();
      case 'ReopenChat':
        return $0.ReopenChatRequest();
      case 'GetMemory':
        return $0.GetMemoryRequest();
      case 'GetSettings':
        return $0.GetSettingsRequest();
      case 'SetSettings':
        return $0.SetSettingsRequest();
      case 'ListTranscripts':
        return $0.ListTranscriptsRequest();
      case 'ClearTranscripts':
        return $0.ClearTranscriptsRequest();
      case 'PlanDeleteChat':
        return $0.PlanDeleteChatRequest();
      case 'DeleteChat':
        return $0.DeleteChatRequest();
      case 'DismissRemovedChats':
        return $0.DismissRemovedChatsRequest();
      case 'AnswerPermission':
        return $0.AnswerPermissionRequest();
      case 'AnswerQuestion':
        return $0.AnswerQuestionRequest();
      case 'SetConfigOption':
        return $0.SetConfigOptionRequest();
      case 'GetDiff':
        return $0.GetDiffRequest();
      case 'GetFile':
        return $0.GetFileRequest();
      case 'WatchChatFile':
        return $0.WatchChatFileRequest();
      case 'FindChatFiles':
        return $0.FindChatFilesRequest();
      case 'ListCommits':
        return $0.ListCommitsRequest();
      case 'GetFolderStatus':
        return $0.GetFolderStatusRequest();
      case 'ListBranches':
        return $0.ListBranchesRequest();
      case 'ListFiles':
        return $0.ListFilesRequest();
      case 'GetContextUsage':
        return $0.GetContextUsageRequest();
      case 'ListMcpServers':
        return $0.ListMcpServersRequest();
      case 'AddMcpServer':
        return $0.AddMcpServerRequest();
      case 'EditMcpServer':
        return $0.EditMcpServerRequest();
      case 'RemoveMcpServer':
        return $0.RemoveMcpServerRequest();
      case 'SetMcpServerOn':
        return $0.SetMcpServerOnRequest();
      case 'LoginMcpServer':
        return $0.LoginMcpServerRequest();
      case 'LogoutMcpServer':
        return $0.LogoutMcpServerRequest();
      case 'ListSkills':
        return $0.ListSkillsRequest();
      case 'SetSkillOn':
        return $0.SetSkillOnRequest();
      case 'SetPluginOn':
        return $0.SetPluginOnRequest();
      case 'UninstallPlugin':
        return $0.UninstallPluginRequest();
      case 'TrashSkill':
        return $0.TrashSkillRequest();
      case 'LinkSkill':
        return $0.LinkSkillRequest();
      case 'ReloadChat':
        return $0.ReloadChatRequest();
      case 'OpenTerminal':
        return $0.OpenTerminalRequest();
      case 'ListTerminals':
        return $0.ListTerminalsRequest();
      case 'AttachTerminal':
        return $0.AttachTerminalRequest();
      case 'WriteTerminal':
        return $0.WriteTerminalRequest();
      case 'ResizeTerminal':
        return $0.ResizeTerminalRequest();
      case 'RenameTerminal':
        return $0.RenameTerminalRequest();
      case 'ArrangeTerminals':
        return $0.ArrangeTerminalsRequest();
      case 'RestartTerminal':
        return $0.RestartTerminalRequest();
      case 'CloseTerminal':
        return $0.CloseTerminalRequest();
      case 'CheckFolder':
        return $0.CheckFolderRequest();
      case 'TrustFolder':
        return $0.TrustFolderRequest();
      case 'GetRemote':
        return $0.GetRemoteRequest();
      case 'SetRemote':
        return $0.SetRemoteRequest();
      case 'StartPairing':
        return $0.StartPairingRequest();
      case 'ConfirmPairing':
        return $0.ConfirmPairingRequest();
      case 'RevokeDevice':
        return $0.RevokeDeviceRequest();
      case 'GetPushKey':
        return $0.GetPushKeyRequest();
      case 'SetPushSubscription':
        return $0.SetPushSubscriptionRequest();
      case 'SetDeviceView':
        return $0.SetDeviceViewRequest();
      case 'SendTestPush':
        return $0.SendTestPushRequest();
      case 'UnpairThisDevice':
        return $0.UnpairThisDeviceRequest();
      case 'Log':
        return $0.LogRequest();
      case 'ListJiraSites':
        return $0.ListJiraSitesRequest();
      case 'AddJiraSite':
        return $0.AddJiraSiteRequest();
      case 'RemoveJiraSite':
        return $0.RemoveJiraSiteRequest();
      case 'CheckJiraSite':
        return $0.CheckJiraSiteRequest();
      case 'AllowJiraToken':
        return $0.AllowJiraTokenRequest();
      case 'ListJiraBoards':
        return $0.ListJiraBoardsRequest();
      case 'SetJiraBoard':
        return $0.SetJiraBoardRequest();
      case 'SetJiraSearches':
        return $0.SetJiraSearchesRequest();
      case 'ListJiraIssues':
        return $0.ListJiraIssuesRequest();
      case 'GetJiraJql':
        return $0.GetJiraJqlRequest();
      case 'SuggestJiraJql':
        return $0.SuggestJiraJqlRequest();
      case 'GetJiraIssue':
        return $0.GetJiraIssueRequest();
      case 'ListJiraTransitions':
        return $0.ListJiraTransitionsRequest();
      case 'TransitionJiraIssue':
        return $0.TransitionJiraIssueRequest();
      case 'AddJiraComment':
        return $0.AddJiraCommentRequest();
      case 'FindJiraIssues':
        return $0.FindJiraIssuesRequest();
      case 'GetJiraAttachment':
        return $0.GetJiraAttachmentRequest();
      case 'ListGitHubHosts':
        return $0.ListGitHubHostsRequest();
      case 'AddGitHubToken':
        return $0.AddGitHubTokenRequest();
      case 'RemoveGitHubToken':
        return $0.RemoveGitHubTokenRequest();
      case 'AllowGitHubToken':
        return $0.AllowGitHubTokenRequest();
      case 'ListGitHubRepos':
        return $0.ListGitHubReposRequest();
      case 'ListGitHubInbox':
        return $0.ListGitHubInboxRequest();
      case 'GetGitHubStates':
        return $0.GetGitHubStatesRequest();
      case 'GetGitHubPull':
        return $0.GetGitHubPullRequest();
      case 'GetGitHubIssue':
        return $0.GetGitHubIssueRequest();
      case 'GetGitHubFiles':
        return $0.GetGitHubFilesRequest();
      case 'GetGitHubJobLog':
        return $0.GetGitHubJobLogRequest();
      case 'GetGitHubPrompt':
        return $0.GetGitHubPromptRequest();
      case 'ReplyGitHubThread':
        return $0.ReplyGitHubThreadRequest();
      case 'ResolveGitHubThread':
        return $0.ResolveGitHubThreadRequest();
      case 'AddGitHubComment':
        return $0.AddGitHubCommentRequest();
      case 'SubmitGitHubReview':
        return $0.SubmitGitHubReviewRequest();
      case 'RerunGitHubChecks':
        return $0.RerunGitHubChecksRequest();
      case 'GetCleanUp':
        return $0.GetCleanUpRequest();
      case 'RemoveChatWorktree':
        return $0.RemoveChatWorktreeRequest();
      case 'DeleteChatBranch':
        return $0.DeleteChatBranchRequest();
      case 'DeleteGitHubBranch':
        return $0.DeleteGitHubBranchRequest();
      case 'RestoreGitHubBranch':
        return $0.RestoreGitHubBranchRequest();
      case 'FindChatPull':
        return $0.FindChatPullRequest();
      case 'LinkChatPull':
        return $0.LinkChatPullRequest();
      case 'Events':
        return $0.EventsRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'Ping':
        return ping(ctx, request as $0.PingRequest);
      case 'RestartWhenIdle':
        return restartWhenIdle(ctx, request as $0.RestartWhenIdleRequest);
      case 'CheckForUpdates':
        return checkForUpdates(ctx, request as $0.CheckForUpdatesRequest);
      case 'ListChats':
        return listChats(ctx, request as $0.ListChatsRequest);
      case 'GetChat':
        return getChat(ctx, request as $0.GetChatRequest);
      case 'GetChatItems':
        return getChatItems(ctx, request as $0.GetChatItemsRequest);
      case 'StartChat':
        return startChat(ctx, request as $0.StartChatRequest);
      case 'ListAgents':
        return listAgents(ctx, request as $0.ListAgentsRequest);
      case 'SetUpAgent':
        return setUpAgent(ctx, request as $0.SetUpAgentRequest);
      case 'RemoveAgent':
        return removeAgent(ctx, request as $0.RemoveAgentRequest);
      case 'ListAgentSessions':
        return listAgentSessions(ctx, request as $0.ListAgentSessionsRequest);
      case 'OpenAgentSession':
        return openAgentSession(ctx, request as $0.OpenAgentSessionRequest);
      case 'MoveChat':
        return moveChat(ctx, request as $0.MoveChatRequest);
      case 'SendPrompt':
        return sendPrompt(ctx, request as $0.SendPromptRequest);
      case 'RewindChat':
        return rewindChat(ctx, request as $0.RewindChatRequest);
      case 'Unqueue':
        return unqueue(ctx, request as $0.UnqueueRequest);
      case 'CancelTurn':
        return cancelTurn(ctx, request as $0.CancelTurnRequest);
      case 'StopTask':
        return stopTask(ctx, request as $0.StopTaskRequest);
      case 'ForkChat':
        return forkChat(ctx, request as $0.ForkChatRequest);
      case 'CloseSideChat':
        return closeSideChat(ctx, request as $0.CloseSideChatRequest);
      case 'RenameChat':
        return renameChat(ctx, request as $0.RenameChatRequest);
      case 'RenameBranch':
        return renameBranch(ctx, request as $0.RenameBranchRequest);
      case 'SwitchBranch':
        return switchBranch(ctx, request as $0.SwitchBranchRequest);
      case 'ArchiveChat':
        return archiveChat(ctx, request as $0.ArchiveChatRequest);
      case 'SleepChat':
        return sleepChat(ctx, request as $0.SleepChatRequest);
      case 'ReopenChat':
        return reopenChat(ctx, request as $0.ReopenChatRequest);
      case 'GetMemory':
        return getMemory(ctx, request as $0.GetMemoryRequest);
      case 'GetSettings':
        return getSettings(ctx, request as $0.GetSettingsRequest);
      case 'SetSettings':
        return setSettings(ctx, request as $0.SetSettingsRequest);
      case 'ListTranscripts':
        return listTranscripts(ctx, request as $0.ListTranscriptsRequest);
      case 'ClearTranscripts':
        return clearTranscripts(ctx, request as $0.ClearTranscriptsRequest);
      case 'PlanDeleteChat':
        return planDeleteChat(ctx, request as $0.PlanDeleteChatRequest);
      case 'DeleteChat':
        return deleteChat(ctx, request as $0.DeleteChatRequest);
      case 'DismissRemovedChats':
        return dismissRemovedChats(
            ctx, request as $0.DismissRemovedChatsRequest);
      case 'AnswerPermission':
        return answerPermission(ctx, request as $0.AnswerPermissionRequest);
      case 'AnswerQuestion':
        return answerQuestion(ctx, request as $0.AnswerQuestionRequest);
      case 'SetConfigOption':
        return setConfigOption(ctx, request as $0.SetConfigOptionRequest);
      case 'GetDiff':
        return getDiff(ctx, request as $0.GetDiffRequest);
      case 'GetFile':
        return getFile(ctx, request as $0.GetFileRequest);
      case 'WatchChatFile':
        return watchChatFile(ctx, request as $0.WatchChatFileRequest);
      case 'FindChatFiles':
        return findChatFiles(ctx, request as $0.FindChatFilesRequest);
      case 'ListCommits':
        return listCommits(ctx, request as $0.ListCommitsRequest);
      case 'GetFolderStatus':
        return getFolderStatus(ctx, request as $0.GetFolderStatusRequest);
      case 'ListBranches':
        return listBranches(ctx, request as $0.ListBranchesRequest);
      case 'ListFiles':
        return listFiles(ctx, request as $0.ListFilesRequest);
      case 'GetContextUsage':
        return getContextUsage(ctx, request as $0.GetContextUsageRequest);
      case 'ListMcpServers':
        return listMcpServers(ctx, request as $0.ListMcpServersRequest);
      case 'AddMcpServer':
        return addMcpServer(ctx, request as $0.AddMcpServerRequest);
      case 'EditMcpServer':
        return editMcpServer(ctx, request as $0.EditMcpServerRequest);
      case 'RemoveMcpServer':
        return removeMcpServer(ctx, request as $0.RemoveMcpServerRequest);
      case 'SetMcpServerOn':
        return setMcpServerOn(ctx, request as $0.SetMcpServerOnRequest);
      case 'LoginMcpServer':
        return loginMcpServer(ctx, request as $0.LoginMcpServerRequest);
      case 'LogoutMcpServer':
        return logoutMcpServer(ctx, request as $0.LogoutMcpServerRequest);
      case 'ListSkills':
        return listSkills(ctx, request as $0.ListSkillsRequest);
      case 'SetSkillOn':
        return setSkillOn(ctx, request as $0.SetSkillOnRequest);
      case 'SetPluginOn':
        return setPluginOn(ctx, request as $0.SetPluginOnRequest);
      case 'UninstallPlugin':
        return uninstallPlugin(ctx, request as $0.UninstallPluginRequest);
      case 'TrashSkill':
        return trashSkill(ctx, request as $0.TrashSkillRequest);
      case 'LinkSkill':
        return linkSkill(ctx, request as $0.LinkSkillRequest);
      case 'ReloadChat':
        return reloadChat(ctx, request as $0.ReloadChatRequest);
      case 'OpenTerminal':
        return openTerminal(ctx, request as $0.OpenTerminalRequest);
      case 'ListTerminals':
        return listTerminals(ctx, request as $0.ListTerminalsRequest);
      case 'AttachTerminal':
        return attachTerminal(ctx, request as $0.AttachTerminalRequest);
      case 'WriteTerminal':
        return writeTerminal(ctx, request as $0.WriteTerminalRequest);
      case 'ResizeTerminal':
        return resizeTerminal(ctx, request as $0.ResizeTerminalRequest);
      case 'RenameTerminal':
        return renameTerminal(ctx, request as $0.RenameTerminalRequest);
      case 'ArrangeTerminals':
        return arrangeTerminals(ctx, request as $0.ArrangeTerminalsRequest);
      case 'RestartTerminal':
        return restartTerminal(ctx, request as $0.RestartTerminalRequest);
      case 'CloseTerminal':
        return closeTerminal(ctx, request as $0.CloseTerminalRequest);
      case 'CheckFolder':
        return checkFolder(ctx, request as $0.CheckFolderRequest);
      case 'TrustFolder':
        return trustFolder(ctx, request as $0.TrustFolderRequest);
      case 'GetRemote':
        return getRemote(ctx, request as $0.GetRemoteRequest);
      case 'SetRemote':
        return setRemote(ctx, request as $0.SetRemoteRequest);
      case 'StartPairing':
        return startPairing(ctx, request as $0.StartPairingRequest);
      case 'ConfirmPairing':
        return confirmPairing(ctx, request as $0.ConfirmPairingRequest);
      case 'RevokeDevice':
        return revokeDevice(ctx, request as $0.RevokeDeviceRequest);
      case 'GetPushKey':
        return getPushKey(ctx, request as $0.GetPushKeyRequest);
      case 'SetPushSubscription':
        return setPushSubscription(
            ctx, request as $0.SetPushSubscriptionRequest);
      case 'SetDeviceView':
        return setDeviceView(ctx, request as $0.SetDeviceViewRequest);
      case 'SendTestPush':
        return sendTestPush(ctx, request as $0.SendTestPushRequest);
      case 'UnpairThisDevice':
        return unpairThisDevice(ctx, request as $0.UnpairThisDeviceRequest);
      case 'Log':
        return log(ctx, request as $0.LogRequest);
      case 'ListJiraSites':
        return listJiraSites(ctx, request as $0.ListJiraSitesRequest);
      case 'AddJiraSite':
        return addJiraSite(ctx, request as $0.AddJiraSiteRequest);
      case 'RemoveJiraSite':
        return removeJiraSite(ctx, request as $0.RemoveJiraSiteRequest);
      case 'CheckJiraSite':
        return checkJiraSite(ctx, request as $0.CheckJiraSiteRequest);
      case 'AllowJiraToken':
        return allowJiraToken(ctx, request as $0.AllowJiraTokenRequest);
      case 'ListJiraBoards':
        return listJiraBoards(ctx, request as $0.ListJiraBoardsRequest);
      case 'SetJiraBoard':
        return setJiraBoard(ctx, request as $0.SetJiraBoardRequest);
      case 'SetJiraSearches':
        return setJiraSearches(ctx, request as $0.SetJiraSearchesRequest);
      case 'ListJiraIssues':
        return listJiraIssues(ctx, request as $0.ListJiraIssuesRequest);
      case 'GetJiraJql':
        return getJiraJql(ctx, request as $0.GetJiraJqlRequest);
      case 'SuggestJiraJql':
        return suggestJiraJql(ctx, request as $0.SuggestJiraJqlRequest);
      case 'GetJiraIssue':
        return getJiraIssue(ctx, request as $0.GetJiraIssueRequest);
      case 'ListJiraTransitions':
        return listJiraTransitions(
            ctx, request as $0.ListJiraTransitionsRequest);
      case 'TransitionJiraIssue':
        return transitionJiraIssue(
            ctx, request as $0.TransitionJiraIssueRequest);
      case 'AddJiraComment':
        return addJiraComment(ctx, request as $0.AddJiraCommentRequest);
      case 'FindJiraIssues':
        return findJiraIssues(ctx, request as $0.FindJiraIssuesRequest);
      case 'GetJiraAttachment':
        return getJiraAttachment(ctx, request as $0.GetJiraAttachmentRequest);
      case 'ListGitHubHosts':
        return listGitHubHosts(ctx, request as $0.ListGitHubHostsRequest);
      case 'AddGitHubToken':
        return addGitHubToken(ctx, request as $0.AddGitHubTokenRequest);
      case 'RemoveGitHubToken':
        return removeGitHubToken(ctx, request as $0.RemoveGitHubTokenRequest);
      case 'AllowGitHubToken':
        return allowGitHubToken(ctx, request as $0.AllowGitHubTokenRequest);
      case 'ListGitHubRepos':
        return listGitHubRepos(ctx, request as $0.ListGitHubReposRequest);
      case 'ListGitHubInbox':
        return listGitHubInbox(ctx, request as $0.ListGitHubInboxRequest);
      case 'GetGitHubStates':
        return getGitHubStates(ctx, request as $0.GetGitHubStatesRequest);
      case 'GetGitHubPull':
        return getGitHubPull(ctx, request as $0.GetGitHubPullRequest);
      case 'GetGitHubIssue':
        return getGitHubIssue(ctx, request as $0.GetGitHubIssueRequest);
      case 'GetGitHubFiles':
        return getGitHubFiles(ctx, request as $0.GetGitHubFilesRequest);
      case 'GetGitHubJobLog':
        return getGitHubJobLog(ctx, request as $0.GetGitHubJobLogRequest);
      case 'GetGitHubPrompt':
        return getGitHubPrompt(ctx, request as $0.GetGitHubPromptRequest);
      case 'ReplyGitHubThread':
        return replyGitHubThread(ctx, request as $0.ReplyGitHubThreadRequest);
      case 'ResolveGitHubThread':
        return resolveGitHubThread(
            ctx, request as $0.ResolveGitHubThreadRequest);
      case 'AddGitHubComment':
        return addGitHubComment(ctx, request as $0.AddGitHubCommentRequest);
      case 'SubmitGitHubReview':
        return submitGitHubReview(ctx, request as $0.SubmitGitHubReviewRequest);
      case 'RerunGitHubChecks':
        return rerunGitHubChecks(ctx, request as $0.RerunGitHubChecksRequest);
      case 'GetCleanUp':
        return getCleanUp(ctx, request as $0.GetCleanUpRequest);
      case 'RemoveChatWorktree':
        return removeChatWorktree(ctx, request as $0.RemoveChatWorktreeRequest);
      case 'DeleteChatBranch':
        return deleteChatBranch(ctx, request as $0.DeleteChatBranchRequest);
      case 'DeleteGitHubBranch':
        return deleteGitHubBranch(ctx, request as $0.DeleteGitHubBranchRequest);
      case 'RestoreGitHubBranch':
        return restoreGitHubBranch(
            ctx, request as $0.RestoreGitHubBranchRequest);
      case 'FindChatPull':
        return findChatPull(ctx, request as $0.FindChatPullRequest);
      case 'LinkChatPull':
        return linkChatPull(ctx, request as $0.LinkChatPullRequest);
      case 'Events':
        return events(ctx, request as $0.EventsRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => NushiServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => NushiServiceBase$messageJson;
}
