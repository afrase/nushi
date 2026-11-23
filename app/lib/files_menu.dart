import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:nushi/app_actions.dart' show fileTreeKey;
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/open_file.dart';
import 'package:nushi/view_options.dart';

/// The Files pane's ⋯ (ADR 0123), Claude desktop's rows in its order and
/// groups: Go to file or search (⌘P's box), Show file tree, Collapse all
/// folders, then how a source shows. Each option's row reads and flips its
/// one pref ([viewToggles]). [folded] are the second row's file actions
/// where it has no room for them, last after a line, so Claude's rows keep
/// their places. [treeShows] and [treeOut] are the second row's: the tree's
/// rows say what the pane shows, not only the pref.
List<MenuEntry> filesMenu(
  BuildContext context,
  ChatState chat,
  Daemon daemon, {
  bool treeShows = false,
  bool treeOut = false,
  List<MenuEntry> folded = const [],
}) {
  return [
    MenuEntry(
      'Go to file or search',
      shortcut: keyLabel(openFileKey),
      onPick: () => unawaited(openFile(context, daemon)),
    ),
    MenuEntry.divider,
    MenuEntry(
      'Show file tree',
      checked: treeShows,
      shortcut: keyLabel(fileTreeKey),
      onPick: !treeOut ? () => toggleFileTree(chat) : null,
    ),
    _choice(treeSideChoice),
    MenuEntry.divider,
    MenuEntry(
      'Collapse all folders',
      onPick: treeShows && canCollapseFolders(chat, daemon)
          ? folderTreeOf(chat).collapseAll
          : null,
    ),
    MenuEntry.divider,
    _toggle(previewTabsOption),
    MenuEntry.divider,
    for (final o in sourceToggles) _toggle(o),
    _choice(tabSizeChoice),
    if (folded.isNotEmpty) ...[MenuEntry.divider, ...folded],
  ];
}

/// [option]'s row, checked while it's on.
MenuEntry _toggle(ViewToggle option) =>
    MenuEntry(option.label, checked: option.pref.value, onPick: option.toggle);

/// [choice]'s row: its value now at the right, its values in a submenu,
/// the one now checked.
MenuEntry _choice<T>(ViewChoice<T> choice) => MenuEntry(
  choice.label,
  detail: choice.current,
  submenu: [
    for (final (value, name, _, _) in choice.values)
      MenuEntry(
        name,
        checked: choice.pref.value == value,
        onPick: () => choice.pref.value = value,
      ),
  ],
);
