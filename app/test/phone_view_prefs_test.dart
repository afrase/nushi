import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_view.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The Mac's Files options (ADR 0123: Tab size, Indent guides, Scroll past
// end) are the desktop's: the phone's preview shows a source as it always
// has, whatever they're set to, and its files reach none of the desktop's
// Files pane.

/// A Go file indented with tabs, two levels deep.
const _code =
    'package main\n'
    '\n'
    'func main() {\n'
    '\tfor i := 0; i < 3; i++ {\n'
    '\t\tprintln(i)\n'
    '\t}\n'
    '}\n';

/// The daemon: a chat whose files all read [_code].
FakeDaemon _fake() {
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final c = chat('c', 'claude', 'Fix the loop');
  return FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: c),
      _ => null,
    })
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        WatchChatFileResponse(
          path: '/Users/me/loop/${input.path}',
          data: utf8.encode(_code),
          size: Int64(_code.length),
        ),
      );
      return s.stream;
    };
}

/// What the shown source draws that the options would change: what it was
/// handed, each tab's drawn size (as text, so records compare by value),
/// its painters, and how far it scrolls.
typedef _Drawn = ({
  int tabSize,
  bool guides,
  bool pastEnd,
  String tabs,
  int painters,
  double scrolls,
});

_Drawn _drawn(WidgetTester tester) {
  final view = find.byType(SourceView);
  final w = tester.widget<SourceView>(view);
  final tabs = <double>[];
  for (final e
      in find
          .descendant(of: view, matching: find.byType(RichText))
          .evaluate()) {
    (e.widget as RichText).text.visitChildren((span) {
      if (span is TextSpan && span.text == '\t') {
        tabs.add(span.style!.fontSize!);
      }
      return true;
    });
  }
  final down = tester
      .widgetList<Scrollable>(
        find.descendant(of: view, matching: find.byType(Scrollable)),
      )
      .where((s) => s.axisDirection == AxisDirection.down)
      .first;
  return (
    tabSize: w.tabSize,
    guides: w.guides,
    pastEnd: w.pastEnd,
    tabs: tabs.join(' '),
    painters: find
        .descendant(of: view, matching: find.byType(CustomPaint))
        .evaluate()
        .length,
    scrolls: down.controller!.position.maxScrollExtent,
  );
}

/// The phone's preview of `main.go`, opened afresh.
Future<_Drawn> _preview(WidgetTester tester, Daemon d) async {
  PreviewScreen.open(
    tester.element(find.byType(Navigator).first),
    d,
    d.chats['c']!,
    'main.go',
  );
  await tester.pumpAndSettle();
  final drawn = _drawn(tester);
  Navigator.of(tester.element(find.byType(PreviewScreen))).pop();
  await tester.pumpAndSettle();
  return drawn;
}

void main() {
  setUpAll(loadFonts);

  testWidgets("the phone's preview ignores Tab size, Indent guides and "
      'Scroll past end', (tester) async {
    viewport(tester, const Size(390, 844), ratio: 3);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final phone = await startPhone(tester, _fake());
    await tester.tap(find.text('Fix the loop'));
    await tester.pumpAndSettle();
    final d = phone.daemon!;

    final plain = await _preview(tester, d);
    expect(plain.tabSize, 4);
    expect(plain.guides, isFalse);
    expect(plain.pastEnd, isFalse);
    expect(plain.tabs.split(' '), hasLength(4), reason: 'every tab drawn');

    tabSize.value = 8;
    indentGuides.value = true;
    scrollPastEnd.value = true;
    final set = await _preview(tester, d);
    expect(set, plain);
    await endPhone(tester, phone);
  }, variant: onPhone);

  test("the phone's files import none of the desktop's Files pane", () {
    const desktop = [
      'files_pane',
      'files_top_row',
      'files_bar',
      'files_tree',
      'file_view',
      'files_menu',
      'view_options',
    ];
    final found = <String>[];
    for (final f in Directory('lib/phone').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final line in f.readAsLinesSync()) {
        for (final name in desktop) {
          if (RegExp("^(import|export) '[^']*\\b$name\\.dart'")
              .hasMatch(line)) {
            found.add('${f.path}: $line');
          }
        }
      }
    }
    expect(found, isEmpty);
  });
}
