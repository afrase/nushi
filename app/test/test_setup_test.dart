import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/daemon.dart' show dataDir;
import 'package:nushi/gen/nushi/v1/nushi.connect.spec.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/native.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'fake_desktop.dart';
import 'flutter_test_config.dart';
import 'harness.dart';
import 'phone_native_fixture.dart';

// What every test starts with (flutter_test_config.dart's setUp, which
// runs startAfresh): each test here leaves something and starts afresh
// itself, as the test after it would, so it checks the same in any order.

void main() {
  test('nothing a test does opens on the desktop, and the next test’s '
      'file manager was asked nothing', () async {
    expect(native.desktop, isA<FakeDesktop>());
    await native.desktop.reveal('/Users/me/nushi/README.md');
    expect(fakeDesktop(), [
      ['-R', '/Users/me/nushi/README.md'],
    ]);
    startAfresh();
    expect(fakeDesktop(), isEmpty);
  });

  test('what one test leaves in memory the next doesn’t see', () {
    Collapsible.opened.add('tool-1');
    recentRows.add('chat:c');
    startAfresh();
    expect(Collapsible.opened, isEmpty);
    expect(recentRows, isEmpty);
  });

  test('what one test saves to app.json the next doesn’t read', () async {
    showDetails.value = !showDetails.value;
    await pumpEventQueue();
    expect(readSaved(), isNotEmpty);
    startAfresh();
    expect(readSaved(), isEmpty);
  });

  test('what one test leaves in the data folder the next doesn’t see, '
      'but app.json as at launch', () {
    File('$dataDir/left.txt').writeAsStringSync('mine');
    Directory('$dataDir/left/deeper').createSync(recursive: true);
    startAfresh();
    final left = [
      for (final e in Directory(dataDir).listSync()) e.uri.pathSegments,
    ].map((p) => p.lastWhere((s) => s.isNotEmpty)).toSet();
    expect(left.difference({'app.json', 'config'}), isEmpty);
  });

  testWidgets('a phone test that reaches the native edge fails, as in the '
      'browser, where the phone has none', (tester) async {
    final phone = await startPhone(tester, FakeDaemon([]));
    expect(native, isA<PhoneNative>());
    expect(() => native.desktop.reveal('/Users/me/nushi'), throwsStateError);
    expect(() => native.alerts, throwsStateError);
    expect(() => native.diagrams, throwsStateError);
    expect(() => native.window.zoom(), throwsStateError);
    expect(() => native.web.page(), throwsStateError);
    // What the shared widgets read behind a kIsWeb guard answers as there.
    expect(native.window.headersMoveWindow, isFalse);
    expect(native.web.embedded, isFalse);
    expect(native.speller, isNull);
    await endPhone(tester, phone);
  });

  test('a chat the fake daemon changes isn’t the one its test built it '
      'from, which the next test may share', () async {
    final shared = [Chat(id: 'a', title: 'A')];
    final fake = FakeDaemon(shared);
    await fake.unary(NushiService.pinChats, PinChatsRequest(chatIds: ['a']));
    await fake.unary(
      NushiService.setChatColor,
      SetChatColorRequest(chatId: 'a', color: 'teal'),
    );
    expect([fake.chats.single.pin, fake.chats.single.color], [1, 'teal']);
    expect(shared.single, Chat(id: 'a', title: 'A'));
  });

  test('what lib keeps outside widgets is made through run_state.dart', () {
    // A map, set, list or notifier made at the top level (or static) is
    // held for the whole test process; made by run_state.dart's makers,
    // every test's setUp forgets it. These are kept on purpose.
    const kept = {
      'back_swipe.dart _all', // the swipes mounted now
      'browser_page_macos.dart _commits', // pages' channels, live
      'browser_bar.dart _never', // never changes
      'comment_box.dart commentDraftsChanged', // a count, for saving
      'github_review.dart draftsChanged', // a count, for saving
      'review.dart reviews', // read from disk; forgetReviews
      'run_state.dart _forgets',
      'settings.dart _made', // resetAppSettings
      'syntax.dart _highlighters', // by language, the same for every test
    };
    final made = RegExp(
      r'^(?:final|var|  static final)\b[^=(]*?\b(\w+) = *'
      r'(?:<[^=]*>)?(?:\{\}|\[\]|ValueNotifier\b)',
    );
    final found = <String>{
      for (final f in Directory('lib').listSync().whereType<File>())
        if (f.path.endsWith('.dart'))
          for (final line in f.readAsLinesSync())
            if (made.firstMatch(line) case final m?)
              '${f.uri.pathSegments.last} ${m[1]}',
    };
    expect(found, kept);
  });
}
