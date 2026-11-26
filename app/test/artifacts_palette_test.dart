// Artifacts… as a palette: past the widget's 50 rows it's the only way to
// a workflow's files, which sit in a worktree beside the chat's folder, so
// each row's name shows whole and its folder gives way from its start.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _m = Duration(minutes: 1);

/// A worktree beside the chat's folder, deep enough that its folders are
/// longer than the palette's row.
const _wt = '/Users/me/Developer/nushi-worktrees/audit-docs-workflow-run';

/// A name wider than half the row, narrower than the whole.
const _long = 'every-finding-of-the-audit-across-the-packages-in-order.md';

String _deep(int i) =>
    '$_wt/packages/area-$i/src/components/reports/notes/finding-$i.md';

/// The app on a chat whose workflow wrote 60 files in [_wt], and whose own
/// docs/gone.md, written last, is no longer there (its folder still is),
/// at [width].
Future<Daemon> _app(WidgetTester tester, double width) async {
  showDetails.value = true;
  sidebarHidden.value = true;
  final was = fileChanged;
  fileChanged = (p) => p.endsWith('gone.md') ? null : clock().subtract(_m * 5);
  addTearDown(() => fileChanged = was);
  final c = chat('c', 'claude', 'Audit the docs');
  final items = [
    userSays('u', 'Audit the docs.'),
    workflowWrote('wf', 'audit-docs', [
      for (var i = 0; i < 60; i++) (_deep(i), _m * (10 + i)),
      ('$_wt/packages/$_long', _m * 9),
    ], state: 'done'),
    wrote('w0', 'docs/gone.md')..ended = msAgo(_m),
  ];
  final fake = FakeDaemon([c])
    ..on(
      (input) => switch (input) {
        GetChatRequest() => GetChatResponse(chat: c, items: items),
        _ => null,
      },
    );
  return await openApp(tester, fake, size: Size(width, 900));
}

/// Opens Artifacts…: the palette where the panel has no room, and the
/// palette all the same where it has.
Future<void> _open(WidgetTester tester, Daemon d, {required bool wide}) async {
  final at = tester.element(find.byType(ChatHeader));
  if (wide) {
    showArtifacts(at, d.chats['c']!).ignore();
  } else {
    revealArtifacts(at, d.chats['c']!);
  }
  await tester.pumpAndSettle();
  expect(find.byType(Palette), findsOneWidget);
}

Finder _inPalette(Finder f) =>
    find.descendant(of: find.byType(Palette), matching: f);

void main() {
  setUpAll(loadFonts);

  for (final (width, wide) in [(1700.0, true), (720.0, false)]) {
    testWidgets("Artifacts… shows each file's whole name, its folder cut "
        'from its start, and a gone file says so, at $width', (tester) async {
      final d = await _app(tester, width);
      await _open(tester, d, wide: wide);
      // Each name in view is whole, and its row's detail ends as the
      // folder does, with when it changed.
      for (final n in [_long, for (var i = 0; i < 10; i++) 'finding-$i.md']) {
        final name = _inPalette(find.text(n));
        expect(name, findsOneWidget, reason: n);
        expect(
          tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
          isFalse,
          reason: '$n is cut',
        );
        final detail = _inPalette(find.textContaining('/notes · 5m ago'))
            .evaluate()
            .map((e) => (e.widget as Text).data!);
        expect(detail, isNotEmpty);
        expect(detail.every((s) => s.startsWith('…')), isTrue);
      }
      // A file gone from a folder still there says so in its detail.
      expect(_inPalette(find.text('gone.md')), findsOneWidget);
      expect(_inPalette(find.text('docs · Gone')), findsOneWidget);
      await closeView(tester, d);
    }, variant: onMac);
  }

  for (final (width, wide, mode, label) in [
    (1700.0, true, Brightness.dark, 'wide_dark'),
    (720.0, false, Brightness.light, 'narrow_light'),
  ]) {
    renderTest("render: Artifacts… with a worktree's files, $label", (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = mode;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final d = await _app(tester, width);
      await _open(tester, d, wide: wide);
      await render(tester, find.byType(NushiApp), 'artifacts_palette_$label');
      await closeView(tester, d);
    }, variant: onMac);
  }
}
