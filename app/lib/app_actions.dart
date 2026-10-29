import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/open_file.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_link_dialog.dart';
import 'package:nushi/review.dart';
import 'package:nushi/rewind_picker.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/side_panel.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/widgets.dart';

// The app's actions in one place: each is a row of the ⌘K palette, its
// key (bound at the app's root, and passed on by a terminal) and, when it
// names a menu, a menu bar item.

/// The menus an action can be in; the Chat menu's are the chat's ⋯ menu
/// too.
enum ActMenu { nushi, file, view, chat }

/// ⇧⌘B: a side question (Claude Code's /btw, "by the way").
const sideQuestionKey = SingleActivator(
  LogicalKeyboardKey.keyB,
  meta: true,
  shift: true,
);

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
  sideQuestion(
    key: sideQuestionKey,
    menu: ActMenu.chat,
    menuLabel: 'Side Question',
  ),
  sendComments(menu: ActMenu.chat, menuLabel: 'Send Review Comments to Agent'),
  stop(keyText: 'Esc', menu: ActMenu.chat, menuLabel: 'Stop'), // the chat's
  rename(menu: ActMenu.chat, menuLabel: 'Rename'),
  sleep(menu: ActMenu.chat, menuLabel: 'Sleep'),
  reload(menu: ActMenu.chat, menuLabel: 'Reload'),
  linkPull(menu: ActMenu.chat, menuLabel: 'Link Pull Request…'),
  archive(menu: ActMenu.chat, menuLabel: 'Archive'),
  unarchive(menu: ActMenu.chat, menuLabel: 'Unarchive'),
  mcp(menu: ActMenu.chat, menuLabel: 'MCP Servers…'),
  skills(menu: ActMenu.chat, menuLabel: 'Skills…'),
  delete(menu: ActMenu.chat, menuLabel: 'Delete…'),
  settings(key: settingsKey, menu: ActMenu.nushi, menuLabel: 'Settings…'),
  jira(key: jiraKey, menu: ActMenu.view, menuLabel: 'Jira'),
  github(key: githubKey, menu: ActMenu.view, menuLabel: 'GitHub'),
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
/// it does; [short], what a chat's ⋯ menu says ("Rename" for "Rename
/// chat").
class AppAction {
  const new(
    this.act,
    this.title, {
    required this.run,
    this.enabled = true,
    String? short,
  }) : short = short ?? title;

  final Act act;
  final String title;
  final bool enabled;
  final VoidCallback run;
  final String short;

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
    ...chatActions(context, d, shown),
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
      .restart,
      'Restart daemon',
      enabled: bundledDaemon != null,
      run: () => unawaited(restartDaemonAsking(context, d)),
    ),
  ];
}

/// What can be done to [chat] (the shown one, from the palette and the
/// menu bar; any, from its ⋯ menu or its sidebar row's), each as it is now:
/// the Chat menu's actions. Without a chat they don't apply, but MCP
/// servers and Skills, which open their Settings sections. [onRename]
/// renames in place (a sidebar row); else the header's title does.
List<AppAction> chatActions(
  BuildContext context,
  Daemon d,
  ChatState? chat, {
  VoidCallback? onRename,
}) {
  final live = chat != null && !chat.archived && !chat.sessionGone;
  final comments = chat == null ? 0 : unsentComments(chat.id).length;
  return [
    AppAction(
      .sideQuestion,
      'Side question',
      enabled: live && chat.canFork,
      run: () => unawaited(askAside(context, d, chat!)),
    ),
    AppAction(
      .sendComments,
      'Send review comments to agent ($comments)',
      short: 'Send review comments ($comments)',
      enabled: live && comments > 0,
      run: () => reviewToBox(chat!),
    ),
    AppAction(
      .stop,
      'Stop the turn',
      short: 'Stop',
      enabled: chat != null && chat.started != null && !chat.stopping,
      run: () => unawaited(stopTurn(context, chat!, d)),
    ),
    AppAction(
      .rename,
      'Rename chat',
      short: 'Rename',
      enabled: chat != null,
      run: onRename ?? () => chat!.renaming.value = true,
    ),
    AppAction(
      .sleep,
      'Sleep chat',
      short: 'Sleep',
      enabled: chat != null && chat.canSleep && !chat.archived,
      run: () => unawaited(sleepChat(context, chat!, d)),
    ),
    AppAction(
      .reload,
      'Reload chat',
      short: 'Reload',
      enabled: live && !chat.busy && !chat.asleep && !chat.reopenFailed,
      run: () => tryOrShow(context, () => reloadChat(context, chat!, d)),
    ),
    AppAction(
      .linkPull,
      chat?.pull == null ? 'Link pull request…' : 'Link another pull request…',
      enabled: live && d.daemonApi >= chatPullApi,
      run: () => unawaited(linkPull(context, ChatPull.of(d, chat!))),
    ),
    AppAction(
      .archive,
      'Archive chat',
      short: 'Archive',
      enabled: chat != null && !chat.archived,
      run: () => tryOrShow(context, () => archiveChat(context, chat!, d)),
    ),
    AppAction(
      .unarchive,
      'Unarchive chat',
      short: 'Unarchive',
      enabled: chat != null && chat.archived,
      run: () => tryOrShow(context, () => archiveChat(context, chat!, d)),
    ),
    AppAction(
      .mcp,
      'MCP servers',
      short: 'MCP servers…',
      enabled: knownAgents[chat?.agent]?.mcp ?? true,
      run: () => chat == null
          ? d.openSettings(section: SettingsSection.mcp)
          : d.showMcp(chat.folder),
    ),
    AppAction(
      .skills,
      'Skills',
      short: 'Skills…',
      run: () => chat == null
          ? d.openSettings(section: SettingsSection.skills)
          : d.showSkills(chat.folder, agent: chat.agent),
    ),
    AppAction(
      .delete,
      'Delete chat…',
      short: 'Delete…',
      enabled: chat != null,
      run: () => unawaited(showDeleteChat(context, chat!, d)),
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
