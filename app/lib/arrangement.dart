import 'package:nushi/agents.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/status.dart';

// How the sidebar arranges its chats (its Arrange menu): what it groups
// them by, how it sorts them, what each row shows, and the sections of
// the user's own. The choices, and grouping and sorting chats by them;
// the prefs that keep them are `settings.dart`'s, the sidebar arranged
// by them `sidebar_view.dart`'s, and the widgets that show them apart.

/// What the sidebar groups its chats by. [project] is the default: a
/// folder's chats under it, in the order they were dragged into.
enum GroupBy {
  project('Project'),
  date('Date'),
  status('Status'),
  agent('Agent'),
  worktree('Worktree'),
  none('None');

  new(this.label);

  final String label;
}

/// How the sidebar sorts its chats. [manual] is the default: as they were
/// dragged, a new one first; only Project grouping has an order of the
/// user's ([effectiveSort]).
enum SortBy {
  manual('Manual'),
  updated('Last updated'),
  created('Date created'),
  name('Name');

  new(this.label);

  final String label;

  /// Its two ways, descending first: "Newest first" and "Oldest first",
  /// or for [name] "Z to A" and "A to Z".
  (String, String) get ways =>
      this == name ? ('Z to A', 'A to Z') : ('Newest first', 'Oldest first');

  /// The way it's usually wanted: the newest first, names from A.
  bool get naturallyAscending => this == name;
}

/// What a sidebar row can show besides its title: its state's dot, its
/// agent's mark, its branch (or Jira key), its project's name where its
/// group doesn't say it (Pinned, a section, a grouping other than
/// Project), and how long ago it was updated or made.
enum RowPart {
  status('Status'),
  agent('Agent'),
  branch('Branch'),
  project('Project'),
  time('Time');

  new(this.label);

  final String label;
}

/// What rows show unless picked otherwise: all but the time.
const Set<RowPart> defaultRowParts = {
  RowPart.status,
  RowPart.agent,
  RowPart.branch,
  RowPart.project,
};

/// A section of the user's own in the sidebar: a [name], the [chats] moved
/// into it (ids, the last moved in first: the order they're in when the
/// sort is Manual), and whether it's [collapsed]. Kept in the Mac's
/// `app.json` (ADR 0089).
class Section {
  const new({
    required this.id,
    required this.name,
    this.chats = const [],
    this.collapsed = false,
  });

  /// [saved] as `app.json` has it; null when it isn't one.
  static Section? read(Object? saved) {
    if (saved case {'id': final String id, 'name': final String name}) {
      final chats = saved['chats'];
      return Section(
        id: id,
        name: name,
        chats: [if (chats is List) ...chats.whereType<String>()],
        collapsed: saved['collapsed'] == true,
      );
    }
    return null;
  }

  final String id;
  final String name;
  final List<String> chats;
  final bool collapsed;

  /// The key its collapse and its drag go by, apart from any folder's.
  String get key => 'section:$id';

  Section copyWith({String? name, List<String>? chats, bool? collapsed}) =>
      Section(
        id: id,
        name: name ?? this.name,
        chats: chats ?? this.chats,
        collapsed: collapsed ?? this.collapsed,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'chats': chats,
    if (collapsed) 'collapsed': true,
  };
}

/// The sort that applies under [group]: [SortBy.manual] only orders a
/// project's chats; under another grouping it reads as Date created.
SortBy effectiveSort(GroupBy group, SortBy sort) =>
    sort == SortBy.manual && group != GroupBy.project ? SortBy.created : sort;

/// Whether chats are dragged into an order of their own: Project grouping,
/// sorted by hand. Elsewhere a drag only moves a chat into a section.
bool dragsOrder(GroupBy group, SortBy sort) =>
    group == GroupBy.project && sort == SortBy.manual;

/// The time a chat goes by under [sort]: when it was made for Date
/// created, else when it was last updated.
DateTime chatTime(ChatState c, SortBy sort) =>
    sort == SortBy.created ? c.created : c.updated;

/// [chats] in [sort]'s order ([SortBy.manual] keeps theirs); the newest
/// or Z first unless [ascending]. Ties go by when they were made, the
/// newest first, so the order is stable.
List<ChatState> sortChats(
  Iterable<ChatState> chats,
  SortBy sort, {
  required bool ascending,
}) {
  final list = [...chats];
  if (sort == SortBy.manual) return list;
  int by(ChatState a, ChatState b) => switch (sort) {
    SortBy.name => a.shownTitle.toLowerCase().compareTo(
      b.shownTitle.toLowerCase(),
    ),
    _ => chatTime(a, sort).compareTo(chatTime(b, sort)),
  };
  return list..sort((a, b) {
    final c = ascending ? by(a, b) : by(b, a);
    return c != 0 ? c : b.created.compareTo(a.created);
  });
}

/// One of the sidebar's groups under a grouping other than Project: its
/// [key] (where its collapse is kept, `<grouping>:<what>`), its [label]
/// ('' for None's one group, which has no header), the [agent] whose mark
/// its header shows (Agent grouping), and its chats.
class ChatGroup {
  const new(this.key, this.label, this.chats, {this.agent = ''});

  final String key;
  final String label;
  final String agent;
  final List<ChatState> chats;
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The Date group [t] falls in at [now]: Today, Yesterday, Previous 7
/// days, Previous 30 days, then its month ("October", or "October 2025"
/// before this year). Its key sorts the groups, the newest first when
/// compared backward. Calendar days, so a clock change doesn't move one.
(String key, String label) dateGroup(DateTime t, DateTime now) {
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(t.year, t.month, t.day)).inDays;
  return switch (days) {
    <= 0 => ('date:9today', 'Today'),
    1 => ('date:8yesterday', 'Yesterday'),
    < 7 => ('date:7week', 'Previous 7 days'),
    < 30 => ('date:6month', 'Previous 30 days'),
    _ => (
      'date:${t.year}-${t.month.toString().padLeft(2, '0')}',
      t.year == now.year
          ? _months[t.month - 1]
          : '${_months[t.month - 1]} ${t.year}',
    ),
  };
}

/// [chats] in the groups of [group] (any but [GroupBy.project]), each
/// sorted by [sort]: Date's groups the newest first (the oldest with
/// [ascending] and a time sort), Status's in the order of [ChatPhase]
/// (what needs you first), Agent's by the agent's name, Worktree's those
/// in one first, None's one group.
List<ChatGroup> groupChats(
  Iterable<ChatState> chats,
  GroupBy group,
  SortBy sort, {
  required bool ascending,
  required DateTime now,
}) {
  final sorted = sortChats(chats, sort, ascending: ascending);
  final byKey =
      <String, ({String label, String agent, List<ChatState> chats})>{};
  for (final c in sorted) {
    final (key, label, agent) = switch (group) {
      GroupBy.date => (
        dateGroup(chatTime(c, sort), now).$1,
        dateGroup(chatTime(c, sort), now).$2,
        '',
      ),
      GroupBy.status => (
        'status:${c.phase.index.toString().padLeft(2, '0')}',
        _capital(phaseName(c.phase)),
        '',
      ),
      GroupBy.agent => ('agent:${c.agent}', agentTitle(c.agent), c.agent),
      GroupBy.worktree =>
        c.worktree != null
            ? ('worktree:1', 'In a worktree', '')
            : ('worktree:2', 'Not in a worktree', ''),
      GroupBy.none || GroupBy.project => ('none', '', ''),
    };
    (byKey[key] ??= (label: label, agent: agent, chats: [])).chats.add(c);
  }
  final keys = byKey.keys.toList();
  switch (group) {
    case GroupBy.date:
      // The newest first, unless a time sort goes the other way.
      final up = ascending && sort != SortBy.name;
      keys.sort((a, b) => up ? a.compareTo(b) : b.compareTo(a));
    case GroupBy.agent:
      keys.sort((a, b) => byKey[a]!.label.compareTo(byKey[b]!.label));
    case _:
      keys.sort();
  }
  return [
    for (final k in keys)
      ChatGroup(k, byKey[k]!.label, byKey[k]!.chats, agent: byKey[k]!.agent),
  ];
}

String _capital(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
