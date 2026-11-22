import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'package:nushi/app_log.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/file_tabs.dart' show KeptTabs;
import 'package:nushi/fonts.dart';
import 'package:nushi/tile_images.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/tile_picture.dart';
import 'package:nushi/usage_range.dart';

/// What the app remembers across launches, in `app.json` in the data folder:
/// whether the details panel shows (its toolbar button), which of its widgets
/// are collapsed and their order, what each chat's Changes view shows, the
/// side panes' widths (not the details panel's, which is fixed), whether
/// changed files show flat and diffs unified, which chats show their
/// terminals and their Files pane, its file tabs, whether it lists ignored
/// files and
/// shows its tree and on which side, whether its clicks open preview tabs,
/// its tab size, indent guides and scrolling past the end, the
/// terminal's font, the app's and code's fonts, whether the chat takes the
/// whole width,
/// whether the sidebar is hidden, the Jira task list's groups and assignee
/// filters, the GitHub view's cards and filters, the sidebar's project
/// groups' order and which are collapsed, the projects it keeps (with
/// chats or none), whether it has the project rail, the project it's
/// narrowed to and each project's tile, each project's chats' order,
/// whether Pinned is collapsed and whether it keeps every project's
/// pins while the sidebar is narrowed to one, the sidebar's arrangement
/// (grouping, sort, what rows show),
/// each project's own sort, and sections, the models picked last, each
/// repository's merge method, each chat's pinned artifacts, and the Mac's
/// notifications and Dock badge, the appearance and the color theme,
/// whether the composer checks spelling, whether Enter starts a line in
/// the boxes that send, whether the plan pinned over it
/// shows collapsed, whether a chat's links open in a
/// browser tab and which sites there may reach the local network, whether a
/// preview's source wraps its lines and shows its whitespace,
/// what reply cards ask the agent, the pull request each chat's tab shows,
/// the failed checks each chat's user acted on, the comments seen of
/// each chat's pull requests,
/// the range Settings › Usage shows, the newer release whose toast
/// was dismissed, the remote access reset last said in a toast, and the
/// keys chosen in Settings › Keyboard shortcuts.
/// Each is a [Pref].
/// Not whether new chats get a worktree, nor whether a subagent's pane
/// shows wide, nor a beta's `projectRail`: an older `worktrees`,
/// `subagentWide` or `projectRail` key is ignored, and dropped by the
/// next save. What a newer app saved (a beta's, ADR 0108) stays as it
/// was: a key this one has no pref for, and a value it can't read until
/// the user changes that pref.
final Pref<bool> showDetails = _plain('details', true);

/// The details panel's widgets collapsed, by title.
final Pref<Set<String>> collapsedWidgets = _set('collapsed');

/// The details panel's widgets by title, in the order they were dragged
/// into. Saved under `cards`, from when they were called that.
final Pref<List<String>> widgetOrder = _list('cards');

/// What each chat's Changes view shows (a `Scope`'s name), by chat, once
/// picked.
final Pref<Map<String, String>> changeScopes = _byChat(
  'scopes',
  (v) => v is String ? v : null,
);

/// Whether the Changes view lists its files flat rather than as a tree.
final Pref<bool> changesFlat = _plain('flat', false);

/// Whether diffs show unified, in one column, rather than side by side
/// (ADR 0107).
final Pref<bool> diffUnified = _plain('unified', false);

/// The chats whose terminal panel is open.
final Pref<Set<String>> terminalChats = _set('terminals', chats: true);

/// The chats whose Files pane is open, however it opened (its own button
/// or a file's opening; ADR 0123's amendment of 2026-11-19), and whether
/// the pane lists what git ignores.
final Pref<Set<String>> filesChats = _set('files', chats: true);
final Pref<bool> filesIgnored = _plain('filesIgnored', false);

/// Each chat's file tabs (ADR 0070's amendment of 2026-11-19), by chat
/// id: their names, the one that shows, the provisional one and those
/// showing their Source (`files_kept.dart` puts them back).
final Pref<Map<String, KeptTabs>> fileTabsKept = Pref(
  'fileTabs',
  (v) => _entries(v, KeptTabs.read),
  write: (m) => {
    for (final MapEntry(:key, :value) in m.entries) key: value.json,
  },
  chats: (m) => m.keys,
  without: (m, gone) => {...m}..removeWhere((id, _) => gone.contains(id)),
);

/// Whether the Files pane shows its tree beside its viewer (on at first;
/// ⇧⌘Y, its second row's button, its ⋯ and View › Show File Tree): one
/// for every chat, as Claude desktop's.
final Pref<bool> filesTree = _plain('filesTree', true);

/// Whether a click in the Files pane's tree opens a provisional tab (on at
/// first), as Claude desktop's and VS Code's Preview tabs: in italics, the
/// next click's file takes its place until it's kept (a double click, an
/// edit, a pin). Off, every file opened keeps its tab.
final Pref<bool> previewTabs = _plain('previewTabs', true);

/// Whether the Files pane's source and editor draw indent guides (on at
/// first, as Claude desktop's): a faint line down each indent level.
final Pref<bool> indentGuides = _plain('indentGuides', true);

/// Whether the Files pane's source and editor scroll on past their last
/// line, until it's at the top (off at first), as Claude desktop's Scroll
/// past end.
final Pref<bool> scrollPastEnd = _plain('scrollPastEnd', false);

/// The columns between tab stops in the Files pane's source and editor
/// (ADR 0096): 2, 4 (at first) or 8, Claude desktop's Tab size. Anything
/// else saved reads as 4.
final tabSize = Pref<int>(
  'tabSize',
  (v) => v is int && tabSizes.contains(v) ? v : 4,
);

/// The tab sizes there are.
const tabSizes = [2, 4, 8];

/// Which side of the Files pane its tree is on, as Claude desktop's File
/// tree position: Automatic (the side away from the transcript, the
/// right while the panes are right of it), Left or Right.
final filesTreeSide = Pref<TreeSide>(
  'filesTreeSide',
  (v) => TreeSide.values.asNameMap()[v] ?? TreeSide.automatic,
  write: (side) => side.name,
);

/// The Files pane's tree's side ([filesTreeSide]).
enum TreeSide { automatic, left, right }

/// Whether the tree is at the Files pane's right on [side]: Automatic puts
/// it away from the transcript, which is left of every side pane (ADR
/// 0123). The one place to change should the panes' order change.
bool treeOnRight(TreeSide side) => side != TreeSide.left;

/// The Jira site used last (shown in the Jira view, or an issue picked from
/// it for a chat): a key typed alone is looked for there.
final Pref<String?> lastJiraSite = _plain('jiraSite', null);

/// The Jira task list's status groups, by site (`*` for every site's
/// list): the order they were dragged into (statuses it doesn't name go
/// last), and those collapsed.
final Pref<Map<String, List<String>>> jiraGroupOrder = _places('jiraGroups');
final Pref<Map<String, List<String>>> jiraCollapsed = _places('jiraCollapsed');

/// The Jira lists' assignee filters, by site and list (`jira_people.dart`'s
/// `filterPlace`): `["me"]`, `["none"]` or `["person", id, name]`; a list
/// not named shows everyone's.
final Pref<Map<String, List<String>>> jiraAssignee = _places('jiraAssignee');

/// Whether the GitHub view's Review requested has pull requests asked of
/// a team of mine too ("Me and my teams"), not only of me by name.
final Pref<bool> githubTeamReviews = _plain('githubTeams', false);

/// The GitHub view's cards ("review", "mine", "assigned"): the order
/// they were dragged into (those it doesn't name go last), and those
/// collapsed.
final Pref<List<String>> githubCardOrder = _list('githubCards');
final Pref<Set<String>> githubCollapsed = _set('githubCollapsed');

/// The GitHub view's filters: only what changed in the last this many
/// days (0: any time; 90 at first), and by host the repositories
/// (owner/name) and owners hidden, and the owners it's limited to.
final githubDays = Pref<int>('githubDays', (v) => v is int && v >= 0 ? v : 90);
final Pref<Map<String, List<String>>> githubHidden = _places('githubHidden');
final Pref<Map<String, List<String>>> githubOwners = _places('githubOwners');

/// Whether the GitHub view's inbox is only the repositories of the folders
/// Nushi knows ("My folders' repositories"), not all.
final Pref<bool> githubKnownRepos = _plain('githubKnown', false);

/// Findings from review bots (Settings › GitHub; off at first): the merge
/// status card reads must-address findings out of these bots' reviews (logins,
/// comma-separated), the list items under a heading with any of
/// [githubFindingHeadings]' words (comma-separated, any case).
final Pref<bool> githubFindings = _plain('githubFindings', false);
final Pref<String> githubFindingBots = _plain(
  'githubFindingBots',
  'github-actions',
);
final Pref<String> githubFindingHeadings = _plain(
  'githubFindingHeadings',
  findingHeadingsDefault,
);
const findingHeadingsDefault = 'Key findings, Must address';

/// What reply cards ask the agent (Settings › GitHub), by kind (a
/// `CardAsk`'s name): the user's own words in place of that kind's
/// default. A kind not named here asks the default; `CardAsk.text` reads
/// it, and refuses what isn't plain text.
final Pref<Map<String, String>> cardAsks = Pref(
  'cardAsks',
  (v) => _entries(v, (s) => s is String ? s : null),
);

/// The merge method picked last, by host and repository (`host owner/name`):
/// it comes before what GitHub says the viewer used last, for as long as the
/// repository allows it.
final Pref<Map<String, String>> mergeMethods = Pref(
  'mergeMethods',
  (v) => _entries(v, (m) => m is String ? m : null),
);

/// The sidebar's project groups, by folder path: the order they were
/// dragged into (folders it doesn't name go first), and those collapsed;
/// with these, the other groupings' groups collapsed (`ChatGroup.key`,
/// such as `date:9today`) and the sections (`Section.key`).
final Pref<List<String>> sidebarOrder = _list('sidebarOrder');
final Pref<Set<String>> sidebarCollapsed = _set('sidebarCollapsed');

/// The sidebar's projects, by folder path, in the order they joined: each
/// folder an unarchived chat was in ([keepProject]). One stays with its
/// chats archived or deleted, an empty group whose + starts the next chat
/// there, until Remove from sidebar ([forgetProject]).
final Pref<Set<String>> sidebarProjects = _set('sidebarProjects');

/// Keeps [folder] among the sidebar's projects, if it isn't one yet;
/// never '', the chats with no folder, which aren't a project.
void keepProject(String folder) {
  if (folder.isEmpty || sidebarProjects.value.contains(folder)) return;
  sidebarProjects.value = {...sidebarProjects.value, folder};
}

/// Whether the sidebar has its project rail, while it's arranged by
/// project (Settings › Appearance's Project rail; ADR 0112): off at
/// first. Kept as `projectRailOn`: the beta that had the rail on at first
/// saved `projectRail` as true for everyone, touched or not, so that key
/// says nothing of what the user chose; it's ignored, and dropped by the
/// next save.
final Pref<bool> projectRail = _plain('projectRailOn', false);

/// The project the sidebar is narrowed to, by folder path: the tile
/// picked in the project rail; null for All projects. It counts only
/// while the rail shows (`shownProject`): with the rail off the sidebar
/// shows every project, whatever this says.
final Pref<String?> sidebarProject = _plain('sidebarProject', null);

/// What the user set for each project's tile (Change tile…), by folder
/// path: a project not named shows its repository's icon, or its
/// initials.
final projectTiles = Pref<Map<String, TileLook>>(
  'projectTiles',
  (v) => _entries(v, TileLook.read),
  write: (tiles) => {
    for (final MapEntry(:key, :value) in tiles.entries) key: value.toJson(),
  },
);

/// Gives [folder]'s tile [look]; an empty one puts it back as it is by
/// itself. The stored image it had, if [look] has another or none, is
/// deleted.
void setProjectTile(String folder, TileLook look) {
  _dropImage(projectTiles.value[folder], unless: look.image);
  projectTiles.value = {
    ...{...projectTiles.value}..remove(folder),
    if (!look.isEmpty) folder: look,
  };
}

/// Deletes [look]'s stored image, [unless] it's the one still wanted.
void _dropImage(TileLook? look, {String unless = ''}) {
  final image = look?.image ?? '';
  if (image.isEmpty || image == unless) return;
  dropTileImage(image);
  forgetPicture(image);
}

/// Takes [folder] out of the sidebar's projects, and with it its place
/// among them, its collapse, its chats' order, its own sort and its tile
/// (its stored image deleted); the sidebar
/// narrowed to it shows all again: one save.
void forgetProject(String folder) {
  if (sidebarProject.value == folder) sidebarProject.value = null;
  _dropImage(projectTiles.value[folder]);
  projectTiles.value = {...projectTiles.value}..remove(folder);
  sidebarProjects.value = {...sidebarProjects.value}..remove(folder);
  sidebarOrder.value = [...sidebarOrder.value.where((f) => f != folder)];
  sidebarCollapsed.value = {...sidebarCollapsed.value}..remove(folder);
  sidebarChats.value = {...sidebarChats.value}..remove(folder);
  if (projectSorts.value.containsKey(folder)) {
    projectSorts.value = {...projectSorts.value}..remove(folder);
  }
}

/// The order each project's chats were dragged into, by folder path
/// ('' for no folder): chat ids, those it doesn't name (new chats) going
/// first. A pinned chat keeps its place here while it's out of the list.
final sidebarChats = Pref<Map<String, List<String>>>(
  'sidebarChats',
  _byPlace,
  chats: (order) => order.values.expand((ids) => ids),
  without: (order, gone) => {
    for (final MapEntry(:key, :value) in order.entries)
      key: [...value.where((id) => !gone.contains(id))],
  },
);

/// Whether the sidebar is hidden; its width stays in [paneWidths].
final Pref<bool> sidebarHidden = _plain('sidebarHidden', false);

/// Whether the sidebar's Pinned section is collapsed.
final Pref<bool> pinnedCollapsed = _plain('pinnedCollapsed', false);

/// Whether Pinned shows the chats pinned in every project while the
/// sidebar is narrowed to one in the project rail (`shownProject`), each
/// of another project marked with its tile and name; off, only the shown
/// project's (Settings › Appearance's Pinned from every project). On at
/// first: a pin is there to be seen whatever is picked.
final Pref<bool> pinnedEveryProject = _plain('pinnedEveryProject', true);

/// The sidebar's arrangement, from its Arrange menu (`arrangement.dart`):
/// what it groups its chats by, how it sorts them and which way (the
/// newest first unless ascending), and what its rows show.
final sidebarGroupBy = Pref<GroupBy>(
  'sidebarGroupBy',
  (v) => GroupBy.values.asNameMap()[v] ?? GroupBy.project,
  write: (g) => g.name,
);
final sidebarSort = Pref<SortBy>(
  'sidebarSort',
  (v) => SortBy.values.asNameMap()[v] ?? SortBy.manual,
  write: (s) => s.name,
);
final Pref<bool> sidebarAscending = _plain('sidebarAscending', false);

/// Each project's own sort, by folder path ('' for no folder), from its
/// header's Sort button (ADR 0120): a project not named sorts as
/// [sidebarSort] and [sidebarAscending] say, the sidebar's, which stays
/// the default. Only while the sidebar is grouped by project.
final projectSorts = Pref<Map<String, ProjectSort>>(
  'projectSorts',
  (v) => _entries(v, ProjectSort.read),
  write: (sorts) => {
    for (final MapEntry(:key, :value) in sorts.entries) key: value.toJson(),
  },
);
final sidebarShows = Pref<Set<RowPart>>(
  'sidebarShows',
  (v) => v is List
      ? {for (final n in v) ?RowPart.values.asNameMap()[n]}
      : defaultRowParts,
  write: (parts) => [
    for (final p in parts) p.name,
    // What a newer app's rows show that this one doesn't know stays.
    if (_saved['sidebarShows'] case final List<Object?> saved)
      for (final n in saved)
        if (n is String && !RowPart.values.asNameMap().containsKey(n)) n,
  ],
);

/// The sidebar's sections of the user's own, in the order they were
/// dragged into, each with the chats moved into it (ADR 0089). A chat
/// deleted leaves its section.
final sidebarSections = Pref<List<Section>>(
  'sidebarSections',
  (v) => [
    if (v is List)
      for (final s in v) ?Section.read(s),
  ],
  write: (sections) => [for (final s in sections) s.toJson()],
  chats: (sections) => sections.expand((s) => s.chats),
  without: (sections, gone) => [
    for (final s in sections)
      s.copyWith(chats: [...s.chats.where((id) => !gone.contains(id))]),
  ],
);

/// The models picked from the model menu, by value, the last first: the
/// menu's first four are the ones used last.
final Pref<List<String>> recentModels = _list('models');

/// When each chat was last opened (milliseconds since the epoch), by chat
/// id: the palette lists chats the last opened first.
final Pref<Map<String, int>> chatOpened = _byChat(
  'opened',
  (v) => v is int ? v : null,
);

/// Each chat's pinned artifacts (as `chatFiles` names them), by chat id,
/// in the order pinned.
final Pref<Map<String, List<String>>> pinnedFiles = _byChat('pins', _strings);

/// The newest comment seen of each chat's pull request (ms since the
/// epoch), by chat id: newer ones are unread.
final Pref<Map<String, int>> pullSeen = _byChat(
  'pullSeen',
  (v) => v is num ? v.toInt() : null,
);

/// How many comments each chat's pull requests had when last seen, by chat
/// id and then by pull request's node id (ADR 0140): the PR widget counts
/// more since as new, from the rows' items rather than the pull request
/// read whole.
final Pref<Map<String, Map<String, int>>> pullSeenComments = _byChat(
  'pullSeenComments',
  (v) => v is Map
      ? {
          for (final MapEntry(:key, :value) in v.entries)
            if ((key, value) case (final String k, final num n)) k: n.toInt(),
        }
      : null,
);

/// The failures of each chat's pull requests' checks the user has acted
/// on (Ask to fix, Dismiss), by chat id, each as `<node id>@<commit>`
/// (ADR 0138): one of those doesn't need you again; a failure on another
/// commit does. A chat's entry starts with the failures there when it was
/// first seen.
final Pref<Map<String, List<String>>> checksSeen = _byChat(
  'checksSeen',
  _strings,
);

/// The pull request each chat's Pull request tab shows, picked among its
/// several (ADR 0117), as host/owner/repo#n.
final Pref<Map<String, String>> pickedPulls = _byChat(
  'pickedPulls',
  (v) => v is String ? v : null,
);

/// The chats whose PR widget no longer offers Clean up… (Not now); its
/// menu still has it.
final Pref<Set<String>> cleanUpLater = _set('cleanUpLater', chats: true);

/// The widths panes were dragged to, by pane (see `Resizable`). Not the
/// details panel's, which is fixed (ADR 0092): an older `details` width is
/// ignored, and dropped by the next save. The preview's, from when files
/// and browser tabs shared it, is the browser's (ADR 0094).
final paneWidths = Pref<Map<String, double>>(
  'panes',
  readPaneWidths,
  rewrite: true,
);

/// [paneWidths] as read from `app.json`'s [v].
@visibleForTesting
Map<String, double> readPaneWidths(Object? v) {
  final widths = _entries(v, (w) => w is num ? w.toDouble() : null)
    ..remove('details');
  final preview = widths.remove('preview');
  if (preview != null) widths.putIfAbsent('browser', () => preview);
  return widths;
}

/// Whether the chat takes the pane's whole width rather than a column in
/// its middle (ADR 0074).
final Pref<bool> chatFullWidth = _plain('chatFullWidth', false);

/// The terminal's font family (null: the bundled JetBrains Mono; a saved
/// value that can't be a family's name reads as that too) and size.
final terminalFont = Pref<String?>('termFont', _family);
final terminalFontSize = Pref<double>(
  'termSize',
  (v) => v is num ? v.toDouble() : 12.5,
);

/// The families the app's text and code are set in (Settings ›
/// Appearance's Fonts; ADR 0114): null is the bundled one (IBM Plex Sans,
/// JetBrains Mono). What's saved is anyone's text: only something that
/// can be a family's name ([isFamilyName]) is read, anything else as
/// null. The terminal keeps its own, above, read the same way.
final appFont = Pref<String?>('appFont', _family);
final codeFont = Pref<String?>('codeFont', _family);

String? _family(Object? saved) =>
    saved is String && isFamilyName(saved) ? saved : null;

/// The app's appearance (Settings › General, and View's items): light,
/// dark or as the system is.
final appearance = Pref<ThemeMode>(
  'appearance',
  (v) => ThemeMode.values.asNameMap()[v] ?? ThemeMode.system,
  write: (mode) => mode.name,
);

/// The color theme (Settings › General's Theme, ADR 0086): a built-in's
/// id, or `custom:` and a theme file's name; Nushi's unless picked.
final Pref<String> colorTheme = _plain('theme', 'nushi');

/// The app's notifications (`alerts.dart`), each kind on or off: a chat
/// needs you (a permission prompt or a question), a turn ends, a turn
/// fails; whether they play a sound; and the app icon's badge (the Dock's,
/// on the Mac) counting the chats that need you.
final Pref<bool> alertNeedsYou = _plain('alertNeedsYou', true);
final Pref<bool> alertFinished = _plain('alertFinished', true);
final Pref<bool> alertFailed = _plain('alertFailed', true);
final Pref<bool> alertSound = _plain('alertSound', false);
final Pref<bool> dockBadge = _plain('dockBadge', true);

/// Whether the Mac's composer checks spelling (ADR 0083): off, it asks
/// nothing and flags nothing.
final Pref<bool> checkSpelling = _plain('checkSpelling', true);

/// Whether Enter starts a line in the boxes that send to an agent or save
/// a reply, which then send with the command key held (off at first:
/// Enter sends; `isSendKey`, ADR 0147). The Mac's and Linux's: the phone's
/// Return always sends.
final Pref<bool> enterStartsLine = _plain('enterStartsLine', false);

/// Whether the plan pinned over the composer shows collapsed, its summary
/// line alone (ADR 0135); every chat's, the Mac's only (the phone's opens
/// collapsed).
final Pref<bool> planCollapsed = _plain('planCollapsed', false);

/// Whether a web link the user clicks in a chat (its messages, its tool
/// calls' output) to this Mac or the local network opens in a browser tab
/// beside it (on at first; ADR 0094), rather than in the default browser,
/// which has every other site; `openWebLink`.
final Pref<bool> linksInBrowserTab = _plain('linksInBrowserTab', true);

/// The sites (hosts, lowercase) whose pages in a browser tab may reach
/// this Mac and the local network (ADR 0094): none at first. Each is a
/// rule's exception (`localNetworkRules`); `allowLocalNetwork` and
/// `disallowLocalNetwork` change it.
final Pref<Set<String>> localNetworkSites = _set('localNetworkSites');

/// Whether a file's source in the preview wraps its long lines (on at
/// first); off, they run on and the view scrolls sideways. One for every
/// preview. The phone's button flips it too, in its own memory: a browser
/// has no `app.json`, so there it lasts until the page reloads.
final Pref<bool> wrapLines = _plain('wrap', true);

/// Whether a file's source in the preview, read-only or being edited,
/// marks its spaces (a dot) and tabs (an arrow) (off at first; ADR 0096).
/// Only drawn: the text is as it was.
final Pref<bool> showWhitespace = _plain('whitespace', false);

/// The span of days Settings › Usage shows (ADR 0136): the last 7 days
/// until another is picked.
final usageRange = Pref<UsageRange>(
  'usageRange',
  (v) => UsageRange.values.asNameMap()[v] ?? UsageRange.week,
  write: (r) => r.name,
);

/// The newer release whose toast was dismissed ("0.1.17"): it shows again
/// only for a newer one.
final Pref<String?> dismissedUpdate = _plain('dismissedUpdate', null);

/// The remote access reset last said in a toast, by its time (Unix ms;
/// 0 none): another reset is said again, this one never.
final Pref<int> remoteResetToasted = _plain('remoteResetToasted', 0);

/// The keys chosen in Settings › Keyboard shortcuts (ADR 0146), by
/// binding (an Act's name, or 'palette'), each in `shortcutText`'s words,
/// "" for none. A name or text this app can't read is ignored, and kept.
/// A binding on its default has no entry. Changed only by a fresh map.
final Pref<Map<String, String>> shortcutKeys = Pref(
  'shortcuts',
  (v) {
    _otherShortcuts = {
      if (v is Map)
        for (final MapEntry(:key, :value) in v.entries)
          if ((key, value) case (final String k, final Object? v)
              when v is! String)
            k: v,
    };
    return _entries(v, (s) => s is String ? s : null);
  },
  write: (keys) {
    _otherShortcuts = {
      for (final MapEntry(:key, :value) in _otherShortcuts.entries)
        if (!keys.containsKey(key)) key: value,
    };
    return {..._otherShortcuts, ...keys};
  },
);

/// `shortcuts`' entries in a shape this app doesn't read (a newer app's),
/// as last read: written back unchanged, until a key is chosen here for
/// that name, which replaces it for good (a later Reset is the default).
Map<String, Object?> _otherShortcuts = const {};

/// The prefs kept by chat, which [chatsKept] and [forgetChats] go through.
/// Named here rather than found among those made: a pref is made when
/// first read, and a chat gone is forgotten from those not read yet too.
List<Pref<Object?>> get _chatPrefs => [
  changeScopes,
  terminalChats,
  filesChats,
  fileTabsKept,
  sidebarChats,
  sidebarSections,
  chatOpened,
  pinnedFiles,
  pullSeen,
  pullSeenComments,
  checksSeen,
  pickedPulls,
  cleanUpLater,
];

/// The chats some pref keeps something for.
Set<String> chatsKept() => {for (final p in _chatPrefs) ...p.chats};

/// Forgets the chats [ids] (gone) in every pref kept by chat: one save.
void forgetChats(Set<String> ids) {
  for (final p in _chatPrefs) {
    p.forget(ids);
  }
}

/// One thing the app remembers in `app.json`, under [key]: read from
/// what was there at launch (`read` takes what's saved under the key, of
/// any type, or null, and gives the value: the default for nothing or a
/// wrong type, never an error), and saved with the others whenever it
/// changes (`write` gives what's saved; the value itself unless given).
/// Until it's changed, what was there is saved back as it was, so a value
/// a newer app wrote that this one reads as its default (a beta's
/// grouping, ADR 0108) isn't lost; one that [rewrite]s saves what it read
/// instead (an old part it drops goes with the next save).
/// One kept by chat says which chats it has something for (`chats`) and
/// how it goes without some (`without`).
final class Pref<T> extends ValueNotifier<T> {
  new(
    this.key,
    this._read, {
    this._write,
    this._chats,
    this._without,
    this.rewrite = false,
  }) : super(_read(_saved[key])) {
    _made.add(this);
    addListener(_changed);
  }

  /// Whether what was saved is rewritten as read, changed or not.
  final bool rewrite;

  /// Whether the value is no longer the one read at launch.
  bool _touched = false;

  final String key;
  final T Function(Object? saved) _read;
  final Object? Function(T value)? _write;
  final Iterable<String> Function(T value)? _chats;
  final T Function(T value, Set<String> gone)? _without;

  /// The chats this keeps something for (none unless it's kept by chat).
  Iterable<String> get chats => _chats?.call(value) ?? const [];

  /// Goes without what it keeps for the chats [ids], if anything.
  void forget(Set<String> ids) {
    if (_without case final without? when chats.any(ids.contains)) {
      value = without(value, ids);
    }
  }

  void _changed() {
    _touched = true;
    _saveSoon();
  }

  /// Whether it's saved as it was at launch: untouched, and there.
  bool get _asSaved => !_touched && !rewrite && _saved.containsKey(key);

  Object? get _saving => switch (_write) {
    final write? => write(value),
    null => value,
  };

  void _reset() {
    value = _read(_saved[key]);
    _touched = false;
  }

  /// Takes what a launch would read from [saved], `app.json` read whole
  /// ([readSaved]): a test's relaunch.
  @visibleForTesting
  void readFrom(Map<String, Object?> saved) => value = _read(saved[key]);
}

/// A set pref's toggle, for what's kept as a set of ids or names (the
/// collapsed groups and widgets, the chats with a terminal).
extension SetPrefToggle<T> on Pref<Set<T>> {
  /// Takes [x] out of the set if it's there, else puts it in.
  void toggle(T x) =>
      value = value.contains(x) ? ({...value}..remove(x)) : {...value, x};
}

/// The prefs made so far (read or set in this run), in that order.
final _made = <Pref<Object?>>[];

/// A plain JSON value: what's saved if it's a [T], else [or].
Pref<T> _plain<T>(String key, T or) => Pref(key, (v) => v is T ? v : or);

/// Strings in no order, saved as a list; [chats] when they're chat ids.
Pref<Set<String>> _set(String key, {bool chats = false}) => Pref(
  key,
  (v) => {..._strings(v) ?? const []},
  write: (s) => s.toList(),
  chats: chats ? (s) => s : null,
  without: chats ? (s, gone) => s.difference(gone) : null,
);

/// Strings in an order.
Pref<List<String>> _list(String key) => Pref(key, (v) => [...?_strings(v)]);

/// Strings by place (a site, a host, a folder…).
Pref<Map<String, List<String>>> _places(String key) => Pref(key, _byPlace);

/// Something for each chat, by chat id; [each] reads one (null: wrong).
Pref<Map<String, V>> _byChat<V extends Object>(
  String key,
  V? Function(Object? saved) each,
) => Pref(
  key,
  (v) => _entries(v, each),
  chats: (m) => m.keys,
  without: (m, gone) => {...m}..removeWhere((id, _) => gone.contains(id)),
);

/// [saved]'s strings, if it's a list.
List<String>? _strings(Object? saved) =>
    saved is List ? [...saved.whereType<String>()] : null;

/// [saved]'s entries that [each] reads, if it's a map.
Map<String, V> _entries<V extends Object>(
  Object? saved,
  V? Function(Object? saved) each,
) => {
  if (saved is Map)
    for (final MapEntry(:key, :value) in saved.entries)
      if ((key, each(value)) case (final String k, final V v)) k: v,
};

Map<String, List<String>> _byPlace(Object? saved) => _entries(saved, _strings);

File get _settings => File('$dataDir/app.json');

/// `app.json` as it was at launch, read by [readKept] (one that didn't
/// parse was set aside, and reads as none); null when it couldn't be read
/// at all, and then nothing is saved over it in this run.
final Kept? _launch = _readLaunch();

Kept? _readLaunch() {
  try {
    return readKept(_settings);
  } on Object catch (e) {
    appLog.warn("app.json can't be read, so it isn't written over", {
      'err': '$e',
    });
    return null;
  }
}

/// `app.json` as it was at launch.
final Map<String, Object?> _saved = _launch?.json ?? {};

/// `app.json` as it is on disk now; empty when it can't be read.
Map<String, Object?> readSaved() {
  try {
    return jsonDecode(_settings.readAsStringSync()) as Map<String, Object?>;
  } on Object {
    return <String, Object?>{};
  }
}

/// Keys an older app saved that mean nothing now, dropped by the next
/// save: `worktrees` (new chats no longer remember one), `subagentWide`
/// (a subagent's pane is dragged as wide as it's wanted) and `projectRail`
/// (a beta's, true for everyone; [projectRail] is `projectRailOn`).
const _dropped = {'worktrees', 'subagentWide', 'projectRail'};

var _saveDue = false;

/// Saves once the changes made meanwhile are in (a chat forgotten from
/// several prefs, or a test's setup, is one write).
void _saveSoon() {
  if (_saveDue) return;
  _saveDue = true;
  scheduleMicrotask(() {
    _saveDue = false;
    _save();
  });
}

/// Writes the prefs made over `app.json` as it was at launch: those not
/// read in this run, and keys a newer app saved, stay as they were. One
/// that couldn't be read isn't written over: the prefs changed apply
/// until the app quits.
void _save() {
  if (_launch == null) return;
  try {
    writeWhole(
      _settings,
      utf8.encode(
        jsonEncode({
          for (final MapEntry(:key, :value) in _saved.entries)
            if (!_dropped.contains(key)) key: value,
          for (final p in _made)
            if (!p._asSaved) p.key: p._saving,
        }),
      ),
    );
  } on Object {
    // Not remembered; it still applies until the app quits.
  }
}

/// Every pref as it was at launch (a test process's: as its data folder's
/// `app.json` had it, none unless a test wrote one before reading), and
/// the file on disk too, so no test sees another's, in memory or saved.
@visibleForTesting
void resetAppSettings() {
  _saveDue = false; // a test's pending save may never have run
  for (final p in _made) {
    p._reset();
  }
  try {
    if (_launch == null) {
      // Left as it is: it couldn't be read.
    } else if (_saved.isNotEmpty) {
      writeWhole(_settings, utf8.encode(jsonEncode(_saved)));
    } else if (_settings.existsSync()) {
      _settings.deleteSync();
    }
  } on Object {
    // A test that reads the file would fail on what's left.
  }
}
