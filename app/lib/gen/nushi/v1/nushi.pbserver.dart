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
  $async.Future<$0.StartChatResponse> startChat(
      $pb.ServerContext ctx, $0.StartChatRequest request);
  $async.Future<$0.SendPromptResponse> sendPrompt(
      $pb.ServerContext ctx, $0.SendPromptRequest request);
  $async.Future<$0.AnswerPermissionResponse> answerPermission(
      $pb.ServerContext ctx, $0.AnswerPermissionRequest request);
  $async.Future<$0.EventsResponse> events(
      $pb.ServerContext ctx, $0.EventsRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'Ping':
        return $0.PingRequest();
      case 'StartChat':
        return $0.StartChatRequest();
      case 'SendPrompt':
        return $0.SendPromptRequest();
      case 'AnswerPermission':
        return $0.AnswerPermissionRequest();
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
      case 'StartChat':
        return startChat(ctx, request as $0.StartChatRequest);
      case 'SendPrompt':
        return sendPrompt(ctx, request as $0.SendPromptRequest);
      case 'AnswerPermission':
        return answerPermission(ctx, request as $0.AnswerPermissionRequest);
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
