import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'sidebar_fixture.dart';

// The Archived section's order (issue #48): under the default sort the
// latest archived first, those archived before the daemon kept the time
// after them as before (the newest made first); a sort the user picked
// wins there too.

/// An archived chat made [made] minutes before noon and archived [archived]
/// minutes before it (null: before the daemon kept the time).
ChatState _archived(String id, {required int made, int? archived}) =>
    ChatState(id, '/Users/me/nushi')
      ..title = id
      ..archived = true
      ..created = fixtureNow.subtract(Duration(minutes: made))
      ..updated = fixtureNow.subtract(Duration(minutes: made))
      ..archivedAt = archived == null
          ? null
          : fixtureNow.subtract(Duration(minutes: archived));

List<String> _ids(List<ChatState> chats) => [for (final c in chats) c.id];

/// The same as a daemon's chat, for the sidebar.
Chat _chat(String title, {required int made, int? archived}) =>
    chat(title.toLowerCase(), 'claude', title, age: made)
      ..archived = true
      ..archivedUnixMs = archived == null
          ? Int64()
          : Int64(
              fixtureNow
                  .subtract(Duration(minutes: archived))
                  .millisecondsSinceEpoch,
            );

void main() {
  setUpAll(loadFonts);

  test('with times, the latest archived first', () {
    final chats = [
      _archived('a', made: 1, archived: 30),
      _archived('b', made: 2, archived: 5),
      _archived('c', made: 3, archived: 60),
    ];
    expect(_ids(sortArchived(chats, SortBy.manual, ascending: false)), [
      'b',
      'a',
      'c',
    ]);
  });

  test('without times, the newest made first, as before', () {
    final chats = [
      _archived('a', made: 3),
      _archived('b', made: 1),
      _archived('c', made: 2),
    ];
    expect(_ids(sortArchived(chats, SortBy.manual, ascending: false)), [
      'b',
      'c',
      'a',
    ]);
  });

  test('mixed, those with a time first', () {
    final chats = [
      _archived('old-new', made: 1),
      _archived('timed-early', made: 9, archived: 50),
      _archived('old-old', made: 8),
      _archived('timed-late', made: 7, archived: 2),
    ];
    expect(_ids(sortArchived(chats, SortBy.manual, ascending: false)), [
      'timed-late',
      'timed-early',
      'old-new',
      'old-old',
    ]);
  });

  test('a sort the user picked wins', () {
    final chats = [
      _archived('b', made: 1, archived: 50),
      _archived('a', made: 3, archived: 2),
      _archived('c', made: 2),
    ];
    expect(_ids(sortArchived(chats, SortBy.created, ascending: false)), [
      'b',
      'c',
      'a',
    ]);
    expect(_ids(sortArchived(chats, SortBy.name, ascending: true)), [
      'a',
      'b',
      'c',
    ]);
  });

  testWidgets('the sidebar lists the latest archived first, unless a sort '
      'was picked', (tester) async {
    const titles = ['Old notes', 'Put away', 'Just shelved', 'Live one'];
    final (d, _) = await arrangedSidebar(
      tester,
      chats: [
        chat('live', 'claude', 'Live one'),
        _chat('Old notes', made: 1),
        _chat('Put away', made: 2, archived: 40),
        _chat('Just shelved', made: 3, archived: 1),
      ],
    );
    await tester.tap(find.text('Archived  3'));
    await tester.pumpAndSettle();
    expect(shownInOrder(tester, titles), [
      'Live one',
      'Just shelved',
      'Put away',
      'Old notes',
    ]);

    sidebarSort.value = SortBy.created;
    await tester.pumpAndSettle();
    expect(shownInOrder(tester, titles), [
      'Live one',
      'Old notes',
      'Put away',
      'Just shelved',
    ]);
    d.dispose();
  });
}
