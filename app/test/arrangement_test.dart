import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'harness.dart';

// The sidebar's groups as pure functions: the Date group a time falls in,
// and the groups each grouping makes, in their order. The sidebar's own
// tests (sidebar_arrange_test, sidebar_test) check them as drawn.

/// A chat made [made] and last updated [updated] before [fixtureNow].
ChatState _chat(
  String id, {
  required Duration made,
  Duration? updated,
  String agent = 'claude',
  bool busy = false,
  bool waiting = false,
  bool worktree = false,
}) => ChatState(id, '/Users/me/nushi')
  ..title = id
  ..agent = agent
  ..busy = busy
  ..waiting = waiting
  ..worktree = worktree ? Worktree(path: '/Users/me/wt/$id') : null
  ..created = fixtureNow.subtract(made)
  ..updated = fixtureNow.subtract(updated ?? made);

/// Each group's label and its chats' ids, in order, as lists (a record
/// of a list compares the list by identity).
List<List<Object>> _shown(List<ChatGroup> groups) => [
  for (final g in groups) [g.label, for (final c in g.chats) c.id],
];

/// [want]'s groups as [_shown] gives them.
List<List<Object>> _groups(List<(String, List<String>)> want) => [
  for (final (label, ids) in want) [label, ...ids],
];

void main() {
  test('dateGroup: each boundary, the future, and past years', () {
    // fixtureNow is noon on Thursday 29 October 2026.
    for (final (at, key, label) in [
      (fixtureNow.add(const Duration(days: 2)), 'date:9today', 'Today'),
      (fixtureNow, 'date:9today', 'Today'),
      (DateTime(2026, 10, 29), 'date:9today', 'Today'),
      (DateTime(2026, 10, 28, 23, 59), 'date:8yesterday', 'Yesterday'),
      (DateTime(2026, 10, 28), 'date:8yesterday', 'Yesterday'),
      (DateTime(2026, 10, 27, 23, 59), 'date:7week', 'Previous 7 days'),
      (DateTime(2026, 10, 23), 'date:7week', 'Previous 7 days'),
      (DateTime(2026, 10, 22, 23), 'date:6month', 'Previous 30 days'),
      (DateTime(2026, 9, 30), 'date:6month', 'Previous 30 days'),
      (DateTime(2026, 9, 29, 23), 'date:2026-09', 'September'),
      (DateTime(2026, 1, 3), 'date:2026-01', 'January'),
      (DateTime(2025, 12, 31), 'date:2025-12', 'December 2025'),
      (DateTime(2019, 10, 29), 'date:2019-10', 'October 2019'),
    ]) {
      expect(dateGroup(at, fixtureNow), (key, label), reason: '$at');
    }
  });

  test('dateGroup: calendar days, so any time of a day is in its group', () {
    for (final now in [DateTime(2026, 10, 29), DateTime(2026, 10, 29, 23)]) {
      expect(dateGroup(DateTime(2026, 10, 28, 23, 59), now).$2, 'Yesterday');
      expect(dateGroup(DateTime(2026, 10, 28), now).$2, 'Yesterday');
      expect(dateGroup(DateTime(2026, 10, 22, 23), now).$2, 'Previous 30 days');
    }
  });

  // Made today, two days ago and two months ago; b was updated today.
  final chats = [
    _chat('a', made: const Duration(hours: 1)),
    _chat('b', made: const Duration(days: 2), updated: Duration.zero),
    _chat('c', made: const Duration(days: 60)),
  ];

  test('groupChats by Date: each sort, either way', () {
    for (final (sort, ascending, want) in [
      (
        SortBy.created,
        false,
        [
          ('Today', ['a']),
          ('Previous 7 days', ['b']),
          ('August', ['c']),
        ],
      ),
      // A time sort oldest first turns the groups over too.
      (
        SortBy.created,
        true,
        [
          ('August', ['c']),
          ('Previous 7 days', ['b']),
          ('Today', ['a']),
        ],
      ),
      // By last updated, b is today's, after a (updated at fixtureNow).
      (
        SortBy.updated,
        false,
        [
          ('Today', ['b', 'a']),
          ('August', ['c']),
        ],
      ),
      (
        SortBy.updated,
        true,
        [
          ('August', ['c']),
          ('Today', ['a', 'b']),
        ],
      ),
    ]) {
      expect(
        _shown(
          groupChats(
            chats,
            GroupBy.date,
            sort,
            ascending: ascending,
            now: fixtureNow,
          ),
        ),
        _groups(want),
        reason: '${sort.name}, ascending $ascending',
      );
    }
  });

  test('groupChats by Date under Name: the groups stay newest first, '
      'their rows A to Z either way', () {
    final named = [
      _chat('zed', made: const Duration(hours: 2)),
      _chat('amy', made: const Duration(hours: 1)),
      _chat('old', made: const Duration(days: 60)),
    ];
    for (final (ascending, today) in [
      (true, ['amy', 'zed']),
      (false, ['zed', 'amy']),
    ]) {
      expect(
        _shown(
          groupChats(
            named,
            GroupBy.date,
            SortBy.name,
            ascending: ascending,
            now: fixtureNow,
          ),
        ),
        _groups([
          ('Today', today),
          ('August', ['old']),
        ]),
        reason: 'ascending $ascending',
      );
    }
  });

  test('groupChats by Status, Agent, Worktree and None', () {
    final mixed = [
      _chat('idle', made: const Duration(hours: 4)),
      _chat('asks', made: const Duration(hours: 3), waiting: true),
      _chat(
        'runs',
        made: const Duration(hours: 2),
        busy: true,
        agent: 'codex',
        worktree: true,
      ),
      _chat('ante', made: const Duration(hours: 1), agent: 'ante'),
    ];
    for (final (group, want) in [
      // What needs you first: ChatPhase's order.
      (
        GroupBy.status,
        [
          ('Needs you', ['asks']),
          ('Working', ['runs']),
          ('Idle', ['ante', 'idle']),
        ],
      ),
      (
        GroupBy.agent,
        (<(String, List<String>)>[
          (agentTitle('ante'), ['ante']),
          (agentTitle('claude'), ['asks', 'idle']),
          (agentTitle('codex'), ['runs']),
        ]..sort((a, b) => a.$1.compareTo(b.$1))),
      ),
      (
        GroupBy.worktree,
        [
          ('In a worktree', ['runs']),
          ('Not in a worktree', ['ante', 'asks', 'idle']),
        ],
      ),
      (
        GroupBy.none,
        [
          ('', ['ante', 'runs', 'asks', 'idle']),
        ],
      ),
    ]) {
      expect(
        _shown(
          groupChats(
            mixed,
            group,
            SortBy.created,
            ascending: false,
            now: fixtureNow,
          ),
        ),
        _groups(want),
        reason: group.name,
      );
    }
  });
}
