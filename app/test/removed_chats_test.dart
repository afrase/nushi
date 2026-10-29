import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/removed_chats.dart';

import 'fake_daemon.dart';
import 'harness.dart';

RemovedChat _removed(String id, String title, {String agent = 'claude'}) =>
    RemovedChat(
      id: id,
      agent: agent,
      title: title,
      folder: '/Users/me/nushi',
      removedUnixMs: Int64(1),
    );

final List<RemovedChat> _three = [
  _removed('a', 'Fix the login redirect'),
  _removed('b', 'Sidebar spacing'),
  _removed('c', ''),
];

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  test('the bar names the chats, and why when one agent deleted them', () {
    expect(
      RemovedChatsBar.text([_three.first]),
      'Removed “Fix the login redirect”: Claude no longer had its session '
      '(Claude Code deletes sessions after 30 days by default).',
    );
    expect(
      RemovedChatsBar.text(_three),
      'Removed 3 chats whose sessions Claude deleted (Claude Code deletes '
      'sessions after 30 days by default): “Fix the login redirect”, '
      '“Sidebar spacing”, “Untitled chat”.',
    );
    expect(
      RemovedChatsBar.text([
        _three.first,
        _removed('d', 'Rename the flag', agent: 'codex'),
      ]),
      'Removed 2 chats whose sessions their agents deleted: '
      '“Fix the login redirect” (Claude), “Rename the flag” (Codex).',
    );
  });

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets('the window says once which chats went; OK dismisses '
        'it ($name)', (tester) async {
      viewport(tester, const Size(900, 500), brightness: brightness);
      final chats = [chat('k', 'claude', 'Still here')];
      final fake = FakeDaemon(chats)
        ..answer = (input) => input is ListChatsRequest
            ? ListChatsResponse(chats: chats, removed: _three)
            : null;
      final d = await fake.connect(tester);
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      expect(find.byType(RemovedChatsBar), findsOneWidget);
      await expectLater(
        find.byType(RemovedChatsBar),
        matchesGoldenFile('goldens/removed_chats_$name.png'),
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(RemovedChatsBar), findsNothing);
      final dismissed = fake.calls.whereType<DismissRemovedChatsRequest>();
      expect(dismissed.single.ids, ['a', 'b', 'c']);

      // One removed while the app is open shows at once.
      fake.emit(
        EventsResponse(
          removedChats: RemovedChats(chats: [_removed('k', 'Still here')]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Removed “Still here”'), findsOneWidget);
      d.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }
}
