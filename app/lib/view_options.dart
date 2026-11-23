import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_open.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/settings.dart';

// The Files pane's view options in one table (ADR 0123): each is one pref,
// and the pane's ⋯, the View menu, the palette and Settings › Appearance
// (where one has a row) all show and change it through here.

/// A view option that's on or off: its [pref], the one place it's kept,
/// and what each place that flips it says. The ⋯'s row says [label]
/// (Claude desktop's words), checked while it's on; the View menu's item
/// ([viewOn] while it's on, [viewOff] while off) and the palette's row
/// ([paletteOn], [paletteOff]) say what picking them does.
final class ViewToggle {
  const new({
    required this.act,
    required this.pref,
    required this.label,
    required this.viewOn,
    required this.viewOff,
    required this.paletteOn,
    required this.paletteOff,
  });

  final Act act;
  final Pref<bool> pref;
  final String label;
  final String viewOn;
  final String viewOff;
  final String paletteOn;
  final String paletteOff;

  /// The View menu's label as it is now.
  String get viewLabel => pref.value ? viewOn : viewOff;

  /// The palette's title as it is now.
  String get paletteTitle => pref.value ? paletteOn : paletteOff;

  /// Turns it on, or off.
  void toggle() => pref.value = !pref.value;
}

/// Preview tabs: a click in the tree opens a provisional tab (ADR 0070).
final previewTabsOption = ViewToggle(
  act: Act.previewTabs,
  pref: previewTabs,
  label: 'Preview tabs',
  viewOn: 'Don’t Use Preview Tabs',
  viewOff: 'Use Preview Tabs',
  paletteOn: 'Don’t use preview tabs',
  paletteOff: 'Use preview tabs',
);

/// Word wrap: a source's long lines wrap, or run on (⌥Z in the viewer).
final wrapOption = ViewToggle(
  act: Act.wrap,
  pref: wrapLines,
  label: 'Word wrap',
  viewOn: 'Don’t Wrap Lines',
  viewOff: 'Wrap Lines',
  paletteOn: 'Don’t wrap lines in Files',
  paletteOff: 'Wrap lines in Files',
);

/// Indent guides: a faint line down each of a source's indent levels.
final indentGuidesOption = ViewToggle(
  act: Act.indentGuides,
  pref: indentGuides,
  label: 'Indent guides',
  viewOn: 'Hide Indent Guides',
  viewOff: 'Show Indent Guides',
  paletteOn: 'Hide indent guides in Files',
  paletteOff: 'Show indent guides in Files',
);

/// Show whitespace: a source's spaces and tabs marked (ADR 0096).
final whitespaceOption = ViewToggle(
  act: Act.whitespace,
  pref: showWhitespace,
  label: 'Show whitespace',
  viewOn: 'Hide Whitespace',
  viewOff: 'Show Whitespace',
  paletteOn: 'Hide whitespace in Files',
  paletteOff: 'Show whitespace in Files',
);

/// Scroll past end: a source scrolls on until its last line is at the top.
final scrollPastEndOption = ViewToggle(
  act: Act.scrollPastEnd,
  pref: scrollPastEnd,
  label: 'Scroll past end',
  viewOn: 'Don’t Scroll Past End',
  viewOff: 'Scroll Past End',
  paletteOn: 'Don’t scroll past the end in Files',
  paletteOff: 'Scroll past the end in Files',
);

/// The view options that are on or off, in the ⋯'s order.
final List<ViewToggle> viewToggles = [
  previewTabsOption,
  wrapOption,
  indentGuidesOption,
  whitespaceOption,
  scrollPastEndOption,
];

/// Those of [viewToggles] about how a source shows, a group of the ⋯.
List<ViewToggle> get sourceToggles => [
  for (final o in viewToggles)
    if (o != previewTabsOption) o,
];

/// A view option of a few values: its [pref], the ⋯'s row ([label], the
/// value now at its right, a submenu of [values]) and the View menu's
/// submenu ([viewLabel], its first value's [Act] standing for it there,
/// the value now disabled: the menu bar has no checks). Each value is its
/// name, its action and the palette's row for it, listed while it isn't
/// the value.
final class ViewChoice<T> {
  const new({
    required this.pref,
    required this.label,
    required this.viewLabel,
    required this.values,
  });

  final Pref<T> pref;
  final String label;
  final String viewLabel;
  final List<(T value, String name, Act act, String palette)> values;

  /// The value's name now.
  String get current => values
      .firstWhere((v) => v.$1 == pref.value, orElse: () => values.first)
      .$2;
}

/// File tree position: Automatic, Left or Right ([treeOnRight]).
final treeSideChoice = ViewChoice<TreeSide>(
  pref: filesTreeSide,
  label: 'File tree position',
  viewLabel: 'File Tree Position',
  values: [
    (
      TreeSide.automatic,
      'Automatic',
      Act.treeAutomatic,
      'Place the file tree automatically',
    ),
    (TreeSide.left, 'Left', Act.treeLeft, 'Put the file tree on the left'),
    (TreeSide.right, 'Right', Act.treeRight, 'Put the file tree on the right'),
  ],
);

/// Tab size: the columns between a source's tab stops (ADR 0096).
final tabSizeChoice = ViewChoice<int>(
  pref: tabSize,
  label: 'Tab size',
  viewLabel: 'Tab Size',
  values: [
    for (final (size, act) in [
      (2, Act.tabSize2),
      (4, Act.tabSize4),
      (8, Act.tabSize8),
    ])
      (size, '$size', act, 'Tab size $size in Files'),
  ],
);

/// The view options of a few values.
final List<ViewChoice<Object?>> viewChoices = [treeSideChoice, tabSizeChoice];

/// The choice whose View submenu [act] stands for, if any.
ViewChoice<Object?>? viewChoiceOf(Act act) {
  for (final c in viewChoices) {
    if (c.values.first.$3 == act) return c;
  }
  return null;
}

/// Shows [chat]'s Files pane with its tree, or, while the pane shows, the
/// tree or not ([filesTree]): ⇧⌘Y, the pane's button, its ⋯, View › Show
/// File Tree and the palette. From the Changes tab it's the Chat tab's.
void toggleFileTree(ChatState chat) {
  if (filesShown(chat)) {
    filesTree.value = !filesTree.value;
    return;
  }
  showOrHideFiles(chat);
  filesTree.value = true;
}

/// Whether [chat]'s Files pane shows its tree: the pane shows and the user
/// has it on.
bool fileTreeShown(ChatState chat, Daemon daemon) =>
    filesShown(chat) && filesTree.value;

/// Whether Collapse all folders has something to do in [chat]: its tree
/// shows with a folder open.
bool canCollapseFolders(ChatState chat, Daemon daemon) =>
    fileTreeShown(chat, daemon) && folderTreeOf(chat).anyOpen;

/// The View menu's label for [act] as it is now, [chat] being the one
/// shown; null for an action that isn't a view option's. The tree's says
/// what picking it does ([toggleFileTree]), as the palette's row does.
String? viewMenuLabel(Act act, ChatState? chat, Daemon daemon) {
  if (act == Act.fileTree) {
    final shown = chat != null && fileTreeShown(chat, daemon);
    return shown ? 'Hide File Tree' : 'Show File Tree';
  }
  for (final o in viewToggles) {
    if (o.act == act) return o.viewLabel;
  }
  return null;
}

/// The palette's rows of the view options, [shown] the chat that shows.
List<AppAction> viewActions(ChatState? shown, Daemon d) => [
  AppAction(
    .fileTree,
    shown != null && fileTreeShown(shown, d)
        ? 'Hide the file tree'
        : 'Show the file tree',
    enabled: shown != null,
    run: () => toggleFileTree(shown!),
  ),
  // Each value but the one now, where a chat shows; the tree's only where
  // it can show.
  for (final c in viewChoices)
    for (final (value, _, act, title) in c.values)
      AppAction(
        act,
        title,
        enabled: c.pref.value != value && shown != null,
        run: () => c.pref.value = value,
      ),
  AppAction(
    .collapseFolders,
    'Collapse all folders',
    enabled: shown != null && canCollapseFolders(shown, d),
    run: () => folderTreeOf(shown!).collapseAll(),
  ),
  for (final o in viewToggles)
    AppAction(
      o.act,
      o.paletteTitle,
      // Whitespace where a chat shows, as its files do; wrapping always,
      // as it was.
      enabled: o.act == Act.wrap || shown != null,
      run: o.toggle,
    ),
];
