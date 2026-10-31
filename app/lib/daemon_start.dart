part of 'daemon.dart';

/// Starting, opening and moving chats, past a folder's trust card.
extension DaemonStart on Daemon {
  /// Whether a chat with [agent] may start or move into [folder] (doing
  /// [action]): when the folder brings code for it to run that nobody trusted,
  /// [trustAsk] shows it and this waits for "Start anyway", which the
  /// daemon remembers, or Cancel.
  Future<bool> _mayRun(String folder, String action, String agent) async {
    if (folder.isEmpty) return true;
    while (true) {
      final check = await client.checkFolder(
        CheckFolderRequest(folder: folder, agent: agent),
      );
      if (check.runs.isEmpty) return true;
      trustAsk?.decide(start: false);
      final ask = trustAsk = TrustAsk(folder, action, check.runs, agent);
      _changed();
      final start = await ask.answer.future;
      if (trustAsk == ask) {
        trustAsk = null;
        _changed();
      }
      // A folder without a key is for this start only.
      if (!start || check.key.isEmpty) return start;
      try {
        await client.trustFolder(
          TrustFolderRequest(folder: folder, agent: agent, key: check.key),
        );
        return true;
      } on connect.ConnectException catch (e) {
        if (e.code != connect.Code.aborted) rethrow; // changed: look again
      }
    }
  }

  /// Where the user is: a start that ends elsewhere doesn't take them
  /// to its chat.
  (String?, Place) get _place => (selectedId, place);

  /// Starts a chat with [agent] in [folder], or in a scratch folder of its
  /// own (''); never in a worktree unless asked, as nothing is remembered
  /// (the "New worktree" chip moves it). A chat on a Jira [issue] remembers
  /// it and takes its worktree choice; its box stays empty (the agent's
  /// tools say which issue it is).
  Future<void> startChat(
    String folder,
    String agent, {
    IssueChat? issue,
  }) async {
    starting = folder;
    _changed();
    try {
      if (!await _mayRun(folder, 'Start a chat', agent)) return;
      final before = _place;
      final StartChatResponse resp;
      try {
        resp = await client.startChat(
          StartChatRequest(
            agent: agent,
            folder: folder,
            worktree: issue?.worktree ?? false,
            jiraSite: issue?.github == null ? issue?.site : null,
            jiraKey: issue?.github == null ? issue?.key : null,
            github: issue?.github,
            branch:
                issue != null &&
                    issue.worktree &&
                    folder.isNotEmpty &&
                    issue.github?.pull != true
                ? issue.branch
                : null,
          ),
        );
      } on connect.ConnectException catch (e) {
        if (refusedFor(
          e,
          'agent_start',
          (m) => m.startsWith("couldn't start "),
        )) {
          cantStart[agent] = e.message;
        }
        rethrow;
      }
      cantStart.remove(agent);
      chats[resp.chatId] ??= ChatState(resp.chatId, folder);
      // Not if the user went elsewhere meanwhile: a trust card or another
      // chat they're on stays.
      if (_place == before && trustAsk == null) {
        select(resp.chatId);
      }
    } finally {
      starting = null;
      _changed();
    }
  }

  /// Opens [session], one of [agent]'s sessions that isn't a chat, as a
  /// chat in [asked] (its own folder for ''), and shows it.
  Future<void> openSession(
    String asked,
    String agent,
    FoundSession session,
  ) async {
    final folder = asked.isEmpty ? session.folder : asked;
    starting = folder;
    _changed();
    try {
      if (!await _mayRun(folder, 'Open the session', agent)) return;
      final before = _place;
      final resp = await client.openAgentSession(
        OpenAgentSessionRequest(
          agent: agent,
          folder: folder,
          sessionId: session.sessionId,
          title: session.title,
        ),
      );
      chats[resp.chatId] ??= ChatState(resp.chatId, folder);
      if (_place == before && trustAsk == null) {
        select(resp.chatId);
      }
    } finally {
      starting = null;
      _changed();
    }
  }

  /// Moves a chat to [folder], or to a new worktree of its repository
  /// ([worktree]), and says whether it did (not when the user cancelled).
  Future<bool> moveChat(
    ChatState chat,
    String folder, {
    bool worktree = false,
  }) async {
    if (!await _mayRun(folder, 'Move the chat', chat.agent)) return false;
    await client.moveChat(
      MoveChatRequest(chatId: chat.id, folder: folder, worktree: worktree),
    );
    return true;
  }
}
