import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_changes.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/marks_base.dart';

import 'fake_daemon.dart';

// A chat's folder has one owner (ChatChanges): one read serves its details,
// its Changes and its change marks, and a change to the folder reads it
// again only while something shows it.

void main() {
  test('one read serves every view; a turn ends unfollowed and it waits '
      'for the next to follow it, which reads again', () async {
    final fake = FakeDaemon([Chat(id: 'c', agent: 'claude', folder: '/x')])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'fix',
          defaultBase: 'main',
        ),
        ListBranchesRequest() => ListBranchesResponse(),
        _ => null,
      };
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    await pumpEventQueue();
    int statuses() => fake.calls.whereType<GetFolderStatusRequest>().length;
    final chat = ChatState('c', '/x');
    final changes = ChatChanges.of(d, chat);
    expect(ChatChanges.of(d, chat), same(changes));

    changes.follow();
    // The marks ask while the read is under way: they take it.
    final base = marksBaseOf(chat).find(d);
    await pumpEventQueue();
    expect(changes.span?.status.branch, 'fix');
    expect(changes.branches, isNotNull);
    expect(await base, (base: 'main', from: MarksFrom.branch));
    expect(statuses(), 1);

    // A second view of it: what it has, no read.
    changes.follow();
    await pumpEventQueue();
    expect(statuses(), 1);

    // A turn ends while followed: one read.
    var told = 0;
    marksBaseOf(chat).addListener(() => told++);
    chat
      ..busy = true
      ..notifyListeners()
      ..busy = false
      ..notifyListeners();
    await pumpEventQueue();
    expect(statuses(), 2);
    expect(told, 1, reason: 'the marks look again');

    // Nothing shows it: a turn's end only marks it behind.
    changes
      ..unfollow()
      ..unfollow();
    chat
      ..busy = true
      ..notifyListeners()
      ..busy = false
      ..notifyListeners();
    await pumpEventQueue();
    expect(statuses(), 2);
    expect(changes.span?.status.branch, 'fix', reason: 'kept meanwhile');
    changes.follow();
    await pumpEventQueue();
    expect(statuses(), 3);
    changes.unfollow();
  });

  test('shown again, it shows what it had at once and reads again: a '
      'sibling chat or a terminal may have changed the folder', () async {
    var files = 3;
    final fake = FakeDaemon([Chat(id: 'c', agent: 'claude', folder: '/x')])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'fix',
          files: files,
        ),
        ListBranchesRequest() => ListBranchesResponse(),
        _ => null,
      };
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    await pumpEventQueue();
    int statuses() => fake.calls.whereType<GetFolderStatusRequest>().length;
    final chat = ChatState('c', '/x');
    final changes = ChatChanges.of(d, chat)..follow();
    await pumpEventQueue();
    expect(changes.span?.status.files, 3);
    changes.unfollow();

    // Another chat in /x, or an editor, changed it meanwhile.
    files = 7;
    changes.follow();
    expect(changes.span?.status.files, 3, reason: 'what it had, at once');
    await pumpEventQueue();
    expect(statuses(), 2);
    expect(changes.span?.status.files, 7);
    changes.unfollow();
  });

  test('the marks alone read no branches, which only a view of them '
      'lists', () async {
    final fake = FakeDaemon([Chat(id: 'c', agent: 'claude', folder: '/x')])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'fix',
          defaultBase: 'main',
        ),
        ListBranchesRequest() => ListBranchesResponse(),
        _ => null,
      };
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    await pumpEventQueue();
    int lists() => fake.calls.whereType<ListBranchesRequest>().length;
    final chat = ChatState('c', '/x');
    expect(await marksBaseOf(chat).find(d), (
      base: 'main',
      from: MarksFrom.branch,
    ));
    expect(lists(), 0);
    final changes = ChatChanges.of(d, chat)..follow();
    await pumpEventQueue();
    expect(lists(), 1);
    expect(changes.branches, isNotNull);
    changes.unfollow();

    // Shown while the marks' read is under way: that read is taken, and
    // the branches listed beside it.
    final other = ChatState('o', '/x');
    final finding = marksBaseOf(other).find(d);
    final view = ChatChanges.of(d, other)..follow();
    await finding;
    await pumpEventQueue();
    expect(lists(), 2);
    expect(view.branches, isNotNull);
    view.unfollow();
  });

  test('a read that fails says why, and the next that answers clears it; '
      'the newest read asked for is what shows', () async {
    var fail = true;
    var branch = 'one';
    final fake = FakeDaemon([Chat(id: 'c', agent: 'claude', folder: '/x')])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() when fail => throw Exception('no folder'),
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: branch,
        ),
        _ => null,
      };
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    await pumpEventQueue();
    final chat = ChatState('c', '/x');
    final changes = ChatChanges.of(d, chat)..follow();
    await pumpEventQueue();
    expect(changes.known, isTrue);
    expect(changes.error, contains('no folder'));
    fail = false;
    final first = changes.reload();
    branch = 'two';
    final second = changes.reload();
    await Future.wait([first, second]);
    expect(changes.error, isNull);
    expect(changes.span?.status.branch, 'two');
    changes.unfollow();
  });
}
