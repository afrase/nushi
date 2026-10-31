part of 'daemon.dart';

/// What shows in the chat's place, and moving between those.
extension DaemonPlaces on Daemon {
  /// Whether the selected chat shows in the window: nothing (the trust
  /// card, Settings, Jira, GitHub) is in its place. What the daemon is
  /// told the Mac views, and what a chat's tabs and actions need.
  bool get chatShows =>
      selected != null && trustAsk == null && place is ChatPlace;

  /// Shows [to] in the chat's place (picking a chat goes there too), and
  /// on GitHub, [github]'s details. A trust card asking is left: that's a
  /// no.
  void go(Place to, {GitHubPick? github}) {
    _leaveTrust();
    if (to is SettingsPlace) {
      if (place is! SettingsPlace) _beforeSettings = place;
      lastSettings = to.section;
    }
    place = to;
    githubShow = github;
    _changed();
  }

  /// Leaves what's in the chat's place: Settings for what showed before
  /// it, Jira and GitHub for the chat.
  void back() {
    if (place is ChatPlace) return;
    go(place is SettingsPlace ? _beforeSettings : const ChatPlace());
  }

  /// Opens [to] in the chat's place, or leaves it when it shows (the
  /// sidebar's rows, the palette's Jira and GitHub).
  void toggle(Place to) =>
      place.runtimeType == to.runtimeType ? back() : go(to);

  /// Shows Settings at [section] (the one showing, else the last one shown,
  /// when null); a [folder] for MCP servers or Skills, an [agent] for
  /// Skills (whose skills) or Agents (the row marked).
  void openSettings({SettingsSection? section, String? folder, String? agent}) {
    final s =
        section ??
        switch (place) {
          SettingsPlace(:final section) => section,
          _ => lastSettings,
        };
    if (folder != null && s == SettingsSection.mcp) mcpFolder = folder;
    if (folder != null && s == SettingsSection.skills) skillsFolder = folder;
    if (agent != null && s == SettingsSection.skills) skillsAgent = agent;
    go(SettingsPlace(s, agent: s == SettingsSection.agents ? agent : null));
  }

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
