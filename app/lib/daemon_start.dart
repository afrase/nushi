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
      final start = await _ask(TrustAsk(folder, action, check.runs, agent));
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

  /// Shows [ask]'s trust card, in place of one shown, and gives its answer.
  Future<bool> _ask(TrustAsk ask) async {
    trustAsk?.decide(start: false);
    trustAsk = ask;
    settingsOpen = null; // the card is in the window, under Settings
    _changed();
    final start = await ask.answer.future;
    if (trustAsk == ask) {
      trustAsk = null;
      _changed();
    }
    return start;
  }

  /// Where the user is: a start that ends elsewhere doesn't take them
  /// to its chat.
  (String?, Place) get _place => (selectedId, place);

  /// Starts a chat with [agent] in [folder], or in a scratch folder of its
  /// own (''); never in a worktree unless asked, as nothing is remembered
  /// (the "New worktree" chip moves it). A chat on a Jira [issue] remembers
  /// it and takes its worktree choice; its box stays empty (the agent's
  /// tools say which issue it is). A pull request's head that brings code
  /// of its own asks too, once the daemon has checked it out (ADR 0023).
  /// Gives the new chat's id, shown or not, or null when the trust card
  /// said no.
  Future<String?> startChat(
    String folder,
    String agent, {
    IssueChat? issue,
  }) async {
    starting = folder;
    startingAgent = agent;
    _changed();
    try {
      if (!await _mayRun(folder, 'Start a chat', agent)) return null;
      final before = _place;
      StartChatResponse resp;
      try {
        var shown = '';
        while (true) {
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
              headRunsKey: shown,
            ),
          );
          if (resp.headRuns.isEmpty) break;
          final pull = issue?.github;
          final ask = TrustAsk(
            resp.headFolder,
            'Start a chat',
            resp.headRuns,
            agent,
            shownAs: pull == null ? null : 'Pull request #${pull.number}',
          );
          if (!await _ask(ask)) return null;
          shown = resp.headRunsKey;
        }
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
      final chat = chats[resp.chatId] ??= ChatState(resp.chatId, folder);
      // Now, not at its event, which may come later: what's written in its
      // box from here on is kept.
      drafts?.attach(chat);
      // Not if the user went elsewhere meanwhile: a trust card or another
      // chat they're on stays.
      if (_place == before && trustAsk == null) {
        select(resp.chatId);
      }
      return resp.chatId;
    } finally {
      starting = null;
      startingAgent = null;
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
    startingAgent = agent;
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
      startingAgent = null;
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
