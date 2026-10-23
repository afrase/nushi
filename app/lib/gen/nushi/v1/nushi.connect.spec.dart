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

  /// Moves a chat to another folder, or to a new worktree. A chat without
  /// messages starts a new session there (and a worktree it leaves is
  /// removed if it holds no work); one with messages keeps its history, in a
  /// fork of its session there. Refused while the chat is busy. If the move
  /// fails the chat stays where it was, with a notice saying why.
  static const moveChat = connect.Spec(
    '/$name/MoveChat',
    connect.StreamType.unary,
    nushiv1nushi.MoveChatRequest.new,
    nushiv1nushi.MoveChatResponse.new,
  );

  /// Sends a prompt; the reply arrives as events.
  static const sendPrompt = connect.Spec(
    '/$name/SendPrompt',
    connect.StreamType.unary,
    nushiv1nushi.SendPromptRequest.new,
    nushiv1nushi.SendPromptResponse.new,
  );

  /// Cuts a chat back to just before one of its user messages (when
  /// status.can_rewind and the message's fork_at is set, or it is the first)
  /// and returns that message. The agent's session is forked there: a new
  /// session id, the same chat. Files aren't rewound. Refused while the chat
  /// is busy.
  static const rewindChat = connect.Spec(
    '/$name/RewindChat',
    connect.StreamType.unary,
    nushiv1nushi.RewindChatRequest.new,
    nushiv1nushi.RewindChatResponse.new,
  );

  /// Takes a message out of the chat's queue before the agent gets it, and
  /// returns it. Refused once the agent has it.
  static const unqueue = connect.Spec(
    '/$name/Unqueue',
    connect.StreamType.unary,
    nushiv1nushi.UnqueueRequest.new,
    nushiv1nushi.UnqueueResponse.new,
  );

  /// Stops the chat's running turn (ACP session/cancel). The turn ends with a
  /// "cancelled" notice, and prompts it was waiting on are cancelled. It can
  /// take the last message back too (take_back).
  static const cancelTurn = connect.Spec(
    '/$name/CancelTurn',
    connect.StreamType.unary,
    nushiv1nushi.CancelTurnRequest.new,
    nushiv1nushi.CancelTurnResponse.new,
  );

  /// Opens a side chat: a session the agent forks from the chat's (ACP
  /// session/fork, when status.can_fork). It knows the conversation so far
  /// but doesn't add to it, isn't listed or stored, and ends with
  /// CloseSideChat. Its items and status come as events like any chat's.
  static const forkChat = connect.Spec(
    '/$name/ForkChat',
    connect.StreamType.unary,
    nushiv1nushi.ForkChatRequest.new,
    nushiv1nushi.ForkChatResponse.new,
  );

  static const closeSideChat = connect.Spec(
    '/$name/CloseSideChat',
    connect.StreamType.unary,
    nushiv1nushi.CloseSideChatRequest.new,
    nushiv1nushi.CloseSideChatResponse.new,
  );

  /// Sets the chat's title; it wins over the agent's. An empty title goes
  /// back to the agent's.
  static const renameChat = connect.Spec(
    '/$name/RenameChat',
    connect.StreamType.unary,
    nushiv1nushi.RenameChatRequest.new,
    nushiv1nushi.RenameChatResponse.new,
  );

  /// Archives a chat: its turn is cancelled and its agent stops; it stays
  /// listed, read-only. Unarchiving reopens it (ACP session/load).
  static const archiveChat = connect.Spec(
    '/$name/ArchiveChat',
    connect.StreamType.unary,
    nushiv1nushi.ArchiveChatRequest.new,
    nushiv1nushi.ArchiveChatResponse.new,
  );

  /// Says what DeleteChat removes. The first time, the daemon starts the
  /// agent to learn whether it can delete its history.
  static const planDeleteChat = connect.Spec(
    '/$name/PlanDeleteChat',
    connect.StreamType.unary,
    nushiv1nushi.PlanDeleteChatRequest.new,
    nushiv1nushi.PlanDeleteChatResponse.new,
  );

  /// Deletes a chat: its turn is cancelled and its agent stops, its worktree
  /// and branch go if asked, the agent deletes its history of each of the
  /// chat's sessions (ACP session/delete, when it can), the chat's scratch
  /// folder goes, and Nushi's record of it.
  static const deleteChat = connect.Spec(
    '/$name/DeleteChat',
    connect.StreamType.unary,
    nushiv1nushi.DeleteChatRequest.new,
    nushiv1nushi.DeleteChatResponse.new,
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
  /// included, or everything since its branch left a base, or what commits
  /// changed.
  static const getDiff = connect.Spec(
    '/$name/GetDiff',
    connect.StreamType.unary,
    nushiv1nushi.GetDiffRequest.new,
    nushiv1nushi.GetDiffResponse.new,
  );

  /// Lists a branch's commits since a base, or the last ones.
  static const listCommits = connect.Spec(
    '/$name/ListCommits',
    connect.StreamType.unary,
    nushiv1nushi.ListCommitsRequest.new,
    nushiv1nushi.ListCommitsResponse.new,
  );

  /// Sums up a folder's changes (as GetDiff lists them) and names its
  /// branch.
  static const getFolderStatus = connect.Spec(
    '/$name/GetFolderStatus',
    connect.StreamType.unary,
    nushiv1nushi.GetFolderStatusRequest.new,
    nushiv1nushi.GetFolderStatusResponse.new,
  );

  /// Lists a folder's files (up to 20,000) for @-mentions: in a git
  /// repository the ones git doesn't ignore.
  static const listFiles = connect.Spec(
    '/$name/ListFiles',
    connect.StreamType.unary,
    nushiv1nushi.ListFilesRequest.new,
    nushiv1nushi.ListFilesResponse.new,
  );

  /// Asks the chat's agent, unseen, what fills its context (Claude's
  /// /context), in a throwaway fork of its session, while the chat is idle.
  /// Refused when the agent can't fork.
  static const getContextUsage = connect.Spec(
    '/$name/GetContextUsage',
    connect.StreamType.unary,
    nushiv1nushi.GetContextUsageRequest.new,
    nushiv1nushi.GetContextUsageResponse.new,
  );

  /// Lists the MCP servers the agent's config gives a folder, read from the
  /// agent's own files, env and header values masked. With check_health, the
  /// agent connects to each and says how that went (Claude's `claude mcp list`,
  /// seconds), and servers only it knows (plugins', claude.ai connectors)
  /// are added.
  static const listMcpServers = connect.Spec(
    '/$name/ListMcpServers',
    connect.StreamType.unary,
    nushiv1nushi.ListMcpServersRequest.new,
    nushiv1nushi.ListMcpServersResponse.new,
  );

  /// Add, edit and remove an MCP server in a scope ("user", "project",
  /// "local"), through the agent's own CLI; the folder names the project.
  /// Editing keeps the name and scope, and env and header values sent as
  /// "••••" keep the values they had; if the new config is refused, the old
  /// one is put back. Running chats the change reaches get
  /// status.mcp_changed.
  static const addMcpServer = connect.Spec(
    '/$name/AddMcpServer',
    connect.StreamType.unary,
    nushiv1nushi.AddMcpServerRequest.new,
    nushiv1nushi.AddMcpServerResponse.new,
  );

  static const editMcpServer = connect.Spec(
    '/$name/EditMcpServer',
    connect.StreamType.unary,
    nushiv1nushi.EditMcpServerRequest.new,
    nushiv1nushi.EditMcpServerResponse.new,
  );

  static const removeMcpServer = connect.Spec(
    '/$name/RemoveMcpServer',
    connect.StreamType.unary,
    nushiv1nushi.RemoveMcpServerRequest.new,
    nushiv1nushi.RemoveMcpServerResponse.new,
  );

  /// Turns a project's .mcp.json server on for the folder's project, which
  /// approves it, or off, which rejects it (Claude's
  /// enabledMcpjsonServers and disabledMcpjsonServers in the project's
  /// .claude/settings.local.json).
  static const setMcpServerOn = connect.Spec(
    '/$name/SetMcpServerOn',
    connect.StreamType.unary,
    nushiv1nushi.SetMcpServerOnRequest.new,
    nushiv1nushi.SetMcpServerOnResponse.new,
  );

  /// Signs in to a server that needs OAuth: the agent opens the browser and
  /// the call returns once the sign-in is done there, or failed (a few
  /// minutes at most). Logout forgets the sign-in.
  static const loginMcpServer = connect.Spec(
    '/$name/LoginMcpServer',
    connect.StreamType.unary,
    nushiv1nushi.LoginMcpServerRequest.new,
    nushiv1nushi.LoginMcpServerResponse.new,
  );

  static const logoutMcpServer = connect.Spec(
    '/$name/LogoutMcpServer',
    connect.StreamType.unary,
    nushiv1nushi.LogoutMcpServerRequest.new,
    nushiv1nushi.LogoutMcpServerResponse.new,
  );

  /// Reopens a chat's session on a new agent (ACP session/load), which
  /// replays its transcript, so it uses the MCP servers as they are now.
  /// Refused while it is busy.
  static const reloadChat = connect.Spec(
    '/$name/ReloadChat',
    connect.StreamType.unary,
    nushiv1nushi.ReloadChatRequest.new,
    nushiv1nushi.ReloadChatResponse.new,
  );

  /// Opens a terminal for a chat: the user's login shell, in the chat's
  /// folder (its worktree, for a worktree chat) or in a given one. The
  /// daemon owns it, so it outlives the app, but not the daemon. Changes to
  /// a chat's terminals come as events.
  static const openTerminal = connect.Spec(
    '/$name/OpenTerminal',
    connect.StreamType.unary,
    nushiv1nushi.OpenTerminalRequest.new,
    nushiv1nushi.OpenTerminalResponse.new,
  );

  static const listTerminals = connect.Spec(
    '/$name/ListTerminals',
    connect.StreamType.unary,
    nushiv1nushi.ListTerminalsRequest.new,
    nushiv1nushi.ListTerminalsResponse.new,
  );

  /// Streams a terminal's output: first what it kept (the last 1 MB, maybe
  /// empty), then new output, and a last message once its shell has exited.
  /// A client that falls far behind is cut off and attaches again.
  static const attachTerminal = connect.Spec(
    '/$name/AttachTerminal',
    connect.StreamType.server,
    nushiv1nushi.AttachTerminalRequest.new,
    nushiv1nushi.AttachTerminalResponse.new,
  );

  static const writeTerminal = connect.Spec(
    '/$name/WriteTerminal',
    connect.StreamType.unary,
    nushiv1nushi.WriteTerminalRequest.new,
    nushiv1nushi.WriteTerminalResponse.new,
  );

  static const resizeTerminal = connect.Spec(
    '/$name/ResizeTerminal',
    connect.StreamType.unary,
    nushiv1nushi.ResizeTerminalRequest.new,
    nushiv1nushi.ResizeTerminalResponse.new,
  );

  /// Names a terminal; an empty name goes back to the one it shows by
  /// itself.
  static const renameTerminal = connect.Spec(
    '/$name/RenameTerminal',
    connect.StreamType.unary,
    nushiv1nushi.RenameTerminalRequest.new,
    nushiv1nushi.RenameTerminalResponse.new,
  );

  /// Puts a chat's terminals in an order.
  static const arrangeTerminals = connect.Spec(
    '/$name/ArrangeTerminals',
    connect.StreamType.unary,
    nushiv1nushi.ArrangeTerminalsRequest.new,
    nushiv1nushi.ArrangeTerminalsResponse.new,
  );

  /// Starts a new shell in a terminal's folder in place of its old one (a
  /// shell that exited), keeping its place and name.
  static const restartTerminal = connect.Spec(
    '/$name/RestartTerminal',
    connect.StreamType.unary,
    nushiv1nushi.RestartTerminalRequest.new,
    nushiv1nushi.RestartTerminalResponse.new,
  );

  /// Closes a terminal: its shell is hung up, then killed after a short
  /// grace, along with what still runs in it.
  static const closeTerminal = connect.Spec(
    '/$name/CloseTerminal',
    connect.StreamType.unary,
    nushiv1nushi.CloseTerminalRequest.new,
    nushiv1nushi.CloseTerminalResponse.new,
  );

  /// Says what a folder brings for the agent to run on its own (MCP
  /// servers, hooks, helper commands) when neither the agent nor Nushi was
  /// told to trust it; nothing when it is trusted or brings nothing. Ask
  /// before starting or moving a chat there.
  static const checkFolder = connect.Spec(
    '/$name/CheckFolder',
    connect.StreamType.unary,
    nushiv1nushi.CheckFolderRequest.new,
    nushiv1nushi.CheckFolderResponse.new,
  );

  /// Remembers that the user starts chats in a folder anyway (its
  /// repository, outside git the folders under it too).
  static const trustFolder = connect.Spec(
    '/$name/TrustFolder',
    connect.StreamType.unary,
    nushiv1nushi.TrustFolderRequest.new,
    nushiv1nushi.TrustFolderResponse.new,
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
