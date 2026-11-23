import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_bar.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panes.dart' show PaneHeader;
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_view.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'preview_fixture.dart';

/// A minified line of nearly 5,000 characters (past that it's cut): far
/// wider than any pane.
final _long = 'const tea = [${List.filled(550, '"oolong"').join(',')}];';

/// A file with a long line near its top, and enough lines to scroll.
final String _code = [
  'package main',
  '',
  _long,
  for (var i = 4; i <= 200; i++) 'line $i of the kettle',
].join('\n');

/// The daemon: a chat that wrote `src/tea.go` and `docs/notes.md`.
FakeDaemon _fake() {
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final c = chat('c', 'claude', 'Brew the tea');
  return FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: [
          Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Brew.'),
          wrote('w1', 'src/tea.go'),
          wrote('w2', 'docs/notes.md'),
        ],
      ),
      _ => null,
    })
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      final text = input.path.endsWith('.go') ? _code : '# Notes\n\n$_long\n';
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        WatchChatFileResponse(
          path: '/Users/me/kettle/${input.path}',
          data: utf8.encode(text),
          size: Int64(text.length),
        ),
      );
      return s.stream;
    };
}

/// The app on the chat, [file] in the preview.
Future<Daemon> _app(
  WidgetTester tester, {
  double width = 1700,
  Brightness? brightness,
  String file = 'src/tea.go',
}) => previewApp(
  tester,
  _fake(),
  size: Size(width, 900),
  brightness: brightness,
  file: file,
);

/// Opens the Files pane's ⋯ and says whether Word wrap is checked.
Future<bool> _wordWrap(WidgetTester tester) async {
  if (find.text('Word wrap').evaluate().isEmpty) {
    await tester.tap(
      find.descendant(
        of: find.byType(FilesBar),
        matching: find.byTooltip('More'),
      ),
    );
    await tester.pumpAndSettle();
  }
  final row = find.ancestor(
    of: find.text('Word wrap'),
    matching: find.byType(MenuItemButton),
  );
  return find
      .descendant(of: row, matching: find.byIcon(Icons.check))
      .evaluate()
      .isNotEmpty;
}

/// The palette's wrapping row's title, as it reads now.
String _palette(WidgetTester tester, Daemon d) => appActions(
  tester.element(find.byType(FilesPane)),
  d,
).firstWhere((a) => a.act == Act.wrap).title;

/// The View menu's items' labels, and picks the one called [pick].
List<String> _viewMenu(WidgetTester tester, {String? pick}) {
  final all = viewItems(tester);
  if (pick != null) all.firstWhere((m) => m.label == pick).onSelected!();
  return [for (final m in all) m.label];
}

/// The sideways scroll of the source, while its lines run on.
ScrollPosition? _across(WidgetTester tester) {
  final f = find.descendant(
    of: find.byType(SourceView),
    matching: find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
    ),
  );
  if (f.evaluate().isEmpty) return null;
  return tester.state<ScrollableState>(f).position;
}

/// Line [n]'s number in the source's gutter.
Finder _number(int n) => find.descendant(
  of: find.byType(SourceView),
  matching: find.byWidgetPredicate((w) => w is Text && w.data?.trim() == '$n'),
);

/// The long line's text.
Finder get _longLine => find.descendant(
  of: find.byType(SourceView),
  matching: find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().startsWith('const tea'),
  ),
);

Future<void> _altZ(WidgetTester tester) async {
  await press(tester, LogicalKeyboardKey.keyZ, alt: true);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('⋯ › Word wrap, ⌥Z, View › Wrap Lines and the palette turn '
      'wrapping over, in step, and it’s remembered', (tester) async {
    final d = await _app(tester);
    expect(wrapLines.value, isTrue, reason: 'on at first');
    // No wrap button of its own on the Mac: the ⋯ has it.
    expect(
      find.byWidgetPredicate((w) => w is IconTap && w.icon == Icons.wrap_text),
      findsNothing,
    );
    expect(_viewMenu(tester), contains('Don’t Wrap Lines'));
    expect(_palette(tester, d), 'Don’t wrap lines in Files');
    expect(_across(tester), isNull);
    expect(await _wordWrap(tester), isTrue);

    await tester.tap(find.text('Word wrap'));
    await tester.pumpAndSettle();
    expect(wrapLines.value, isFalse);
    expect(readSaved()['wrap'], isFalse);
    expect(_viewMenu(tester), contains('Wrap Lines'));
    expect(_palette(tester, d), 'Wrap lines in Files');
    expect(_across(tester), isNotNull);
    expect(await _wordWrap(tester), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // A click in the source gives the viewer the focus, for ⌥Z.
    await tester.tap(find.byType(SourceView));
    await tester.pumpAndSettle();
    await _altZ(tester);
    expect(wrapLines.value, isTrue);
    expect(_across(tester), isNull);
    expect(_viewMenu(tester), contains('Don’t Wrap Lines'));

    _viewMenu(tester, pick: 'Don’t Wrap Lines');
    await tester.pumpAndSettle();
    expect(wrapLines.value, isFalse);
    expect(readSaved()['wrap'], isFalse);
    expect(await _wordWrap(tester), isFalse);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('⌥Z leaves a rendered file alone, and wraps its Source', (
    tester,
  ) async {
    wrapLines.value = false;
    final d = await _app(tester, file: 'docs/notes.md');
    await tester.tap(find.byType(PreviewBody));
    await _altZ(tester);
    expect(wrapLines.value, isFalse);
    await tester.tap(inPane(find.byType(SourceButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SourceView));
    await tester.pumpAndSettle();
    await _altZ(tester);
    expect(wrapLines.value, isTrue);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('⌥Z typed in the tree’s search field is a character, not '
      'wrapping', (tester) async {
    final d = await _app(tester);
    await tester.tap(inPane(find.byType(TextField)));
    await tester.pumpAndSettle();
    await _altZ(tester);
    expect(wrapLines.value, isTrue);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a pane too narrow for its buttons still has Word wrap in its '
      '⋯', (tester) async {
    // The pane squeezed in a window too narrow for it (ADR 0123), on its
    // own here.
    viewport(tester, const Size(900, 600));
    final d = await _fake().connect(tester);
    final c = d.chats['c']!..openInFiles('src/tea.go');
    await tester.pumpWidget(
      themed(
        Center(
          child: SizedBox(
            width: 210,
            height: 500,
            child: FilesPane(chat: c, daemon: d, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(inPane(find.byTooltip('More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Word wrap'));
    await tester.pumpAndSettle();
    expect(wrapLines.value, isFalse);
    expect(_across(tester), isNotNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('wrap off, a long line runs on: the view scrolls sideways '
      'and the numbers stay put', (tester) async {
    wrapLines.value = false;
    final d = await _app(tester);
    final across = _across(tester)!;
    expect(across.maxScrollExtent, greaterThan(20000));
    // One line high, however long.
    expect(tester.getSize(_longLine).height, tester.getSize(_number(3)).height);
    final number = tester.getRect(_number(3));
    final line = tester.getRect(_longLine);
    across.jumpTo(400);
    await tester.pump();
    expect(tester.getRect(_number(3)), number);
    expect(tester.getRect(_longLine).left, line.left - 400);
    await render(tester, find.byType(NushiApp), 'preview_wrap_sideways');

    // Shift and the wheel go sideways, and so does a trackpad.
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    final at = tester.getCenter(find.byType(SourceView));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(mouse.hover(at));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(across.pixels, 520);
    final pad = TestPointer(2, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pad.panZoomStart(at));
    for (var i = 1; i <= 10; i++) {
      await tester.sendEventToBinding(
        pad.panZoomUpdate(at, pan: Offset(-20.0 * i, 0)),
      );
      await tester.pump();
    }
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pumpAndSettle();
    expect(across.pixels, greaterThan(600));
    expect(tester.getRect(_number(3)), number);
    expect(tester.takeException(), isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('wrapped, the long line takes many rows and nothing scrolls '
      'sideways', (tester) async {
    final d = await _app(tester);
    expect(
      tester.getSize(_longLine).height,
      greaterThan(tester.getSize(_number(3)).height * 10),
    );
    expect(_across(tester), isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a switch keeps the line on top', (tester) async {
    final d = await _app(tester);
    final list = find.descendant(
      of: find.byType(SourceView),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    final top = tester.getRect(find.byType(SourceView)).top;
    tester.state<ScrollableState>(list).position.jumpTo(3000);
    await tester.pumpAndSettle();
    // The first line whose number is in sight under the top.
    int topLine() {
      for (var n = 1; n <= 200; n++) {
        final f = _number(n);
        if (f.evaluate().isNotEmpty && tester.getRect(f).top >= top) return n;
      }
      return 0;
    }

    final was = topLine();
    expect(was, greaterThan(40));
    Future<void> toggle() async {
      wrapLines.value = !wrapLines.value;
      await tester.pumpAndSettle();
    }

    // The line across the top shows whole, or the next when it barely
    // showed.
    await toggle();
    final off = topLine();
    expect(off, inInclusiveRange(was - 1, was));
    await toggle();
    expect(topLine(), off);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('wrap off, a selection still copies the whole line', (
    tester,
  ) async {
    final copied = clipboardCopies(tester);
    wrapLines.value = false;
    final d = await _app(tester);
    _across(tester)!.jumpTo(2000);
    await tester.pump();
    await tester.tap(find.byType(SourceView));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(copied, isNotEmpty);
    // The numbers aren't the text's.
    // Each line with its break, the empty one too; not the numbers.
    expect(copied.last, startsWith('package main\n\n$_long\nline 4 '));
    expect(copied.last, contains('line 5 of the kettle\nline 6 of'));
    await closeView(tester, d);
  }, variant: onMac);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      testWidgets('the phone: its own button turns wrapping over, '
          '${size.width.toInt()}×${size.height.toInt()}, $name', (
        tester,
      ) async {
        viewport(tester, size, ratio: 3, brightness: brightness);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final fake = _fake();
        final phone = Phone(
          PhonePlatform()..saved = pairedRecord(),
          connectTo: (_) => Daemon(transport: fake, remote: true),
        );
        await tester.pumpWidget(PhoneApp(phone));
        await phone.start();
        await frames(tester, 8);
        await tester.tap(find.text('Brew the tea'));
        await tester.pumpAndSettle();
        PreviewScreen.open(
          tester.element(find.byType(Navigator).first),
          phone.daemon!,
          phone.daemon!.chats['c']!,
          'src/tea.go',
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Don’t wrap lines'), findsOneWidget);
        expect(_across(tester), isNull);
        await render(
          tester,
          find.byType(PhoneApp),
          'preview_wrap_phone_${size.width.toInt()}_on_$name',
        );
        await tester.tap(find.byIcon(Icons.wrap_text));
        await tester.pumpAndSettle();
        expect(wrapLines.value, isFalse);
        expect(find.bySemanticsLabel('Wrap lines'), findsOneWidget);
        expect(_across(tester)!.maxScrollExtent, greaterThan(20000));
        expect(tester.takeException(), isNull);
        await render(
          tester,
          find.byType(PhoneApp),
          'preview_wrap_phone_${size.width.toInt()}_off_$name',
        );
        await endPhone(tester, phone);
      }, variant: onPhone);
    }

    testWidgets("the Files pane's top rows, its bar's buttons at the end, "
        '$name', (tester) async {
      viewport(tester, const Size(900, 200));
      final d = await _fake().connect(tester);
      final c = d.chats['c']!..openInFiles('src/tea.go');
      // The pane on its own, cut to its two rows.
      await tester.pumpWidget(
        themed(
          Center(
            child: RepaintBoundary(
              key: const ValueKey('row'),
              child: ClipRect(
                child: SizedBox(
                  width: 820,
                  height: PaneHeader.height + FilesBar.height,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: 200,
                    // On a pane's fill, as the chat's area backs it.
                    child: ColoredBox(
                      color:
                          (brightness == Brightness.dark
                                  ? Tokens.dark
                                  : Tokens.light)
                              .base,
                      child: SizedBox(
                        height: 200,
                        child: FilesPane(chat: c, daemon: d, onClose: () {}),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          tokens: brightness == Brightness.dark ? Tokens.dark : Tokens.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('row')),
        matchesGoldenFile('goldens/files_top_row_$name.png'),
      );
      await closeView(tester, d);
    }, variant: onMac);

    for (final width in [1700.0, 720.0]) {
      for (final wrap in [true, false]) {
        testWidgets('renders: a source, ${width.toInt()} wide, wrap '
            '${wrap ? 'on' : 'off'}, $name', (tester) async {
          wrapLines.value = wrap;
          final d = await _app(tester, width: width, brightness: brightness);
          expect(tester.takeException(), isNull);
          // Off, the long line runs past the edge, clipped.
          if (wrap) expectTextInside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            'preview_wrap_${width.toInt()}_${wrap ? 'on' : 'off'}_$name',
          );
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }
}
