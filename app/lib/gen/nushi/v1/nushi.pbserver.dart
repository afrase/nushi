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
  $async.Future<$0.ListChatsResponse> listChats(
      $pb.ServerContext ctx, $0.ListChatsRequest request);
  $async.Future<$0.GetChatResponse> getChat(
      $pb.ServerContext ctx, $0.GetChatRequest request);
  $async.Future<$0.StartChatResponse> startChat(
      $pb.ServerContext ctx, $0.StartChatRequest request);
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
  $async.Future<$0.ForkChatResponse> forkChat(
      $pb.ServerContext ctx, $0.ForkChatRequest request);
  $async.Future<$0.CloseSideChatResponse> closeSideChat(
      $pb.ServerContext ctx, $0.CloseSideChatRequest request);
  $async.Future<$0.RenameChatResponse> renameChat(
      $pb.ServerContext ctx, $0.RenameChatRequest request);
  $async.Future<$0.ArchiveChatResponse> archiveChat(
      $pb.ServerContext ctx, $0.ArchiveChatRequest request);
  $async.Future<$0.RemoveChatResponse> removeChat(
      $pb.ServerContext ctx, $0.RemoveChatRequest request);
  $async.Future<$0.PlanDeleteChatResponse> planDeleteChat(
      $pb.ServerContext ctx, $0.PlanDeleteChatRequest request);
  $async.Future<$0.DeleteChatResponse> deleteChat(
      $pb.ServerContext ctx, $0.DeleteChatRequest request);
  $async.Future<$0.AnswerPermissionResponse> answerPermission(
      $pb.ServerContext ctx, $0.AnswerPermissionRequest request);
  $async.Future<$0.AnswerQuestionResponse> answerQuestion(
      $pb.ServerContext ctx, $0.AnswerQuestionRequest request);
  $async.Future<$0.SetConfigOptionResponse> setConfigOption(
      $pb.ServerContext ctx, $0.SetConfigOptionRequest request);
  $async.Future<$0.GetDiffResponse> getDiff(
      $pb.ServerContext ctx, $0.GetDiffRequest request);
  $async.Future<$0.ListCommitsResponse> listCommits(
      $pb.ServerContext ctx, $0.ListCommitsRequest request);
  $async.Future<$0.GetFolderStatusResponse> getFolderStatus(
      $pb.ServerContext ctx, $0.GetFolderStatusRequest request);
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
  $async.Future<$0.ReloadChatResponse> reloadChat(
      $pb.ServerContext ctx, $0.ReloadChatRequest request);
  $async.Future<$0.EventsResponse> events(
      $pb.ServerContext ctx, $0.EventsRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'Ping':
        return $0.PingRequest();
      case 'ListChats':
        return $0.ListChatsRequest();
      case 'GetChat':
        return $0.GetChatRequest();
      case 'StartChat':
        return $0.StartChatRequest();
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
      case 'ForkChat':
        return $0.ForkChatRequest();
      case 'CloseSideChat':
        return $0.CloseSideChatRequest();
      case 'RenameChat':
        return $0.RenameChatRequest();
      case 'ArchiveChat':
        return $0.ArchiveChatRequest();
      case 'RemoveChat':
        return $0.RemoveChatRequest();
      case 'PlanDeleteChat':
        return $0.PlanDeleteChatRequest();
      case 'DeleteChat':
        return $0.DeleteChatRequest();
      case 'AnswerPermission':
        return $0.AnswerPermissionRequest();
      case 'AnswerQuestion':
        return $0.AnswerQuestionRequest();
      case 'SetConfigOption':
        return $0.SetConfigOptionRequest();
      case 'GetDiff':
        return $0.GetDiffRequest();
      case 'ListCommits':
        return $0.ListCommitsRequest();
      case 'GetFolderStatus':
        return $0.GetFolderStatusRequest();
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
      case 'ReloadChat':
        return $0.ReloadChatRequest();
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
      case 'ListChats':
        return listChats(ctx, request as $0.ListChatsRequest);
      case 'GetChat':
        return getChat(ctx, request as $0.GetChatRequest);
      case 'StartChat':
        return startChat(ctx, request as $0.StartChatRequest);
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
      case 'ForkChat':
        return forkChat(ctx, request as $0.ForkChatRequest);
      case 'CloseSideChat':
        return closeSideChat(ctx, request as $0.CloseSideChatRequest);
      case 'RenameChat':
        return renameChat(ctx, request as $0.RenameChatRequest);
      case 'ArchiveChat':
        return archiveChat(ctx, request as $0.ArchiveChatRequest);
      case 'RemoveChat':
        return removeChat(ctx, request as $0.RemoveChatRequest);
      case 'PlanDeleteChat':
        return planDeleteChat(ctx, request as $0.PlanDeleteChatRequest);
      case 'DeleteChat':
        return deleteChat(ctx, request as $0.DeleteChatRequest);
      case 'AnswerPermission':
        return answerPermission(ctx, request as $0.AnswerPermissionRequest);
      case 'AnswerQuestion':
        return answerQuestion(ctx, request as $0.AnswerQuestionRequest);
      case 'SetConfigOption':
        return setConfigOption(ctx, request as $0.SetConfigOptionRequest);
      case 'GetDiff':
        return getDiff(ctx, request as $0.GetDiffRequest);
      case 'ListCommits':
        return listCommits(ctx, request as $0.ListCommitsRequest);
      case 'GetFolderStatus':
        return getFolderStatus(ctx, request as $0.GetFolderStatusRequest);
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
      case 'ReloadChat':
        return reloadChat(ctx, request as $0.ReloadChatRequest);
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
