// A long chat's files reach past its loaded part (issue #62): the daemon
// says what the items before the recent part wrote, and the app goes over
// what it has after them.
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';
import 'harness.dart';

Item _call(String id, String path, {String kind = 'edit'}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: kind,
  title: kind,
  status: 'completed',
  paths: [path],
);

Item _user(String id) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Go on.');

/// What the daemon says the items before the recent part wrote, the one
/// changed last first.
const _older = [
  'docs/plan.md',
  'internal/api/api.go',
  'notes/old.md',
  '/Users/me/elsewhere/chart.png',
];

/// The recent part: it deletes one of the older files, writes another
/// again, and writes one of its own.
final List<Item> _recent = [
  _user('u'),
  _call('del', 'notes/old.md', kind: 'delete'),
  _call('w1', 'docs/new.md'),
  _call('w2', '/Users/me/nushi/docs/plan.md'),
];

GetChatResponse _snapshot() => GetChatResponse(
  items: _recent,
  older: 40,
  olderWritten: _older,
  seq: Int64(1),
);

void main() {
  test("a long chat's artifacts and written files reach past what's loaded; "
      'what the loaded part wrote or deleted since comes first or goes', () {
    final chat = ChatState('c', '/Users/me/nushi')..load(_snapshot());
    expect(chatFilesOf(chat), [
      'docs/plan.md',
      'docs/new.md',
      '/Users/me/elsewhere/chart.png',
    ]);
    expect(chatWrote(chat), {
      'docs/plan.md',
      'docs/new.md',
      'internal/api/api.go',
      '/Users/me/elsewhere/chart.png',
    });
    // An older page loaded changes nothing: its items are in the list.
    chat.prepend([_call('p', 'notes/old.md'), _call('q', 'docs/plan.md')], 38);
    expect(chatFilesOf(chat), [
      'docs/plan.md',
      'docs/new.md',
      '/Users/me/elsewhere/chart.png',
    ]);
  });

  test('items let go of from the top stay among what the chat wrote', () {
    final chat = ChatState('c', '/Users/me/nushi')..load(_snapshot());
    final before = chatFilesOf(chat);
    expect(chat.trim(1), isTrue);
    expect(chat.items.map((it) => it.id), ['w2']);
    expect(chatFilesOf(chat), before);
    expect(chatWrote(chat), contains('docs/new.md'));
  });

  test('a rewind inside an older page that loaded asks for a fresh '
      'snapshot, whose list leaves out what was cut', () async {
    var asked = 0;
    final chat = ChatState('c', '/Users/me/nushi')
      ..load(
        GetChatResponse(
          items: [_user('u2')],
          older: 3,
          olderWritten: ['cut.md'],
          seq: Int64(1),
        ),
      )
      ..stale = (() => asked++)
      ..prepend([_user('u0'), _user('u1'), _call('e', 'cut.md')], 0)
      ..apply(EventsResponse(chatId: 'c', seq: Int64(2), cut: 'u1'));
    await Future<void>.delayed(Duration.zero);
    expect(chat.items.map((it) => it.id), ['u0']);
    expect(asked, 1);
    // Inside the snapshot's own recent part: its list holds nothing cut.
    final recent = ChatState('c', '/Users/me/nushi')
      ..load(_snapshot())
      ..stale = (() => asked++)
      ..prepend([_user('p')], 39)
      ..apply(EventsResponse(chatId: 'c', seq: Int64(2), cut: 'w1'));
    await Future<void>.delayed(Duration.zero);
    expect(recent.items.map((it) => it.id), ['p', 'u', 'del']);
    expect(asked, 1);
  });

  test('a move names what the older items wrote as the daemon does, '
      'relative to the old folder no longer', () {
    final chat = ChatState('c', '/w/old')
      ..load(
        GetChatResponse(
          items: [_user('u')],
          older: 40,
          olderWritten: ['docs/report.md', '/elsewhere/a.png'],
          seq: Int64(1),
        ),
      )
      ..moved('/w/new');
    expect(chatWrote(chat), {'/w/old/docs/report.md', '/elsewhere/a.png'});
    chat.prepend([_call('e', '/w/old/docs/report.md')], 39);
    expect(chatWrote(chat), {'/w/old/docs/report.md', '/elsewhere/a.png'});
  });

  test('from a daemon before olderWrittenApi only the loaded part counts, '
      'as before', () {
    final chat = ChatState('c', '/Users/me/nushi')
      ..load(_snapshot(), written: false);
    expect(chatFilesOf(chat), ['docs/plan.md', 'docs/new.md']);
    expect(chat.trim(1), isTrue);
    expect(chatFilesOf(chat), ['docs/plan.md']);
  });

  for (final (api, want) in [(olderWrittenApi, 3), (olderWrittenApi - 1, 2)]) {
    testWidgets('the app opens a long chat with what its older items wrote '
        'from API $api', (tester) async {
      final fake = FakeDaemon([chat('c', 'claude', 'A long chat')])
        ..on(
          (input) => switch (input) {
            PingRequest() => PingResponse(apiVersion: api),
            GetChatRequest() =>
              _snapshot()..chat = chat('c', 'claude', 'A long chat'),
            _ => null,
          },
        );
      final d = await openApp(tester, fake);
      expect(
        chatArtifacts(d.chats['c']!).recent.length +
            chatArtifacts(d.chats['c']!).older.length,
        want,
      );
      await closeView(tester, d);
    }, variant: onMac);
  }
}
