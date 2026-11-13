import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/drafts_mac.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/platform.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// What's typed is saved at once when the app goes to the back or is
// hidden (main.dart), and when the phone's page hides (iOS may end a page
// in the background), not only half a second after typing stops.

/// Less than the drafts' wait after typing.
const _soon = Duration(milliseconds: 100);

Directory _dir() {
  final dir = Directory.systemTemp.createTempSync('drafts');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  testWidgets('the window going to the back, or hidden: the draft is saved '
      'at once', (tester) async {
    viewport(tester, const Size(1400, 800));
    final dir = _dir();
    final json = File('${dir.path}/drafts.json');
    final fake = FakeDaemon([chat('c', 'claude', 'Fix the login redirect')]);
    final d = await fake.connect(tester, drafts: Drafts(DraftFiles(dir.path)));
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    final binding = tester.binding;
    await tester.enterText(find.byType(TextField), 'A long message');
    await tester.pump(_soon);
    expect(json.existsSync(), isFalse); // still typing
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(_soon);
    expect(json.readAsStringSync(), contains('A long message'));

    await tester.enterText(find.byType(TextField), 'A longer message');
    await tester.pump(_soon);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(_soon);
    expect(json.readAsStringSync(), contains('A longer message'));

    binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the phone’s page hidden: the draft is saved at once', (
    tester,
  ) async {
    final platform = PhonePlatform()..saved = pairedRecord();
    final fake = FakeDaemon([chat('c', 'claude', 'Fix the login redirect')]);
    final phone = await startPhone(tester, fake, platform: platform);
    phone.daemon!.chats['c']!.draft.text.text = 'From the bus';
    await tester.pump(_soon);
    expect(platform.drafts, isNull); // still typing
    platform.visibilityChanged!(visible: false);
    await tester.pump(_soon);
    expect(platform.drafts, contains('From the bus'));
    await endPhone(tester, phone);
  });
}
