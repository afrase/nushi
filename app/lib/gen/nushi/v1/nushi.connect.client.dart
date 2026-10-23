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

  /// Cuts a chat back to just before one of its user messages (when
  /// status.can_rewind and the message's fork_at is set, or it is the first)
  /// and returns that message. The agent's session is forked there: a new
  /// session id, the same chat. Files aren't rewound. Refused while the chat
  /// is busy.
  Future<nushiv1nushi.RewindChatResponse> rewindChat(
    nushiv1nushi.RewindChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.rewindChat,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Takes a message out of the chat's queue before the agent gets it, and
  /// returns it. Refused once the agent has it.
  Future<nushiv1nushi.UnqueueResponse> unqueue(
    nushiv1nushi.UnqueueRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.unqueue,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Stops the chat's running turn (ACP session/cancel). The turn ends with a
  /// "cancelled" notice, and prompts it was waiting on are cancelled. It can
  /// take the last message back too (take_back).
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

  /// Deletes a chat: its turn is cancelled and its agent stops, its worktree
  /// and branch go if asked, the agent deletes its history of each of the
  /// chat's sessions (ACP session/delete, when it can), the chat's scratch
  /// folder goes, and Nushi's record of it.
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
  /// included, or everything since its branch left a base, or what commits
  /// changed.
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

  /// Lists a branch's commits since a base, or the last ones.
  Future<nushiv1nushi.ListCommitsResponse> listCommits(
    nushiv1nushi.ListCommitsRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.listCommits,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Sums up a folder's changes (as GetDiff lists them) and names its
  /// branch.
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

  /// Asks the chat's agent, unseen, what fills its context (Claude's
  /// /context), in a throwaway fork of its session, while the chat is idle.
  /// Refused when the agent can't fork.
  Future<nushiv1nushi.GetContextUsageResponse> getContextUsage(
    nushiv1nushi.GetContextUsageRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.getContextUsage,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Lists the MCP servers the agent's config gives a folder, read from the
  /// agent's own files, env and header values masked. With check_health, the
  /// agent connects to each and says how that went (Claude's `claude mcp list`,
  /// seconds), and servers only it knows (plugins', claude.ai connectors)
  /// are added.
  Future<nushiv1nushi.ListMcpServersResponse> listMcpServers(
    nushiv1nushi.ListMcpServersRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.listMcpServers,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Add, edit and remove an MCP server in a scope ("user", "project",
  /// "local"), through the agent's own CLI; the folder names the project.
  /// Editing keeps the name and scope, and env and header values sent as
  /// "••••" keep the values they had; if the new config is refused, the old
  /// one is put back. Running chats the change reaches get
  /// status.mcp_changed.
  Future<nushiv1nushi.AddMcpServerResponse> addMcpServer(
    nushiv1nushi.AddMcpServerRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.addMcpServer,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<nushiv1nushi.EditMcpServerResponse> editMcpServer(
    nushiv1nushi.EditMcpServerRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.editMcpServer,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<nushiv1nushi.RemoveMcpServerResponse> removeMcpServer(
    nushiv1nushi.RemoveMcpServerRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.removeMcpServer,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Turns a project's .mcp.json server on for the folder's project, which
  /// approves it, or off, which rejects it (Claude's
  /// enabledMcpjsonServers and disabledMcpjsonServers in the project's
  /// .claude/settings.local.json).
  Future<nushiv1nushi.SetMcpServerOnResponse> setMcpServerOn(
    nushiv1nushi.SetMcpServerOnRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.setMcpServerOn,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Signs in to a server that needs OAuth: the agent opens the browser and
  /// the call returns once the sign-in is done there, or failed (a few
  /// minutes at most). Logout forgets the sign-in.
  Future<nushiv1nushi.LoginMcpServerResponse> loginMcpServer(
    nushiv1nushi.LoginMcpServerRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.loginMcpServer,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<nushiv1nushi.LogoutMcpServerResponse> logoutMcpServer(
    nushiv1nushi.LogoutMcpServerRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.logoutMcpServer,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Reopens a chat's session on a new agent (ACP session/load), which
  /// replays its transcript, so it uses the MCP servers as they are now.
  /// Refused while it is busy.
  Future<nushiv1nushi.ReloadChatResponse> reloadChat(
    nushiv1nushi.ReloadChatRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.reloadChat,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Opens a terminal for a chat: the user's login shell, in the chat's
  /// folder (its worktree, for a worktree chat) or in a given one. The
  /// daemon owns it, so it outlives the app, but not the daemon. Changes to
  /// a chat's terminals come as events.
  Future<nushiv1nushi.OpenTerminalResponse> openTerminal(
    nushiv1nushi.OpenTerminalRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.openTerminal,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<nushiv1nushi.ListTerminalsResponse> listTerminals(
    nushiv1nushi.ListTerminalsRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.listTerminals,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Streams a terminal's output: first what it kept (the last 1 MB, maybe
  /// empty), then new output, and a last message once its shell has exited.
  /// A client that falls far behind is cut off and attaches again.
  Stream<nushiv1nushi.AttachTerminalResponse> attachTerminal(
    nushiv1nushi.AttachTerminalRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).server(
      specs.NushiService.attachTerminal,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<nushiv1nushi.WriteTerminalResponse> writeTerminal(
    nushiv1nushi.WriteTerminalRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.writeTerminal,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<nushiv1nushi.ResizeTerminalResponse> resizeTerminal(
    nushiv1nushi.ResizeTerminalRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.resizeTerminal,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Names a terminal; an empty name goes back to the one it shows by
  /// itself.
  Future<nushiv1nushi.RenameTerminalResponse> renameTerminal(
    nushiv1nushi.RenameTerminalRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.renameTerminal,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Puts a chat's terminals in an order.
  Future<nushiv1nushi.ArrangeTerminalsResponse> arrangeTerminals(
    nushiv1nushi.ArrangeTerminalsRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.arrangeTerminals,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Starts a new shell in a terminal's folder in place of its old one (a
  /// shell that exited), keeping its place and name.
  Future<nushiv1nushi.RestartTerminalResponse> restartTerminal(
    nushiv1nushi.RestartTerminalRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.restartTerminal,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Closes a terminal: its shell is hung up, then killed after a short
  /// grace, along with what still runs in it.
  Future<nushiv1nushi.CloseTerminalResponse> closeTerminal(
    nushiv1nushi.CloseTerminalRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.closeTerminal,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Says what a folder brings for the agent to run on its own (MCP
  /// servers, hooks, helper commands) when neither the agent nor Nushi was
  /// told to trust it; nothing when it is trusted or brings nothing. Ask
  /// before starting or moving a chat there.
  Future<nushiv1nushi.CheckFolderResponse> checkFolder(
    nushiv1nushi.CheckFolderRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.checkFolder,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Remembers that the user starts chats in a folder anyway (its
  /// repository, outside git the folders under it too).
  Future<nushiv1nushi.TrustFolderResponse> trustFolder(
    nushiv1nushi.TrustFolderRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NushiService.trustFolder,
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
