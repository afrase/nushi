import 'dart:async';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/app_install.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/chat_pins.dart';
import 'package:nushi/cleanup_dialog.dart';
import 'package:nushi/cleanup_job.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/conventions.dart' show CommandKey;
import 'package:nushi/daemon.dart';
import 'package:nushi/edit_bars.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/fork_chat.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/key_choice.dart' show sameKey;
import 'package:nushi/keys.dart';
import 'package:nushi/native.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/open_file.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/preview_find.dart' show focusedPreviewFind;
import 'package:nushi/preview_marks.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_link_dialog.dart';
import 'package:nushi/review.dart';
import 'package:nushi/rewind_picker.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/spell_check.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/update_toast.dart';
import 'package:nushi/view_options.dart';
import 'package:nushi/web_find.dart' show focusedPageFind, pageFinds;
import 'package:nushi/web_views.dart' show webEmbedded;
import 'package:nushi/widgets.dart';

// The app's actions in one place: each is a row of the ⌘K palette, its
// key (bound at the app's root, and passed on by a terminal) and, when it
// names a menu, a menu bar item.

/// The menus an action can be in; the Chat menu's are the chat's ⋯ menu
/// too.
enum ActMenu { nushi, file, view, chat }

/// ⌘F: find in the chat's transcript, or its changed files. A focused
/// terminal keeps it for its own find, the preview's editor for the
/// file's (`EditorFind`), and a preview with the focus for what it shows
/// (`FindSlot`).
const findKey = Cmd(LogicalKeyboardKey.keyF, id: 'find');

/// ⇧⌘B: a side chat (Claude Code's /btw, "by the way").
const sideChatKey = Cmd(LogicalKeyboardKey.keyB, shift: true, id: 'sideChat');

/// ⌘D: pin the chat, or unpin it (Arc's key for pinning a tab).
const pinKey = Cmd(LogicalKeyboardKey.keyD, id: 'pin');

/// ⌘\: hide the sidebar, or show it.
const sidebarKey = Cmd(LogicalKeyboardKey.backslash, id: 'sidebar');

/// ⌘[ and ⌘]: Back and Forward through the places visited (ADR 0119), as
/// Claude's desktop app and a browser. On Linux Alt+Left and Alt+Right, a
/// browser's there (Control and `[` is Escape): a text field keeps them
/// for its own moves, and a terminal for its shell.
const backKey = Cmd(
  LogicalKeyboardKey.bracketLeft,
  linux: SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true),
  id: 'back',
);
const forwardKey = Cmd(
  LogicalKeyboardKey.bracketRight,
  linux: SingleActivator(LogicalKeyboardKey.arrowRight, alt: true),
  id: 'forward',
);

/// ⌘;: the next flagged word in the composer, as macOS's Check Spelling.
/// On Linux F7, LibreOffice's spelling key: IBus takes Ctrl+; for its emoji.
const nextTypoKey = Cmd(
  LogicalKeyboardKey.semicolon,
  linux: SingleActivator(LogicalKeyboardKey.f7),
  id: 'nextTypo',
);

/// ⇧⌘E: the Files pane (VS Code's key for its Explorer).
const filesKey = Cmd(LogicalKeyboardKey.keyE, shift: true, id: 'files');

/// ⇧⌘Y: the Files pane's tree, shown or hidden (Claude desktop's key).
/// The View menu's item has it too, so it comes while WebKit has the keys.
const fileTreeKey = Cmd(LogicalKeyboardKey.keyY, shift: true, id: 'fileTree');

/// ⌘S: the preview's file, edited (ADR 0096). The editor leaves it to
/// the app.
const saveKey = Cmd(LogicalKeyboardKey.keyS, id: 'save');

/// ⌘L: the browser tab's address field (Safari's Open Location).
const addressKey = Cmd(LogicalKeyboardKey.keyL, id: 'address');

/// ⌘R: the browser tab's page again. Jira and GitHub keep ⌘R for their own
/// reload: their views bind it, under the app's keys.
const reloadPageKey = Cmd(LogicalKeyboardKey.keyR, id: 'reloadPage');

/// An action of the app. Settings › Keyboard shortcuts lists the keys
/// the user may rebind (those with a [keyName]) in this order within each
/// group, which is also the order two saved choices of one key settle in
/// (ADR 0146); the palette lists them in [appActions]' order.
enum Act {
  newChat(
    key: newChatKey,
    menu: ActMenu.file,
    menuLabel: 'New Chat…',
    keyName: 'New chat',
  ),
  openFile(
    key: openFileKey,
    menu: ActMenu.file,
    menuLabel: 'Open File…',
    keyName: 'Open file',
  ),
  closeTab(
    key: closeTabKey,
    menu: ActMenu.file,
    menuLabel: 'Close Tab',
    keyName: 'Close tab',
  ),
  save(key: saveKey, menu: ActMenu.file, menuLabel: 'Save', keyName: 'Save'),
  newBrowserTab(menu: ActMenu.file, menuLabel: 'New Browser Tab'),
  address(
    key: addressKey,
    menu: ActMenu.file,
    menuLabel: 'Open Location…',
    keyName: 'Open location',
  ),
  // No row of the palette itself; the menu bar's item is main.dart's.
  palette(key: paletteKey, keysIn: ActMenu.view, keyName: 'Command palette'),
  reloadPage(
    key: reloadPageKey,
    menu: ActMenu.view,
    menuLabel: 'Reload Page',
    keyName: 'Reload page',
  ),
  artifacts,
  find(key: findKey, menu: ActMenu.view, menuLabel: 'Find…', keyName: 'Find'),
  chat(
    key: chatTabKey,
    menu: ActMenu.view,
    menuLabel: 'Chat',
    keyName: 'Chat tab',
  ),
  changes(
    key: changesTabKey,
    menu: ActMenu.view,
    menuLabel: 'Changes',
    keyName: 'Changes tab',
  ),
  pull(
    key: pullTabKey,
    menu: ActMenu.view,
    menuLabel: 'Pull Request',
    keyName: 'Pull request tab',
  ),
  previousTab(
    key: previousTabKey,
    menu: ActMenu.view,
    menuLabel: 'Previous Tab',
    keyName: 'Previous tab',
  ),
  nextTab(
    key: nextTabKey,
    menu: ActMenu.view,
    menuLabel: 'Next Tab',
    keyName: 'Next tab',
  ),
  sidebar(
    key: sidebarKey,
    menu: ActMenu.view,
    menuLabel: 'Hide Sidebar',
    keyName: 'Show or hide sidebar',
  ),
  details,
  files(
    key: filesKey,
    menu: ActMenu.view,
    menuLabel: 'Files',
    keyName: 'Files pane',
  ),
  // The Files pane's options, in its ⋯'s order (view_options.dart): their
  // View items' labels follow what each is now.
  fileTree(
    key: fileTreeKey,
    menu: ActMenu.view,
    menuLabel: 'Show File Tree',
    keyName: 'File tree',
  ),
  // View › File Tree Position's submenu, its values' rows.
  treeAutomatic(menu: ActMenu.view, menuLabel: 'File Tree Position'),
  treeLeft,
  treeRight,
  collapseFolders(menu: ActMenu.view, menuLabel: 'Collapse All Folders'),
  previewTabs(menu: ActMenu.view, menuLabel: 'Use Preview Tabs'),
  // The viewer's own key: elsewhere ⌥Z types a character.
  wrap(
    shows: wrapKey,
    menu: ActMenu.view,
    menuLabel: 'Wrap Lines',
    keyName: 'Wrap lines',
  ),
  indentGuides(menu: ActMenu.view, menuLabel: 'Show Indent Guides'),
  whitespace(menu: ActMenu.view, menuLabel: 'Show Whitespace'),
  scrollPastEnd(menu: ActMenu.view, menuLabel: 'Scroll Past End'),
  // View › Tab Size's submenu, its values' rows.
  tabSize2(menu: ActMenu.view, menuLabel: 'Tab Size'),
  tabSize4,
  tabSize8,
  chatWidth,
  unifiedDiff(menu: ActMenu.view, menuLabel: 'Show Diffs Unified'),
  terminal(key: toggleTerminalKey, keyName: 'Terminal'),
  rewind(keyText: 'Esc Esc'), // the composer's
  sideChat(
    key: sideChatKey,
    menu: ActMenu.chat,
    menuLabel: 'Side Chat',
    keyName: 'Side chat',
  ),
  fork(menu: ActMenu.chat, menuLabel: 'Fork Chat'),
  sendComments(menu: ActMenu.chat, menuLabel: 'Send Review Comments to Agent'),
  stop(keyText: 'Esc', menu: ActMenu.chat, menuLabel: 'Stop'), // the chat's
  rename(menu: ActMenu.chat, menuLabel: 'Rename'),
  pin(
    key: pinKey,
    menu: ActMenu.chat,
    menuLabel: 'Pin Chat',
    keyName: 'Pin chat',
  ),
  sleep(menu: ActMenu.chat, menuLabel: 'Sleep'),
  reload(menu: ActMenu.chat, menuLabel: 'Reload'),
  nextTypo(
    key: nextTypoKey,
    menu: ActMenu.chat,
    menuLabel: 'Next Typo',
    keyName: 'Next typo',
  ),
  linkPull(menu: ActMenu.chat, menuLabel: 'Link Pull Request…'),
  cleanUp(menu: ActMenu.chat, menuLabel: 'Clean Up…'),
  archive(menu: ActMenu.chat, menuLabel: 'Archive'),
  unarchive(menu: ActMenu.chat, menuLabel: 'Unarchive'),
  mcp(menu: ActMenu.chat, menuLabel: 'MCP Servers…'),
  skills(menu: ActMenu.chat, menuLabel: 'Skills…'),
  delete(menu: ActMenu.chat, menuLabel: 'Delete…'),
  settings(
    key: settingsKey,
    menu: ActMenu.nushi,
    menuLabel: 'Settings…',
    keyName: 'Settings',
  ),
  appearance,
  shortcuts,
  jira(key: jiraKey, menu: ActMenu.view, menuLabel: 'Jira', keyName: 'Jira'),
  github(
    key: githubKey,
    menu: ActMenu.view,
    menuLabel: 'GitHub',
    keyName: 'GitHub',
  ),
  restart,
  checkUpdates(menu: ActMenu.nushi, menuLabel: 'Check for Updates…'),
  // The menu bar's in View, written there (main.dart); Linux's palette has
  // Previous and Next chat, where no menu bar has them.
  back(key: backKey, keysIn: ActMenu.view, keyName: 'Back'),
  forward(key: forwardKey, keysIn: ActMenu.view, keyName: 'Forward'),
  previousChat(
    shows: previousChatKey,
    keysIn: ActMenu.view,
    keyName: 'Previous chat',
  ),
  nextChat(shows: nextChatKey, keysIn: ActMenu.view, keyName: 'Next chat'),
  // The Mac's is its Nushi menu's.
  quit(shows: quitKey);

  new({
    this.key,
    this.shows,
    this.keyText,
    this.menu,
    this.menuLabel,
    this.keyName,
    ActMenu? keysIn,
  }) : keysIn = keysIn ?? menu;

  /// The key the app binds to it, wherever the focus is.
  final Cmd? key;
  final Cmd? shows; // shown, not bound: another widget has it
  final String? keyText; // the same, in words
  final ActMenu? menu;
  final String? menuLabel;

  /// What Settings › Keyboard shortcuts calls its key, for one the user
  /// may rebind (its key's `id` is the Act's name); null for the rest.
  final String? keyName;

  /// The group that page lists its key in: its menu's, unless given; null
  /// for Other.
  final ActMenu? keysIn;

  /// Its key as the palette and tooltips show it; null for none, a key
  /// the user cleared too.
  String? get shortcut =>
      keyText ??
      switch (key ?? shows) {
        final k? when keyLabel(k).isNotEmpty => keyLabel(k),
        _ => null,
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

/// ⌘Q: quits the app, where no menu bar has Quit (Linux); the Mac's is its
/// menu's. It asks the window to close, so unsaved edits still ask.
const quitKey = Cmd(LogicalKeyboardKey.keyQ);

/// ⌘K opens the palette ([Act.palette]), and ⌘⇧P, which a terminal (where
/// ⌘K clears) passes on too: the second only while the first is the
/// default.
const paletteKey = Cmd(LogicalKeyboardKey.keyK, id: 'palette');
const paletteKeyToo = Cmd(
  LogicalKeyboardKey.keyP,
  shift: true,
  aliasOf: 'palette',
);

/// Whether [act]'s key is the focused text field's own, which keeps it:
/// Alt+Left and Alt+Right, Linux's Back and Forward by default, move along
/// its line there (ADR 0119); a key chosen in their place is no field's.
/// The Mac's ⌘[ and ⌘] are no field's.
bool actKeyTaken(Act act) {
  final key = act.key?.single;
  return key != null &&
      commandKey == CommandKey.control &&
      _fieldMoves.any((k) => sameKey(k, key)) &&
      FocusManager.instance.primaryFocus?.context
              ?.findAncestorStateOfType<EditableTextState>() !=
          null;
}

/// Alt+Left and Alt+Right, which a text field moves by where the command
/// key is Control.
const _fieldMoves = [
  SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true),
  SingleActivator(LogicalKeyboardKey.arrowRight, alt: true),
];

/// The second keys (ADR 0146): ⇧⌘] and ⇧⌘[ for the tabs, each also as
/// the key ⇧ makes of it, and ⇧⌘P for the palette; each bound only while
/// its action ([Cmd.aliasOf]) keeps its default.
const secondKeys = <Cmd>[
  ...nextTabKeysToo,
  ...previousTabKeysToo,
  paletteKeyToo,
];

/// The keys of the actions that have one, and their second keys, as the
/// intents that run them.
final Map<ShortcutActivator, Intent> actKeys = {
  for (final a in Act.values) ?a.key: RunActIntent(a),
  for (final k in secondKeys) k: RunActIntent(Act.values.byName(k.aliasOf!)),
};

/// Every key the app binds wherever the focus is, as the intents they
/// run: the actions' and the chats'. The window binds them (and Quit's
/// where there's no menu bar), a focused terminal those it passes on, and
/// Settings stops them (ADR 0087).
final Map<ShortcutActivator, Intent> appKeys = {...actKeys, ...chatKeys};

/// Every action, each as it is now (its title, whether it applies).
/// [context] is where its dialogs open.
List<AppAction> appActions(BuildContext context, Daemon d) {
  final chat = d.selected;
  final shown = d.chatShows ? chat : null;
  void tab(ChatTab t) => shown?.tab.value = t;
  final details = showDetails.value;
  final terminal = shown != null && terminalChats.value.contains(shown.id);
  // The browser tab in sight, under no dialog.
  final browser = switch (shown?.browser.shown.value) {
    final tab?
        when shown?.shownTab == ChatTab.chat &&
            !(Navigator.maybeOf(context)?.canPop() ?? false) =>
      tab.view,
    _ => null,
  };
  // The file the preview shows, being edited, in sight under no dialog.
  final edited = switch (shown?.shownFile) {
    final path?
        when shown?.shownTab == ChatTab.chat &&
            !(Navigator.maybeOf(context)?.canPop() ?? false) =>
      shown!.edits[path],
    _ => null,
  };
  final closing = shown == null ? null : tabToClose(shown);
  // The preview with the focus, which ⌘F finds in (issue 63); else the
  // chat's or Changes', not under a pane expanded over the transcript,
  // where its bar would open unseen.
  final preview = shown == null ? null : focusedPreviewFind();
  final chatFinds =
      shown != null &&
      (shown.shownTab == ChatTab.chat && shown.covered == null ||
          shown.shownTab == ChatTab.changes);
  return [
    AppAction(.newChat, 'New chat', run: () => newChat(context, d, '')),
    AppAction(
      .openFile,
      'Open file…',
      enabled: shown != null,
      run: () => unawaited(openFile(context, d)),
    ),
    AppAction(
      .closeTab,
      'Close tab',
      // Only a tab in sight, and never under a dialog: its ⌘W, which
      // Flutter's keys don't reach, comes here from the menu bar.
      enabled:
          closing != null &&
          shown?.shownTab == ChatTab.chat &&
          !(Navigator.maybeOf(context)?.canPop() ?? false),
      run: () => unawaited(closeTabSaving(context, shown!, closing!)),
    ),
    AppAction(
      .save,
      'Save the file',
      enabled: edited?.canSave ?? false,
      run: () => unawaited(edited!.save()),
    ),
    AppAction(
      .newBrowserTab,
      'New browser tab',
      enabled: shown != null,
      run: () => shown!.openBrowserTab(),
    ),
    // ⌘L and ⌘R are the menu bar's too, so they reach here while WebKit has
    // the keys (ADR 0094).
    AppAction(
      .address,
      'Open location…',
      enabled: browser != null,
      run: () => browser!.focusAddress(),
    ),
    AppAction(
      .reloadPage,
      'Reload page',
      // A page in the browser reloads there (ADR 0104).
      enabled: browser != null && webEmbedded,
      run: () => browser!.reload(),
    ),
    AppAction(
      .artifacts,
      'Artifacts…',
      enabled: shown != null && chatFilesOf(shown).isNotEmpty,
      run: () => revealArtifacts(context, shown!),
    ),
    AppAction(
      .find,
      preview != null
          ? 'Find in the file'
          : shown?.shownTab == ChatTab.changes
          ? 'Find in changes'
          : 'Find in the chat',
      // A preview with the focus finds in its file. A page's web view with
      // the keys gives ⌘F to the menu bar, which comes here: that page's
      // find, asked of the web views shown.
      enabled: preview != null || pageFinds.isNotEmpty || chatFinds,
      run: () {
        void own() {
          if (preview != null) {
            preview.open();
          } else if (chatFinds) {
            shown.shownTab == ChatTab.changes
                ? shown.changesFind.open()
                : shown.find.open();
          }
        }

        if (pageFinds.isEmpty) return own();
        unawaited(
          focusedPageFind().then(
            (page) => page == null ? own() : page.openFromPage(),
          ),
        );
      },
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
      .previousTab,
      'Previous tab',
      enabled: shown != null,
      run: () => stepTab(shown!, -1),
    ),
    AppAction(
      .nextTab,
      'Next tab',
      enabled: shown != null,
      run: () => stepTab(shown!, 1),
    ),
    AppAction(
      .sidebar,
      sidebarShut ? 'Show the sidebar' : 'Hide the sidebar',
      run: toggleSidebar,
    ),
    AppAction(.back, 'Back', enabled: d.canGoBack, run: d.goBack),
    AppAction(.forward, 'Forward', enabled: d.canGoForward, run: d.goForward),
    AppAction(
      .details,
      details ? 'Hide details' : 'Show details',
      enabled: shown?.shownTab == ChatTab.chat,
      run: () => showDetails.value = !details,
    ),
    AppAction(
      .files,
      shown != null && filesShown(shown) ? 'Hide files' : 'Show files',
      enabled: shown != null && d.daemonApi >= filesApi,
      run: () => showOrHideFiles(shown!),
    ),
    ...viewActions(shown, d),
    AppAction(
      .chatWidth,
      chatFullWidth.value ? 'Center the chat' : 'Show the chat at full width',
      run: () => chatFullWidth.value = !chatFullWidth.value,
    ),
    AppAction(
      .unifiedDiff,
      diffUnified.value ? 'Show diffs side by side' : 'Show diffs unified',
      // One choice for the app, as a pull request's Files follows it too.
      run: () => diffUnified.value = !diffUnified.value,
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
      // A long chat's earlier messages may be rewound to once loaded; the
      // chat itself must allow it now, as each message's own check asks.
      enabled:
          shown != null &&
          (rewindChoices(shown).isNotEmpty ||
              (shown.older > 0 &&
                  shown.canRewind &&
                  !shown.busy &&
                  !shown.archived)),
      run: () => unawaited(pickRewind(context, d, shown!)),
    ),
    AppAction(
      .nextTypo,
      'Next typo',
      enabled: _spellOf(shown) != null,
      run: () => unawaited(_spellOf(shown)!.menu.next()),
    ),
    ...chatActions(context, d, shown),
    AppAction(.settings, 'Settings', run: d.toggleSettings),
    AppAction(
      .appearance,
      'Appearance and themes',
      run: () => d.openSettings(section: SettingsSection.appearance),
    ),
    AppAction(
      .shortcuts,
      'Keyboard shortcuts',
      run: () => d.openSettings(section: SettingsSection.shortcuts),
    ),
    AppAction(
      .jira,
      d.place is JiraPlace ? 'Close Jira' : 'Jira',
      run: () => d.toggle(const JiraPlace()),
    ),
    AppAction(
      .github,
      d.place is GitHubPlace ? 'Close GitHub' : 'GitHub',
      run: () => d.toggle(const GitHubPlace()),
    ),
    AppAction(
      .restart,
      'Restart daemon',
      enabled: native.install.restartsDaemon,
      run: () => unawaited(restartDaemonAsking(context, d)),
    ),
    AppAction(
      .checkUpdates,
      'Check for updates',
      enabled: d.connected && d.daemonApi >= updatesApi,
      run: () => unawaited(checkForUpdates(context, d)),
    ),
    if (!native.window.menuBar) ...[
      AppAction(
        .previousChat,
        'Previous chat',
        enabled: d.chats.isNotEmpty,
        run: () => stepChat(d, -1),
      ),
      AppAction(
        .nextChat,
        'Next chat',
        enabled: d.chats.isNotEmpty,
        run: () => stepChat(d, 1),
      ),
      AppAction(.quit, 'Quit Nushi', run: () => unawaited(_quit())),
    ],
  ];
}

/// Quits the app, where no menu bar's Quit does: what would be lost asks
/// first (the app's onExitRequested: edits that can't be saved), as a
/// cancelable exit's request does, and then the engine exits.
Future<void> _quit() async {
  final binding = ServicesBinding.instance;
  if (await binding.handleRequestAppExit() == AppExitResponse.exit) {
    await binding.exitApplication(AppExitType.required);
  }
}

/// Clean up the worktree…: with the tab's pull request whole, for its
/// branch on GitHub (read now unless the tab shows it; ADR 0140).
Future<void> _cleanUp(BuildContext context, Daemon d, ChatState chat) async {
  final cp = ChatPull.of(d, chat);
  final l = cp.current;
  final pull = l == null ? null : await cp.whole(context, l);
  if (!context.mounted) return;
  await showCleanUp(context, d, chat, pull: pull);
}

/// The spell check ⌘; goes through in [chat], while it runs: its prompt
/// box's, or its side chat's if that one has the focus. The box must be in
/// sight.
SpellCheck? _spellOf(ChatState? chat) {
  if (chat == null || chat.shownTab != ChatTab.chat) return null;
  final side = chat.side.value?.draft.text.spell;
  final spell = side?.focus.hasFocus ?? false ? side : chat.draft.text.spell;
  return (spell?.on ?? false) ? spell : null;
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
      .sideChat,
      switch (chat?.side.value) {
        null => 'Side chat',
        _ when chat!.sideHidden.value => 'Show the side chat',
        _ => 'Hide the side chat',
      },
      enabled: live && (chat.canFork || chat.side.value != null),
      run: () => unawaited(toggleSide(context, d, chat!)),
    ),
    AppAction(
      .fork,
      'Fork chat',
      short: 'Fork',
      enabled: canForkChat(d, chat),
      run: () => unawaited(forkChat(context, d, chat!)),
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
      .pin,
      (chat?.pin ?? 0) > 0 ? 'Unpin chat' : 'Pin chat',
      short: (chat?.pin ?? 0) > 0 ? 'Unpin' : 'Pin',
      enabled: canPinChat(d, chat),
      run: () => tryOrShow(context, () => toggleChatPin(d, chat!)),
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
      // Nothing in the chat shows a reload: a toast says it.
      run: () => unawaited(reloadChat(context, chat!, d, say: true)),
    ),
    AppAction(
      .linkPull,
      chat?.pull == null ? 'Link pull request…' : 'Link another pull request…',
      enabled: live && d.daemonApi >= chatPullApi,
      run: () => unawaited(linkPull(context, ChatPull.of(d, chat!))),
    ),
    AppAction(
      .cleanUp,
      'Clean up the worktree…',
      short: 'Clean up…',
      enabled:
          chat != null &&
          chat.worktree != null &&
          d.daemonApi >= cleanUpApi &&
          !CleanUpJob.of(chat).running,
      run: () => unawaited(_cleanUp(context, d, chat!)),
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

/// Runs [act] as it is now, if it applies.
void runAct(BuildContext context, Daemon d, Act act) {
  // The palette is no row of its own; its key never reaches here past
  // Settings, so it shuts nothing.
  if (act == Act.palette) return unawaited(showPalette(context, d));
  // Only the menu bar (and Linux's Quit) reaches here past Settings (it
  // stops the keys): what runs is elsewhere, so Settings shuts first (ADR
  // 0087).
  if (!const {
    Act.settings,
    Act.appearance,
    Act.shortcuts,
    Act.quit,
  }.contains(act)) {
    d.closeSettings();
  }
  final a = appActions(context, d).firstWhere((a) => a.act == act);
  if (a.enabled) a.run();
}
