import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/conventions.dart' show CommandKey;
import 'package:nushi/github_view.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/key_choice.dart' show sameKey;
import 'package:nushi/keys.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/open_file.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/terminal_panel.dart';

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
/// (ADR 0146); the palette lists them in `appActions`' order.
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
