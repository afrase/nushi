import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/kept_notices.dart';
import 'package:nushi/kept_trouble.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A kept file that was set aside, or can't be read, is said once in the
// window, as a closable failure toast in plain words.

void main() {
  setUpAll(loadFonts);

  test('a file that doesn’t parse is noted set aside, with its copy’s '
      'name; one that can’t be read, unread', () {
    final dir = Directory.systemTemp.createTempSync('kept-notices');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bad = File('${dir.path}/drafts.json')..writeAsStringSync('{');
    readKept(bad);
    final unread = File('${dir.path}/reviews.json')..writeAsStringSync('{}');
    Process.runSync('chmod', ['000', unread.path]);
    addTearDown(() => Process.runSync('chmod', ['600', unread.path]));
    expect(() => readKept(unread), throwsA(isA<FileSystemException>()));
    expect(() => readKept(unread), throwsA(isA<FileSystemException>()));

    final [aside, cant] = keptTroubles.value;
    expect(aside.file, 'drafts.json');
    expect(aside.kind, KeptTroubleKind.setAside);
    expect(aside.aside, startsWith('drafts.json.unreadable-'));
    expect(File('${dir.path}/${aside.aside}').readAsStringSync(), '{');
    expect(cant, (
      file: 'reviews.json',
      kind: KeptTroubleKind.unread,
      aside: null,
    ));
  });

  test('the words', () {
    expect(
      keptTroubleText((
        file: 'app.json',
        kind: KeptTroubleKind.setAside,
        aside: 'app.json.unreadable-2026-11-22T10-00-00.000000',
      )),
      'Nushi couldn’t read its settings file, so settings are back to their '
      'defaults. The old file is kept as '
      'app.json.unreadable-2026-11-22T10-00-00.000000.',
    );
    expect(
      keptTroubleText((
        file: 'app.json',
        kind: KeptTroubleKind.unread,
        aside: null,
      )),
      'Nushi can’t read its settings file, so changes to settings won’t be '
      'saved until it can.',
    );
    expect(
      keptTroubleText((
        file: 'reviews.json',
        kind: KeptTroubleKind.copiedAside,
        aside: 'reviews.json.unreadable-x',
      )),
      'Nushi couldn’t read some of its review comments file, so some review '
      'comments are missing. A copy of the file is kept as '
      'reviews.json.unreadable-x.',
    );
  });

  for (final width in [1700.0, 720.0]) {
    testWidgets('each is said once, closable, at ${width.toInt()}', (
      tester,
    ) async {
      viewport(tester, Size(width, 900));
      showDetails.value = false;
      noteKeptTrouble(
        'app.json',
        KeptTroubleKind.setAside,
        aside: 'app.json.unreadable-2026-11-22T10-00-00.000000',
      );
      final d = await FakeDaemon([chat('c', 'claude', 'Fix the parser')])
          .connect(tester);
      d.select('c');
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      final setAside = find.textContaining('settings are back to their');
      expect(setAside, findsOneWidget);
      expectTextInside(tester, width);
      await withRealShadows(
        tester,
        () => render(
          tester,
          find.byType(NushiApp),
          'kept_notice_${width.toInt()}',
        ),
      );

      // One noted later is said after it; the same again isn't.
      noteKeptTrouble('drafts.json', KeptTroubleKind.unread);
      noteKeptTrouble('app.json', KeptTroubleKind.setAside, aside: 'x');
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(setAside, findsNothing);
      expect(
        find.text(
          'Nushi can’t read its drafts file, so changes to drafts won’t be '
          'saved until it can.',
        ),
        findsOneWidget,
      );
      await tester.pump(keptNoticeFor);
      await tester.pumpAndSettle();
      expect(find.textContaining('Nushi can'), findsNothing);
      await closeView(tester, d);
    }, variant: onMac);
  }
}
