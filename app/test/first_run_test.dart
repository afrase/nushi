import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/sidebar.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The app with no chats yet; Claude's sessions were found in two
/// folders (one gone).
Future<Daemon> _firstRun(WidgetTester tester, double width) async {
  viewport(tester, Size(width, 600), brightness: Brightness.dark);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>[],
      );
  FoundSession found(String folder, int age, {bool gone = false}) =>
      FoundSession(
        sessionId: folder,
        folder: folder,
        updatedUnixMs: Int64(1000000 - age),
        folderGone: gone,
      );
  final fake = FakeDaemon([])
    ..sessions = (_) => ListAgentSessionsResponse(
      canList: true,
      sessions: [
        found('/Users/me/site', 2),
        found('/Users/me/nushi', 1),
        found('/Users/me/nushi', 5),
        found('/Users/me/old', 0, gone: true),
      ],
    );
  final d = await fake.connect(tester);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

void main() {
  setUpAll(loadFonts);

  // UX review, findings 10 and 14.
  for (final width in [1700.0, 720.0]) {
    testWidgets('the first run: New chat, Open a folder…, the folders '
        'sessions were found in; the footer has Settings ($width wide)', (
      tester,
    ) async {
      final d = await _firstRun(tester, width);
      expect(find.text('New chat'), findsWidgets);
      expect(find.text('Open a folder…'), findsOne);
      expect(find.text('Recent folders'), findsOne);
      // The newest first, once each, not one that's gone.
      final nushi = tester.getTopLeft(find.text('nushi')).dy;
      final site = tester.getTopLeft(find.text('site')).dy;
      expect(nushi, lessThan(site));
      expect(find.text('old'), findsNothing);
      for (final row in ['Jira', 'GitHub', 'Settings']) {
        expect(
          find.descendant(of: find.byType(Sidebar), matching: find.text(row)),
          findsOne,
        );
      }
      await expectLater(
        find.byType(NushiApp),
        matchesGoldenFile('goldens/first_run_${width.toInt()}_dark.png'),
      );
      d.dispose();
    }, variant: _mac);
  }

  testWidgets('a recent folder starts a new chat there', (tester) async {
    final d = await _firstRun(tester, 1200);
    await tester.tap(find.text('site'));
    await tester.pumpAndSettle();
    // The New chat dialog, on that folder.
    expect(find.textContaining('site', findRichText: true), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    d.dispose();
  }, variant: _mac);
}
