import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/open_file.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/rewind_picker.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/widgets.dart';

// The app's actions in one place: each is a row of the ⌘K palette, its
// key (bound at the app's root, and passed on by a terminal) and, when it
// names a menu, a menu bar item.

/// The menus an action can be in.
enum ActMenu { nushi, file, view }

/// An action of the app, in the palette's order with an empty query.
enum Act {
  newChat(key: newChatKey, menu: ActMenu.file, menuLabel: 'New Chat…'),
  openFile(key: openFileKey, menu: ActMenu.file, menuLabel: 'Open File…'),
  artifacts,
  chat(key: chatTabKey, menu: ActMenu.view, menuLabel: 'Chat'),
  changes(key: changesTabKey, menu: ActMenu.view, menuLabel: 'Changes'),
  pull(key: pullTabKey, menu: ActMenu.view, menuLabel: 'Pull Request'),
  details,
  terminal(keyText: '⌃`'), // TerminalArea's key: it keeps the focus
  rewind(keyText: 'Esc Esc'), // the composer's
  archive,
  settings(key: settingsKey, menu: ActMenu.nushi, menuLabel: 'Settings…'),
  jira(key: jiraKey, menu: ActMenu.view, menuLabel: 'Jira'),
  github(key: githubKey, menu: ActMenu.view, menuLabel: 'GitHub'),
  mcp,
  skills,
  restart;

  new({this.key, this.keyText, this.menu, this.menuLabel});

  /// The key the app binds to it, wherever the focus is.
  final SingleActivator? key;
  final String? keyText; // shown, not bound: another widget has the key
  final ActMenu? menu;
  final String? menuLabel;

  /// Its key as the palette and tooltips show it.
  String? get shortcut =>
      keyText ??
      switch (key) {
        final k? => keyLabel(k),
        null => null,
      };
}

/// One row of the palette: what it says, whether it applies now, and what
/// it does.
class AppAction {
  const new(this.act, this.title, {required this.run, this.enabled = true});

  final Act act;
  final String title;
  final bool enabled;
  final VoidCallback run;

  String? get shortcut => act.shortcut;
}

/// Runs [act] (from its key or the palette) when it applies.
class RunActIntent extends Intent {
  const new(this.act);

  final Act act;
}

/// Opens the palette.
class OpenPaletteIntent extends Intent {
  const new();
}

/// ⌘K opens the palette, and ⌘⇧P, which a terminal (where ⌘K clears)
/// passes on too.
const paletteKey = SingleActivator(LogicalKeyboardKey.keyK, meta: true);
const paletteKeyToo = SingleActivator(
  LogicalKeyboardKey.keyP,
  meta: true,
  shift: true,
);

/// The keys of the actions that have one, as the intents that run them.
final Map<ShortcutActivator, Intent> actKeys = {
  for (final a in Act.values) ?a.key: RunActIntent(a),
};

/// Whether a chat shows in the window (not Jira, GitHub, Settings or the
/// trust card in its place): what its tabs and actions need.
bool chatShown(Daemon d) =>
    d.selected != null &&
    d.trustAsk == null &&
    !d.jiraOpen &&
    !d.githubOpen &&
    d.settings == null;

/// Every action, each as it is now (its title, whether it applies).
/// [context] is where its dialogs open.
List<AppAction> appActions(BuildContext context, Daemon d) {
  final chat = d.selected;
  final shown = chatShown(d) ? chat : null;
  void tab(ChatTab t) => shown?.tab.value = t;
  final details = showDetails.value;
  final terminal = shown != null && terminalChats.value.contains(shown.id);
  return [
    AppAction(.newChat, 'New chat', run: () => newChat(context, d, '')),
    AppAction(
      .openFile,
      'Open file…',
      enabled: shown != null && d.daemonApi >= previewApi,
      run: () => unawaited(openFile(context, d)),
    ),
    AppAction(
      .artifacts,
      'Artifacts…',
      enabled:
          shown != null &&
          d.daemonApi >= previewApi &&
          chatFiles(shown.items).isNotEmpty,
      run: () => revealArtifacts(context, shown!),
    ),
    AppAction(
      .chat,
      'Show chat',
      enabled: shown != null,
      run: () => tab(.chat),
    ),
    AppAction(
      .changes,
      'Show changes',
      enabled: shown != null,
      run: () => tab(.changes),
    ),
    AppAction(
      .pull,
      'Show pull request',
      enabled: shown?.pull != null,
      run: () => tab(.pull),
    ),
    AppAction(
      .details,
      details ? 'Hide details' : 'Show details',
      enabled: shown?.shownTab == ChatTab.chat,
      run: () => showDetails.value = !details,
    ),
    AppAction(
      .terminal,
      terminal ? 'Hide terminal' : 'Show terminal',
      enabled: shown != null && !shown.archived,
      run: () => toggleTerminal(shown!.id),
    ),
    AppAction(
      .rewind,
      'Rewind…',
      enabled: shown != null && rewindChoices(shown).isNotEmpty,
      run: () => unawaited(pickRewind(context, d, shown!)),
    ),
    AppAction(
      .archive,
      'Archive chat',
      enabled: shown != null && !shown.archived,
      run: () => tryOrShow(context, () => archiveChat(context, shown!, d)),
    ),
    AppAction(.settings, 'Settings', run: d.openSettings),
    AppAction(
      .jira,
      d.jiraOpen ? 'Close Jira' : 'Jira',
      run: () => d.showJira(open: !d.jiraOpen),
    ),
    AppAction(
      .github,
      d.githubOpen ? 'Close GitHub' : 'GitHub',
      run: () => d.showGitHub(open: !d.githubOpen),
    ),
    AppAction(
      .mcp,
      'MCP servers',
      run: () => chat == null
          ? d.openSettings(section: SettingsSection.mcp)
          : d.showMcp(chat.folder),
    ),
    AppAction(
      .skills,
      'Skills',
      run: () => chat == null
          ? d.openSettings(section: SettingsSection.skills)
          : d.showSkills(chat.folder, agent: chat.agent),
    ),
    AppAction(
      .restart,
      'Restart daemon',
      enabled: bundledDaemon != null,
      run: () => unawaited(restartDaemonAsking(context, d)),
    ),
  ];
}

/// Artifacts…: the details panel shown on Chat, its Artifacts card opened
/// and scrolled to; where the window has no room for the panel, the
/// palette lists them instead.
void revealArtifacts(BuildContext context, ChatState chat) {
  if (!chat.panelFits) {
    unawaited(showArtifacts(context, chat));
    return;
  }
  chat.tab.value = ChatTab.chat;
  showDetails.value = true;
  revealCard.value = 'Artifacts';
}

/// Runs [act] as it is now, if it applies.
void runAct(BuildContext context, Daemon d, Act act) {
  final a = appActions(context, d).firstWhere((a) => a.act == act);
  if (a.enabled) a.run();
}

/// A key as macOS's menus write it: ⌃⌥⇧⌘ and then the key.
String keyLabel(SingleActivator a) {
  final k = a.trigger;
  final name = k == LogicalKeyboardKey.tab ? '⇥' : k.keyLabel.toUpperCase();
  return '${a.control ? '⌃' : ''}${a.alt ? '⌥' : ''}'
      '${a.shift ? '⇧' : ''}${a.meta ? '⌘' : ''}$name';
}
