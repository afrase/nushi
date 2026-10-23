//
//  Generated code. Do not modify.
//  source: nushi/v1/nushi.proto
//

import "package:connectrpc/connect.dart" as connect;
import "nushi.pb.dart" as nushiv1nushi;
import "nushi.connect.spec.dart" as specs;

extension type NushiServiceClient (connect.Transport _transport) {
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

  /// Lists every stored chat.
  Future<nushiv1nushi.ListChatsResponse> listChats(
    nushiv1nushi.ListChatsRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.listChats,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Returns everything a chat's events have built so far, to pick it up
  /// after (re)connecting.
  Future<nushiv1nushi.GetChatResponse> getChat(
    nushiv1nushi.GetChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.getChat,
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

  /// Moves a chat to another folder, or to a new worktree. A chat without
  /// messages starts a new session there (and a worktree it leaves is
  /// removed if it holds no work); one with messages keeps its history, in a
  /// fork of its session there. Refused while the chat is busy. If the move
  /// fails the chat stays where it was, with a notice saying why.
  Future<nushiv1nushi.MoveChatResponse> moveChat(
    nushiv1nushi.MoveChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.moveChat,
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

  /// Stops the chat's running turn (ACP session/cancel). The turn ends with a
  /// "cancelled" notice, and prompts it was waiting on are cancelled.
  Future<nushiv1nushi.CancelTurnResponse> cancelTurn(
    nushiv1nushi.CancelTurnRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.cancelTurn,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Opens a side chat: a session the agent forks from the chat's (ACP
  /// session/fork, when status.can_fork). It knows the conversation so far
  /// but doesn't add to it, isn't listed or stored, and ends with
  /// CloseSideChat. Its items and status come as events like any chat's.
  Future<nushiv1nushi.ForkChatResponse> forkChat(
    nushiv1nushi.ForkChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.forkChat,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<nushiv1nushi.CloseSideChatResponse> closeSideChat(
    nushiv1nushi.CloseSideChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.closeSideChat,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Sets the chat's title; it wins over the agent's. An empty title goes
  /// back to the agent's.
  Future<nushiv1nushi.RenameChatResponse> renameChat(
    nushiv1nushi.RenameChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.renameChat,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Archives a chat: its turn is cancelled and its agent stops; it stays
  /// listed, read-only. Unarchiving reopens it (ACP session/load).
  Future<nushiv1nushi.ArchiveChatResponse> archiveChat(
    nushiv1nushi.ArchiveChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.archiveChat,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Forgets a chat: its turn is cancelled, its agent stops, and Nushi's
  /// record of it goes. The agent's own history of the session stays.
  Future<nushiv1nushi.RemoveChatResponse> removeChat(
    nushiv1nushi.RemoveChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.removeChat,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Says what DeleteChat removes. The first time, the daemon starts the
  /// agent to learn whether it can delete its history.
  Future<nushiv1nushi.PlanDeleteChatResponse> planDeleteChat(
    nushiv1nushi.PlanDeleteChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.planDeleteChat,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Deletes a chat: its turn is cancelled and its agent stops, the agent
  /// deletes its history of each of the chat's sessions (ACP session/delete,
  /// when it can), the chat's scratch folder goes, and Nushi's record of it.
  Future<nushiv1nushi.DeleteChatResponse> deleteChat(
    nushiv1nushi.DeleteChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.deleteChat,
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

  /// Answers a pending question, or declines it.
  Future<nushiv1nushi.AnswerQuestionResponse> answerQuestion(
    nushiv1nushi.AnswerQuestionRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.answerQuestion,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Sets one of a chat's config options (mode, model, ...). Picking a mode
  /// makes new chats with the same agent start in it.
  Future<nushiv1nushi.SetConfigOptionResponse> setConfigOption(
    nushiv1nushi.SetConfigOptionRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.setConfigOption,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Returns a folder's uncommitted changes against HEAD, untracked files
  /// included.
  Future<nushiv1nushi.GetDiffResponse> getDiff(
    nushiv1nushi.GetDiffRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.getDiff,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Sums up a folder's uncommitted changes (as GetDiff lists them) and names
  /// its branch.
  Future<nushiv1nushi.GetFolderStatusResponse> getFolderStatus(
    nushiv1nushi.GetFolderStatusRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.getFolderStatus,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Lists a folder's files (up to 20,000) for @-mentions: in a git
  /// repository the ones git doesn't ignore.
  Future<nushiv1nushi.ListFilesResponse> listFiles(
    nushiv1nushi.ListFilesRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.listFiles,
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
