// Show whitespace (ADR 0096): an app preference, off at first, in
// Settings › Appearance, the View menu and the palette; on, the read-only
// source and the editor both mark spaces and tabs, the text as it was.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/main.dart';
import 'package:nushi/place.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_editor.dart';
import 'package:nushi/source_view.dart';
import 'package:nushi/whitespace_marks.dart';
import 'package:re_editor/re_editor.dart';

import 'fake_daemon.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'settings_harness.dart';

/// A canvas that counts the marks drawn on it: circles (a space's) and
/// paths (a tab's), and where the circles are.
class _Counting implements Canvas {
  final dots = <Offset>[];
  int arrows = 0;

  @override
  void drawCircle(Offset c, double radius, Paint paint) => dots.add(c);

  @override
  void drawPath(Path path, Paint paint) => arrows++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The View menu's items' labels, and picks the one called [pick].
List<String> _viewMenu(WidgetTester tester, {String? pick}) {
  final view = tester
      .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
      .menus
      .whereType<PlatformMenu>()
      .firstWhere((m) => m.label == 'View');
  Iterable<PlatformMenuItem> items(PlatformMenuItem m) => switch (m) {
    PlatformMenuItemGroup(:final members) => members.expand(items),
    _ => [m],
  };
  final all = view.menus.expand(items).toList();
  if (pick != null) all.firstWhere((m) => m.label == pick).onSelected!();
  return [for (final m in all) m.label];
}

/// The source view's lines whose whitespace is marked.
int _marked(WidgetTester tester) => tester
    .widgetList<WhitespaceMarks>(find.byType(WhitespaceMarks))
    .where((m) => m.show)
    .length;

void main() {
  setUpAll(loadFonts);

  test('a space is a dot at its middle, a tab an arrow; nothing else', () {
    final c = _Counting();
    paintWhitespace(
      c,
      'a b\t c d',
      (i) => [Rect.fromLTWH(i * 7.0, 0, 7, 17)],
      const Color(0xFF808080),
      7,
    );
    expect(c.dots, [const Offset(10.5, 8.5), const Offset(31.5, 8.5)]);
    expect(c.arrows, 1);
  });

  testWidgets('off at first; on, the source marks every line with '
      'whitespace, and its copy is the text', (tester) async {
    expect(showWhitespace.value, isFalse);
    viewport(tester, const Size(900, 600));
    const text = 'func main() {\n\tx := 1  \n}\n';
    await tester.pumpWidget(themed(const SourceView(text, path: 'main.go')));
    expect(_marked(tester), 0);
    showWhitespace.value = true;
    await tester.pump();
    expect(_marked(tester), 3);
    expect(
      tester
          .widgetList<WhitespaceMarks>(find.byType(WhitespaceMarks))
          .map((m) => m.line),
      ['func main() {', '\tx := 1  ', '}'],
    );
    // ⌘A ⌘C: the file's own text.
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    await tester.tap(find.textContaining('x :=', findRichText: true));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(copied.last, text);
  }, variant: onMac);

  testWidgets('View › Show Whitespace and the palette turn it over in both '
      'views; it’s remembered; marks never reach the saved bytes', (
    tester,
  ) async {
    const text = 'package main\n\nfunc main() {\n\tx := 1  \n}\n';
    final (d, fake) = await openEditor(tester, {'main.go': utf8.encode(text)});
    expect(find.byType(WhitespaceOverlay), findsNothing);
    expect(_viewMenu(tester), contains('Show Whitespace'));

    _viewMenu(tester, pick: 'Show Whitespace');
    await tester.pumpAndSettle();
    expect(showWhitespace.value, isTrue);
    expect(readSaved()['whitespace'], isTrue);
    expect(find.byType(WhitespaceOverlay), findsOneWidget);
    expect(_viewMenu(tester), contains('Hide Whitespace'));
    final context = tester.element(find.byType(SourceEditor));
    expect(
      appActions(context, d).firstWhere((a) => a.act == Act.whitespace).title,
      'Hide whitespace in the preview',
    );

    // The editor keeps its text: an edit and ⌘S save only what's typed.
    final e = editOf(d);
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 3,
      offset: 9,
    );
    await typeIn(tester, e, '\t// one');
    await cmd(tester, LogicalKeyboardKey.keyS);
    expect(
      utf8.decode(fake.writes.single.data),
      'package main\n\nfunc main() {\n\tx := 1  \t// one\n}\n',
    );

    // The palette's action turns it off again.
    appActions(context, d).firstWhere((a) => a.act == Act.whitespace).run();
    await tester.pumpAndSettle();
    expect(showWhitespace.value, isFalse);
    expect(readSaved()['whitespace'], isFalse);
    expect(find.byType(WhitespaceOverlay), findsNothing);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('the overlay marks where re_editor laid the line out', (
    tester,
  ) async {
    showWhitespace.value = true;
    final (d, _) = await openEditor(tester, {
      'main.go': utf8.encode('a b\n\tc\n'),
    });
    await tester.pumpAndSettle();
    // Its arrow and dot drawn: a canvas that counts, given the overlay's
    // painter.
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(WhitespaceOverlay),
        matching: find.byType(CustomPaint),
      ),
    );
    final c = _Counting();
    paint.painter!.paint(c, tester.getSize(find.byType(WhitespaceOverlay)));
    expect(c.dots, hasLength(1));
    expect(c.arrows, 1);
    // The dot is in the space's place: between a and b, on line 1.
    final gutter = find.byType(DefaultCodeLineNumber);
    final line = tester
        .widget<DefaultCodeLineNumber>(gutter)
        .notifier
        .value!
        .paragraphs
        .first;
    final space = line.getRangeRects(const TextRange(start: 1, end: 2)).single;
    final left =
        tester.getTopRight(gutter).dx -
        tester.getTopLeft(find.byType(WhitespaceOverlay)).dx;
    expect(
      c.dots.single.dx,
      closeTo(left + line.offset.dx + space.center.dx, 0.01),
    );
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('Settings › Appearance has Show whitespace, off at first', (
    tester,
  ) async {
    final d = await FakeDaemon([]).connect(tester);
    await pumpSettings(tester, d, SettingsSection.appearance);
    final row = find.text('Show whitespace');
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final toggle = find.descendant(
      of: find.ancestor(of: row, matching: find.byType(Row)).first,
      matching: find.byType(GestureDetector),
    );
    await tester.tap(toggle.last);
    await tester.pumpAndSettle();
    expect(showWhitespace.value, isTrue);
    expect(readSaved()['whitespace'], isTrue);
    await tester.pumpWidget(const SizedBox());
    d.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('renders: a tab-indented file being edited with its '
        'whitespace shown, ${brightness.name}', (tester) async {
      showWhitespace.value = true;
      final (d, _) = await openEditor(tester, {
        'main.go': utf8.encode(tabbed),
      }, brightness: brightness);
      await untilReal(tester, () => editOf(d).highlighted);
      for (final width in [1700.0, 720.0]) {
        viewport(tester, Size(width, 900), brightness: brightness);
        await tester.pumpAndSettle();
        expectTextInside(tester, width);
        expect(find.byType(WhitespaceOverlay), findsOneWidget);
        await render(
          tester,
          find.byType(NushiApp),
          'whitespace_${width.toInt()}_${brightness.name}',
        );
      }
      await endEditor(tester, d);
    }, variant: onMac);
  }
}
