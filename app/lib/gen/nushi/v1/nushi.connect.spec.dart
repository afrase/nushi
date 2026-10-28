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

  /// Stops the daemon once no chat has a turn running or waiting on the
  /// user, nothing is queued and no terminal runs a command; prompts are
  /// refused from then on (Unavailable), to be sent again to the new one.
  /// The Mac's app asks while it bundles a newer daemon than the one
  /// running, again every few seconds (an ask lapses after 15 s, so an app
  /// that quit leaves the daemon running), and starts the new one once
  /// this one has gone. Not on a device's channel. API 77.
  static const restartWhenIdle = connect.Spec(
    '/$name/RestartWhenIdle',
    connect.StreamType.unary,
    nushiv1nushi.RestartWhenIdleRequest.new,
    nushiv1nushi.RestartWhenIdleResponse.new,
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

  /// A chat's items before one of them, a page at a time: for a client that
  /// took only the recent part (GetChatRequest.recent), as it scrolls up.
  static const getChatItems = connect.Spec(
    '/$name/GetChatItems',
    connect.StreamType.unary,
    nushiv1nushi.GetChatItemsRequest.new,
    nushiv1nushi.GetChatItemsResponse.new,
  );

  /// Starts an agent in a folder and opens a chat with it.
  static const startChat = connect.Spec(
    '/$name/StartChat',
    connect.StreamType.unary,
    nushiv1nushi.StartChatRequest.new,
    nushiv1nushi.StartChatResponse.new,
  );

  /// Lists the agents chats can run, the default first, each as found on
  /// this Mac now: its CLI on the login shell's PATH and its version. Each
  /// CLI is only asked what it is, with file writes and the network denied.
  static const listAgents = connect.Spec(
    '/$name/ListAgents',
    connect.StreamType.unary,
    nushiv1nushi.ListAgentsRequest.new,
    nushiv1nushi.ListAgentsResponse.new,
  );

  /// Sets up an agent's adapter (Agent.adapter): installs it into Nushi's
  /// data folder from the lockfile Nushi pins, or updates it to the pinned
  /// version. The agent's awake chats sleep just before the new one
  /// replaces the old. Returns once it's done (5 minutes at most).
  static const setUpAgent = connect.Spec(
    '/$name/SetUpAgent',
    connect.StreamType.unary,
    nushiv1nushi.SetUpAgentRequest.new,
    nushiv1nushi.SetUpAgentResponse.new,
  );

  /// Removes an agent's adapter; its awake chats sleep first.
  static const removeAgent = connect.Spec(
    '/$name/RemoveAgent',
    connect.StreamType.unary,
    nushiv1nushi.RemoveAgentRequest.new,
    nushiv1nushi.RemoveAgentResponse.new,
  );

  /// Lists an agent's sessions in a folder that aren't chats (started in a
  /// terminal, say), newest first, a page at a time. It starts the agent to
  /// ask (ACP session/list).
  static const listAgentSessions = connect.Spec(
    '/$name/ListAgentSessions',
    connect.StreamType.unary,
    nushiv1nushi.ListAgentSessionsRequest.new,
    nushiv1nushi.ListAgentSessionsResponse.new,
  );

  /// Opens one of them as a chat in the folder: the agent replays it
  /// (session/load); nothing is copied. For a session that is a chat
  /// already, that chat.
  static const openAgentSession = connect.Spec(
    '/$name/OpenAgentSession',
    connect.StreamType.unary,
    nushiv1nushi.OpenAgentSessionRequest.new,
    nushiv1nushi.OpenAgentSessionResponse.new,
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

  /// Stops a subagent or a background command (the tool call that started
  /// it), alone: through its own session when the agent shows the subagent
  /// as one (Subagent.session), else by asking the agent, as a message of
  /// the user's (Item.relay_stop) that waits for its next chance. It shows
  /// as stopped once the agent says so.
  static const stopTask = connect.Spec(
    '/$name/StopTask',
    connect.StreamType.unary,
    nushiv1nushi.StopTaskRequest.new,
    nushiv1nushi.StopTaskResponse.new,
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

  /// Renames the branch of a chat's worktree (git branch -m; its folder
  /// stays), for good: the chat's title no longer names it. Refused during a
  /// turn, for a name git doesn't take or that's taken, and when the branch
  /// is on a remote or another worktree or chat has it. (API 68)
  static const renameBranch = connect.Spec(
    '/$name/RenameBranch',
    connect.StreamType.unary,
    nushiv1nushi.RenameBranchRequest.new,
    nushiv1nushi.RenameBranchResponse.new,
  );

  /// Archives a chat: its turn is cancelled and its agent stops; it stays
  /// listed, read-only. Unarchiving reopens it (ACP session/load).
  static const archiveChat = connect.Spec(
    '/$name/ArchiveChat',
    connect.StreamType.unary,
    nushiv1nushi.ArchiveChatRequest.new,
    nushiv1nushi.ArchiveChatResponse.new,
  );

  /// Puts a chat to sleep (when status.can_sleep): its agent stops as for
  /// ArchiveChat (a running turn is stopped, side chats end), and the chat
  /// stays, its transcript too. A message, or anything else that needs the
  /// agent, reopens the session (ACP session/load); opening it doesn't.
  static const sleepChat = connect.Spec(
    '/$name/SleepChat',
    connect.StreamType.unary,
    nushiv1nushi.SleepChatRequest.new,
    nushiv1nushi.SleepChatResponse.new,
  );

  /// Says a chat is shown (selected, the app came to the front), or Try
  /// again: a chat whose agent should run but doesn't is reopened, as
  /// GetChat does, and one whose last reopen failed (status.reopen_failed)
  /// tries again, once a call, unless what stopped it still holds (its
  /// folder is gone, its agent isn't ready). A sleeping chat stays asleep.
  static const reopenChat = connect.Spec(
    '/$name/ReopenChat',
    connect.StreamType.unary,
    nushiv1nushi.ReopenChatRequest.new,
    nushiv1nushi.ReopenChatResponse.new,
  );

  /// The daemon's settings, and changing them.
  /// Says how much memory Nushi takes, as footprint (Activity Monitor's
  /// Memory), in bytes: a few milliseconds' work.
  static const getMemory = connect.Spec(
    '/$name/GetMemory',
    connect.StreamType.unary,
    nushiv1nushi.GetMemoryRequest.new,
    nushiv1nushi.GetMemoryResponse.new,
  );

  static const getSettings = connect.Spec(
    '/$name/GetSettings',
    connect.StreamType.unary,
    nushiv1nushi.GetSettingsRequest.new,
    nushiv1nushi.GetSettingsResponse.new,
  );

  static const setSettings = connect.Spec(
    '/$name/SetSettings',
    connect.StreamType.unary,
    nushiv1nushi.SetSettingsRequest.new,
    nushiv1nushi.SetSettingsResponse.new,
  );

  /// Nushi's copies of chats' transcripts (ADR 0047): each one's size and
  /// whose it is, largest first.
  static const listTranscripts = connect.Spec(
    '/$name/ListTranscripts',
    connect.StreamType.unary,
    nushiv1nushi.ListTranscriptsRequest.new,
    nushiv1nushi.ListTranscriptsResponse.new,
  );

  /// Deletes copies of transcripts: a chat goes on, its history from its
  /// agent alone; one kept only for its copy (its agent deleted its
  /// session) goes unless its work keeps it.
  static const clearTranscripts = connect.Spec(
    '/$name/ClearTranscripts',
    connect.StreamType.unary,
    nushiv1nushi.ClearTranscriptsRequest.new,
    nushiv1nushi.ClearTranscriptsResponse.new,
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

  /// Takes chats off ListChatsResponse.removed (the app has said so).
  static const dismissRemovedChats = connect.Spec(
    '/$name/DismissRemovedChats',
    connect.StreamType.unary,
    nushiv1nushi.DismissRemovedChatsRequest.new,
    nushiv1nushi.DismissRemovedChatsResponse.new,
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

  /// Reads one of a folder's files as it is now, as a change that changes
  /// nothing (status "unchanged", the text on both sides): a file a review
  /// names that isn't among the changes. Only a regular file inside the
  /// folder: no "..", no link.
  static const getFile = connect.Spec(
    '/$name/GetFile',
    connect.StreamType.unary,
    nushiv1nushi.GetFileRequest.new,
    nushiv1nushi.GetFileResponse.new,
  );

  /// Reads a file of a chat's (in its folder or its worktree) and sends it
  /// again each time it changes, until the call ends: the preview of what
  /// the agent wrote. A path that leads outside them, through a link too,
  /// is refused.
  static const watchChatFile = connect.Spec(
    '/$name/WatchChatFile',
    connect.StreamType.server,
    nushiv1nushi.WatchChatFileRequest.new,
    nushiv1nushi.WatchChatFileResponse.new,
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

  /// Turns a server on or off for the folder's project (API 65: by scope).
  /// A project's .mcp.json server: on approves it, off rejects it (Claude's
  /// enabledMcpjsonServers and disabledMcpjsonServers in the project's
  /// .claude/settings.local.json). A user or local server: as /mcp in a
  /// terminal does, which Claude records in ~/.claude.json, asked of Claude
  /// (ADR 0050). Refused for a plugin's server and a claude.ai connector.
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

  /// The skills (and plugins) an agent uses in a folder (API 66, ADR 0051;
  /// every agent's from API 67, ADR 0052): read from the agent's files (and
  /// Claude's `claude plugin list --json`), never run in the folder; shared
  /// skills (.agents/skills) with every agent that loads each. Skills'
  /// descriptions and plugins' text are their authors'.
  static const listSkills = connect.Spec(
    '/$name/ListSkills',
    connect.StreamType.unary,
    nushiv1nushi.ListSkillsRequest.new,
    nushiv1nushi.ListSkillsResponse.new,
  );

  /// Turns a skill on or off: yours in your settings, a project's in the
  /// project's local settings (skillOverrides, only that key); "builtin"
  /// turns Claude's built-in skills on or off together, in your settings
  /// (disableBundledSkills). A plugin's skills go with their plugin.
  static const setSkillOn = connect.Spec(
    '/$name/SetSkillOn',
    connect.StreamType.unary,
    nushiv1nushi.SetSkillOnRequest.new,
    nushiv1nushi.SetSkillOnResponse.new,
  );

  /// Turns an installed plugin on or off where Plugin.switch_scope says:
  /// for you through `claude plugin enable`/`disable` (run in Claude's config
  /// folder, never the project's), for the project by its enabledPlugins
  /// entry in the project's local settings.
  static const setPluginOn = connect.Spec(
    '/$name/SetPluginOn',
    connect.StreamType.unary,
    nushiv1nushi.SetPluginOnRequest.new,
    nushiv1nushi.SetPluginOnResponse.new,
  );

  /// Uninstalls a plugin installed for you (`claude plugin uninstall`);
  /// refused for one installed for a project.
  static const uninstallPlugin = connect.Spec(
    '/$name/UninstallPlugin',
    connect.StreamType.unary,
    nushiv1nushi.UninstallPluginRequest.new,
    nushiv1nushi.UninstallPluginResponse.new,
  );

  /// Moves a skill's folder (yours or the project's, as listed) to the
  /// Trash.
  static const trashSkill = connect.Spec(
    '/$name/TrashSkill',
    connect.StreamType.unary,
    nushiv1nushi.TrashSkillRequest.new,
    nushiv1nushi.TrashSkillResponse.new,
  );

  /// Gives an agent a shared skill it doesn't read by a relative link of
  /// its own (Claude's .claude/skills/<name> → ../../.agents/skills/<name>):
  /// only a shared skill listed for the folder; nothing replaced.
  static const linkSkill = connect.Spec(
    '/$name/LinkSkill',
    connect.StreamType.unary,
    nushiv1nushi.LinkSkillRequest.new,
    nushiv1nushi.LinkSkillResponse.new,
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

  /// Remote access (ADRs 0033, 0034): how it stands, and switching it on
  /// or off through a relay.
  static const getRemote = connect.Spec(
    '/$name/GetRemote',
    connect.StreamType.unary,
    nushiv1nushi.GetRemoteRequest.new,
    nushiv1nushi.GetRemoteResponse.new,
  );

  static const setRemote = connect.Spec(
    '/$name/SetRemote',
    connect.StreamType.unary,
    nushiv1nushi.SetRemoteRequest.new,
    nushiv1nushi.SetRemoteResponse.new,
  );

  /// Starts pairing a phone (remote access must be on): the text for the QR
  /// code, good until it expires. Once a phone holding it connects,
  /// Remote.pairing has its name and the code both screens show.
  static const startPairing = connect.Spec(
    '/$name/StartPairing',
    connect.StreamType.unary,
    nushiv1nushi.StartPairingRequest.new,
    nushiv1nushi.StartPairingResponse.new,
  );

  /// Allows or denies the phone that connected, named by its code.
  static const confirmPairing = connect.Spec(
    '/$name/ConfirmPairing',
    connect.StreamType.unary,
    nushiv1nushi.ConfirmPairingRequest.new,
    nushiv1nushi.ConfirmPairingResponse.new,
  );

  /// Unpairs a phone and drops its connections.
  static const revokeDevice = connect.Spec(
    '/$name/RevokeDevice',
    connect.StreamType.unary,
    nushiv1nushi.RevokeDeviceRequest.new,
    nushiv1nushi.RevokeDeviceResponse.new,
  );

  /// Web Push (ADR 0054). The daemon's VAPID public key, for a device's
  /// pushManager.subscribe.
  static const getPushKey = connect.Spec(
    '/$name/GetPushKey',
    connect.StreamType.unary,
    nushiv1nushi.GetPushKeyRequest.new,
    nushiv1nushi.GetPushKeyResponse.new,
  );

  /// A paired device's own push subscription (an empty endpoint: none);
  /// only on a device's channel. The endpoint must be a known push service.
  static const setPushSubscription = connect.Spec(
    '/$name/SetPushSubscription',
    connect.StreamType.unary,
    nushiv1nushi.SetPushSubscriptionRequest.new,
    nushiv1nushi.SetPushSubscriptionResponse.new,
  );

  /// The chat a client shows ("" none), said again within 40 s while it
  /// does: that chat is seen (Chat.unseen), and no push for it goes to the
  /// device while it's connected. On the Mac's socket it's the Mac's window
  /// (API 76; before, only on a device's channel).
  static const setDeviceView = connect.Spec(
    '/$name/SetDeviceView',
    connect.StreamType.unary,
    nushiv1nushi.SetDeviceViewRequest.new,
    nushiv1nushi.SetDeviceViewResponse.new,
  );

  /// Sends a test notification to a device (the Mac's).
  static const sendTestPush = connect.Spec(
    '/$name/SendTestPush',
    connect.StreamType.unary,
    nushiv1nushi.SendTestPushRequest.new,
    nushiv1nushi.SendTestPushResponse.new,
  );

  /// Unpairs the device that calls (its Forget this Mac), as Revoke would;
  /// only on a device's channel.
  static const unpairThisDevice = connect.Spec(
    '/$name/UnpairThisDevice',
    connect.StreamType.unary,
    nushiv1nushi.UnpairThisDeviceRequest.new,
    nushiv1nushi.UnpairThisDeviceResponse.new,
  );

  /// Writes a line of the app's into the daemon's log (source=app): its
  /// errors with their stacks, and what helps afterwards.
  static const log = connect.Spec(
    '/$name/Log',
    connect.StreamType.unary,
    nushiv1nushi.LogRequest.new,
    nushiv1nushi.LogResponse.new,
  );

  /// Jira (ADR 0042): the sites added, their tokens in the keychain. Every
  /// call that reaches Jira is one the user made; nothing polls or writes on
  /// its own.
  static const listJiraSites = connect.Spec(
    '/$name/ListJiraSites',
    connect.StreamType.unary,
    nushiv1nushi.ListJiraSitesRequest.new,
    nushiv1nushi.ListJiraSitesResponse.new,
  );

  /// Checks a token on a site (classic or scoped) and keeps it: the token
  /// in the keychain, the site in the list.
  static const addJiraSite = connect.Spec(
    '/$name/AddJiraSite',
    connect.StreamType.unary,
    nushiv1nushi.AddJiraSiteRequest.new,
    nushiv1nushi.AddJiraSiteResponse.new,
  );

  /// Forgets a site and deletes its token from the keychain.
  static const removeJiraSite = connect.Spec(
    '/$name/RemoveJiraSite',
    connect.StreamType.unary,
    nushiv1nushi.RemoveJiraSiteRequest.new,
    nushiv1nushi.RemoveJiraSiteResponse.new,
  );

  /// Asks Jira who a site's token is, to see it still works.
  static const checkJiraSite = connect.Spec(
    '/$name/CheckJiraSite',
    connect.StreamType.unary,
    nushiv1nushi.CheckJiraSiteRequest.new,
    nushiv1nushi.CheckJiraSiteResponse.new,
  );

  /// Reads a site's token with macOS's prompt, which asks to let this
  /// build of Nushi read it (JiraSite.needs_ok).
  static const allowJiraToken = connect.Spec(
    '/$name/AllowJiraToken',
    connect.StreamType.unary,
    nushiv1nushi.AllowJiraTokenRequest.new,
    nushiv1nushi.AllowJiraTokenResponse.new,
  );

  /// The board whose active sprint is the sprint list, and saved searches.
  static const listJiraBoards = connect.Spec(
    '/$name/ListJiraBoards',
    connect.StreamType.unary,
    nushiv1nushi.ListJiraBoardsRequest.new,
    nushiv1nushi.ListJiraBoardsResponse.new,
  );

  static const setJiraBoard = connect.Spec(
    '/$name/SetJiraBoard',
    connect.StreamType.unary,
    nushiv1nushi.SetJiraBoardRequest.new,
    nushiv1nushi.SetJiraBoardResponse.new,
  );

  static const setJiraSearches = connect.Spec(
    '/$name/SetJiraSearches',
    connect.StreamType.unary,
    nushiv1nushi.SetJiraSearchesRequest.new,
    nushiv1nushi.SetJiraSearchesResponse.new,
  );

  /// A list's issues: "mine", "sprint", or a JQL search.
  static const listJiraIssues = connect.Spec(
    '/$name/ListJiraIssues',
    connect.StreamType.unary,
    nushiv1nushi.ListJiraIssuesRequest.new,
    nushiv1nushi.ListJiraIssuesResponse.new,
  );

  /// What the JQL field autocompletes from, and a field's values.
  static const getJiraJql = connect.Spec(
    '/$name/GetJiraJql',
    connect.StreamType.unary,
    nushiv1nushi.GetJiraJqlRequest.new,
    nushiv1nushi.GetJiraJqlResponse.new,
  );

  static const suggestJiraJql = connect.Spec(
    '/$name/SuggestJiraJql',
    connect.StreamType.unary,
    nushiv1nushi.SuggestJiraJqlRequest.new,
    nushiv1nushi.SuggestJiraJqlResponse.new,
  );

  /// An issue whole, text as Markdown.
  static const getJiraIssue = connect.Spec(
    '/$name/GetJiraIssue',
    connect.StreamType.unary,
    nushiv1nushi.GetJiraIssueRequest.new,
    nushiv1nushi.GetJiraIssueResponse.new,
  );

  static const listJiraTransitions = connect.Spec(
    '/$name/ListJiraTransitions',
    connect.StreamType.unary,
    nushiv1nushi.ListJiraTransitionsRequest.new,
    nushiv1nushi.ListJiraTransitionsResponse.new,
  );

  static const transitionJiraIssue = connect.Spec(
    '/$name/TransitionJiraIssue',
    connect.StreamType.unary,
    nushiv1nushi.TransitionJiraIssueRequest.new,
    nushiv1nushi.TransitionJiraIssueResponse.new,
  );

  /// Posts a comment written in Markdown.
  static const addJiraComment = connect.Spec(
    '/$name/AddJiraComment',
    connect.StreamType.unary,
    nushiv1nushi.AddJiraCommentRequest.new,
    nushiv1nushi.AddJiraCommentResponse.new,
  );

  /// An issue for a new chat: from its link, its key, or words of it.
  static const findJiraIssues = connect.Spec(
    '/$name/FindJiraIssues',
    connect.StreamType.unary,
    nushiv1nushi.FindJiraIssuesRequest.new,
    nushiv1nushi.FindJiraIssuesResponse.new,
  );

  /// An attachment's file or thumbnail (20 MB at most).
  static const getJiraAttachment = connect.Spec(
    '/$name/GetJiraAttachment',
    connect.StreamType.unary,
    nushiv1nushi.GetJiraAttachmentRequest.new,
    nushiv1nushi.GetJiraAttachmentResponse.new,
  );

  /// GitHub (ADR 0045): the hosts gh is signed in to (its token read by the
  /// daemon through go-gh) and those given a pasted token (the keychain).
  /// Nothing reaches GitHub on its own: the app asks, and marks the asking
  /// on its timers quiet, which a rate limit running low holds back.
  static const listGitHubHosts = connect.Spec(
    '/$name/ListGitHubHosts',
    connect.StreamType.unary,
    nushiv1nushi.ListGitHubHostsRequest.new,
    nushiv1nushi.ListGitHubHostsResponse.new,
  );

  /// Checks a pasted token on a host and keeps it in the keychain; it's
  /// used for the host instead of gh's login until removed.
  static const addGitHubToken = connect.Spec(
    '/$name/AddGitHubToken',
    connect.StreamType.unary,
    nushiv1nushi.AddGitHubTokenRequest.new,
    nushiv1nushi.AddGitHubTokenResponse.new,
  );

  static const removeGitHubToken = connect.Spec(
    '/$name/RemoveGitHubToken',
    connect.StreamType.unary,
    nushiv1nushi.RemoveGitHubTokenRequest.new,
    nushiv1nushi.RemoveGitHubTokenResponse.new,
  );

  /// Reads a host's pasted token with macOS's prompt (GitHubHost.needs_ok).
  static const allowGitHubToken = connect.Spec(
    '/$name/AllowGitHubToken',
    connect.StreamType.unary,
    nushiv1nushi.AllowGitHubTokenRequest.new,
    nushiv1nushi.AllowGitHubTokenResponse.new,
  );

  /// The GitHub repositories folders are clones of: the folders asked
  /// about and the chats'.
  static const listGitHubRepos = connect.Spec(
    '/$name/ListGitHubRepos',
    connect.StreamType.unary,
    nushiv1nushi.ListGitHubReposRequest.new,
    nushiv1nushi.ListGitHubReposResponse.new,
  );

  /// Review requested of me or my teams, my pull requests, issues assigned
  /// to me: the latest 50 each.
  static const listGitHubInbox = connect.Spec(
    '/$name/ListGitHubInbox',
    connect.StreamType.unary,
    nushiv1nushi.ListGitHubInboxRequest.new,
    nushiv1nushi.ListGitHubInboxResponse.new,
  );

  /// Items as they are now, by node id (a chat's status chip).
  static const getGitHubStates = connect.Spec(
    '/$name/GetGitHubStates',
    connect.StreamType.unary,
    nushiv1nushi.GetGitHubStatesRequest.new,
    nushiv1nushi.GetGitHubStatesResponse.new,
  );

  static const getGitHubPull = connect.Spec(
    '/$name/GetGitHubPull',
    connect.StreamType.unary,
    nushiv1nushi.GetGitHubPullRequest.new,
    nushiv1nushi.GetGitHubPullResponse.new,
  );

  static const getGitHubIssue = connect.Spec(
    '/$name/GetGitHubIssue',
    connect.StreamType.unary,
    nushiv1nushi.GetGitHubIssueRequest.new,
    nushiv1nushi.GetGitHubIssueResponse.new,
  );

  /// A pull request's files from its merge base to its head, both sides'
  /// texts, as GetDiff gives them.
  static const getGitHubFiles = connect.Spec(
    '/$name/GetGitHubFiles',
    connect.StreamType.unary,
    nushiv1nushi.GetGitHubFilesRequest.new,
    nushiv1nushi.GetGitHubFilesResponse.new,
  );

  /// The end of a failed Actions job's log (16 KB).
  static const getGitHubJobLog = connect.Spec(
    '/$name/GetGitHubJobLog',
    connect.StreamType.unary,
    nushiv1nushi.GetGitHubJobLogRequest.new,
    nushiv1nushi.GetGitHubJobLogResponse.new,
  );

  /// A message for a chat's agent, for the box (never sent by Nushi):
  /// "fix_checks" (the failed checks with their logs' ends) or
  /// "address_comments" (the threads named, else all not resolved), GitHub's
  /// text in it marked as data.
  static const getGitHubPrompt = connect.Spec(
    '/$name/GetGitHubPrompt',
    connect.StreamType.unary,
    nushiv1nushi.GetGitHubPromptRequest.new,
    nushiv1nushi.GetGitHubPromptResponse.new,
  );

  /// The user's writes.
  static const replyGitHubThread = connect.Spec(
    '/$name/ReplyGitHubThread',
    connect.StreamType.unary,
    nushiv1nushi.ReplyGitHubThreadRequest.new,
    nushiv1nushi.ReplyGitHubThreadResponse.new,
  );

  static const resolveGitHubThread = connect.Spec(
    '/$name/ResolveGitHubThread',
    connect.StreamType.unary,
    nushiv1nushi.ResolveGitHubThreadRequest.new,
    nushiv1nushi.ResolveGitHubThreadResponse.new,
  );

  static const addGitHubComment = connect.Spec(
    '/$name/AddGitHubComment',
    connect.StreamType.unary,
    nushiv1nushi.AddGitHubCommentRequest.new,
    nushiv1nushi.AddGitHubCommentResponse.new,
  );

  static const submitGitHubReview = connect.Spec(
    '/$name/SubmitGitHubReview',
    connect.StreamType.unary,
    nushiv1nushi.SubmitGitHubReviewRequest.new,
    nushiv1nushi.SubmitGitHubReviewResponse.new,
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
