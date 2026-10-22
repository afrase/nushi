//
//  Generated code. Do not modify.
//  source: nushi/v1/nushi.proto
//

import "package:connectrpc/connect.dart" as connect;

import "nushi.pb.dart" as nushiv1nushi;

abstract final class NushiService {
  /// Fully-qualified name of the NushiService service.
  static const name = 'nushi.v1.NushiService';

  static const ping = connect.Spec(
    '/$name/Ping',
    connect.StreamType.unary,
    nushiv1nushi.PingRequest.new,
    nushiv1nushi.PingResponse.new,
  );

  /// Lists every stored chat.
  static const listChats = connect.Spec(
    '/$name/ListChats',
    connect.StreamType.unary,
    nushiv1nushi.ListChatsRequest.new,
    nushiv1nushi.ListChatsResponse.new,
  );

  /// Returns everything a chat's events have built so far, to pick it up
  /// after (re)connecting.
  static const getChat = connect.Spec(
    '/$name/GetChat',
    connect.StreamType.unary,
    nushiv1nushi.GetChatRequest.new,
    nushiv1nushi.GetChatResponse.new,
  );

  /// Starts an agent in a folder and opens a chat with it.
  static const startChat = connect.Spec(
    '/$name/StartChat',
    connect.StreamType.unary,
    nushiv1nushi.StartChatRequest.new,
    nushiv1nushi.StartChatResponse.new,
  );

  /// Sends a prompt; the reply arrives as events.
  static const sendPrompt = connect.Spec(
    '/$name/SendPrompt',
    connect.StreamType.unary,
    nushiv1nushi.SendPromptRequest.new,
    nushiv1nushi.SendPromptResponse.new,
  );

  /// Answers a pending permission prompt with one of its options.
  static const answerPermission = connect.Spec(
    '/$name/AnswerPermission',
    connect.StreamType.unary,
    nushiv1nushi.AnswerPermissionRequest.new,
    nushiv1nushi.AnswerPermissionResponse.new,
  );

  /// Answers a pending question, or declines it.
  static const answerQuestion = connect.Spec(
    '/$name/AnswerQuestion',
    connect.StreamType.unary,
    nushiv1nushi.AnswerQuestionRequest.new,
    nushiv1nushi.AnswerQuestionResponse.new,
  );

  /// Sets one of a chat's config options (mode, model, ...). Picking a mode
  /// makes new chats with the same agent start in it.
  static const setConfigOption = connect.Spec(
    '/$name/SetConfigOption',
    connect.StreamType.unary,
    nushiv1nushi.SetConfigOptionRequest.new,
    nushiv1nushi.SetConfigOptionResponse.new,
  );

  /// Returns a folder's uncommitted changes against HEAD, untracked files
  /// included.
  static const getDiff = connect.Spec(
    '/$name/GetDiff',
    connect.StreamType.unary,
    nushiv1nushi.GetDiffRequest.new,
    nushiv1nushi.GetDiffResponse.new,
  );

  /// Streams every change to every chat from now on. The first message is
  /// empty: it says the subscription is live.
  static const events = connect.Spec(
    '/$name/Events',
    connect.StreamType.server,
    nushiv1nushi.EventsRequest.new,
    nushiv1nushi.EventsResponse.new,
  );
}
