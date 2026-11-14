part of 'daemon.dart';

/// What shows in the chat's place, and moving between those.
extension DaemonPlaces on Daemon {
  /// Whether the selected chat shows in the window: nothing (the trust
  /// card, Jira, GitHub) is in its place and Settings isn't open over it.
  /// What the daemon is told the Mac views, and what a chat's tabs and
  /// actions need.
  bool get chatShows =>
      selected != null &&
      trustAsk == null &&
      place is ChatPlace &&
      settingsOpen == null;

  /// Shows [to] in the chat's place (picking a chat goes there too);
  /// Settings shuts, as for anything that takes the user elsewhere. A
  /// trust card asking is left: that's a no.
  void go(Place to) {
    _leaveTrust();
    settingsOpen = null;
    place = to;
    _changed();
  }

  /// Whether Back and Forward have somewhere to go (ADR 0119).
  bool get canGoBack => visits.can(-1, _live);
  bool get canGoForward => visits.can(1, _live);

  /// Back and Forward: the place visited before, or after going back,
  /// opened as a pick does; a chat deleted or archived since is passed
  /// over.
  void goBack() => _revisit(-1);
  void goForward() => _revisit(1);

  void _revisit(int step) {
    switch (visits.step(step, _live)) {
      case Visit(:final chat?):
        select(chat);
      case Visit(:final place):
        go(place);
      case null:
    }
  }

  /// Whether [v] can still be gone to: its chat is there, unarchived.
  bool _live(Visit v) => switch (v.chat) {
    null => true,
    final id => chats[id]?.archived == false,
  };

  /// Leaves Jira or GitHub for the chat.
  void back() {
    if (place is ChatPlace) return;
    go(const ChatPlace());
  }

  /// Opens [to] in the chat's place, or leaves it when it shows (the
  /// sidebar's rows, the palette's Jira and GitHub).
  void toggle(Place to) =>
      place.runtimeType == to.runtimeType ? back() : go(to);

  /// Opens Settings over the window at [section] (the one showing, else
  /// the last one shown, when null), or moves it there; a [folder] for MCP
  /// servers or Skills, an [agent] for Skills (whose skills) or Agents
  /// (the row marked). A trust card asking is left: that's a no.
  void openSettings({SettingsSection? section, String? folder, String? agent}) {
    final s = section ?? settingsOpen?.section ?? lastSettings;
    if (folder != null && s == SettingsSection.mcp) mcpFolder = folder;
    if (folder != null && s == SettingsSection.skills) skillsFolder = folder;
    if (agent != null && s == SettingsSection.skills) skillsAgent = agent;
    _leaveTrust();
    lastSettings = s;
    settingsOpen = SettingsAt(
      s,
      agent: s == SettingsSection.agents ? agent : null,
    );
    _changed();
  }

  /// Shuts Settings, leaving the window as it was.
  void closeSettings() {
    if (settingsOpen == null) return;
    settingsOpen = null;
    _changed();
  }

  /// ⌘, and the menu's Settings…: opens Settings, or shuts it.
  void toggleSettings() =>
      settingsOpen == null ? openSettings() : closeSettings();

  void showMcp(String folder) =>
      openSettings(section: SettingsSection.mcp, folder: folder);

  void showSkills(String folder, {String? agent}) => openSettings(
    section: SettingsSection.skills,
    folder: folder,
    agent: agent,
  );

  void dismissNotice() {
    notice = null;
    _changed();
  }

  /// The user went elsewhere while a trust card asked: that's a no, and
  /// a bar says so, or the chat asked for would just not appear.
  void _leaveTrust() {
    final ask = trustAsk;
    if (ask == null || ask.answer.isCompleted) return;
    ask.decide(start: false);
    notice = ask.left;
  }
}
