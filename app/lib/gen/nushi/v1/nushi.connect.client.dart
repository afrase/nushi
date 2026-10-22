//
//  Generated code. Do not modify.
//  source: nushi/v1/nushi.proto
//

import "package:connectrpc/connect.dart" as connect;

import "nushi.pb.dart" as nushiv1nushi;
import "nushi.connect.spec.dart" as specs;

extension type NushiServiceClient(connect.Transport _transport) {
  Future<nushiv1nushi.PingResponse> ping(
    nushiv1nushi.PingRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.ping,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Starts an agent in a folder and opens a chat with it.
  Future<nushiv1nushi.StartChatResponse> startChat(
    nushiv1nushi.StartChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.startChat,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Sends a prompt; the reply arrives as events.
  Future<nushiv1nushi.SendPromptResponse> sendPrompt(
    nushiv1nushi.SendPromptRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.sendPrompt,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Answers a pending permission prompt with one of its options.
  Future<nushiv1nushi.AnswerPermissionResponse> answerPermission(
    nushiv1nushi.AnswerPermissionRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.answerPermission,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Streams every change to every chat from now on. The first message is
  /// empty: it says the subscription is live.
  Stream<nushiv1nushi.EventsResponse> events(
    nushiv1nushi.EventsRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).server(
      specs.NushiService.events,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }
}
