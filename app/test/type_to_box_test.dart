import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/widgets.dart' show confirm;

import 'fake_daemon.dart';
import 'harness.dart';

// Type to write (ADR 0119): a character typed with nothing that takes text
// focused goes into the chat's box, as if typed there.

const _answer =
    'The timestamp is parsed once when the chat loads and kept as a '
    'DateTime, so sorting compares instants rather than strings.';

Future<Daemon> _open(WidgetTester tester) async {
  viewport(tester, const Size(1400, 700));
  showDetails.value = false;
  final c = chat('c', 'claude', 'Timestamps in the sidebar');
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: [
          Item(
            id: 'u1',
            kind: ItemKind.ITEM_KIND_USER_MESSAGE,
            text: 'Why sort by time?',
          ),
          Item(id: 'm1', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: _answer),
        ],
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

/// The chat's box's text field.
Finder get _box => find
    .descendant(of: find.byType(Composer), matching: find.byType(EditableText))
    .first;

String _boxText(WidgetTester tester) =>
    tester.widget<EditableText>(_box).controller.text;

bool _boxFocused(WidgetTester tester) =>
    tester.widget<EditableText>(_box).focusNode.hasFocus;

/// A click on the agent's message: the transcript takes the focus.
Future<void> _clickTranscript(WidgetTester tester) async {
  final text = find.textContaining('kept as a', findRichText: true).last;
  final gesture = await tester.startGesture(
    tester.getCenter(text),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Selects "kept as a" in the agent's message with the mouse.
Future<void> _select(WidgetTester tester) async {
  final text = find.textContaining('kept as a', findRichText: true).last;
  final para = tester.renderObject<RenderParagraph>(text);
  final whole = para.text.toPlainText();
  final from = whole.indexOf('kept as a');
  Offset at(int i, {bool right = false}) {
    final box = para
        .getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))
        .first
        .toRect();
    return para.localToGlobal(
      Offset(right ? box.right - 1 : box.left + 1, box.center.dy),
    );
  }

  final drag = await tester.startGesture(
    at(from),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await drag.moveTo(at(from + 'kept as a'.length - 1, right: true));
  await tester.pump();
  await drag.up();
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);
  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  testWidgets('a letter typed on the transcript lands at the box’s end, '
      'the focus with it; / opens the commands as if typed there', (
    tester,
  ) async {
    final d = await _open(tester);
    d.chats['c']!.draft.text.text = 'Hello';
    await _clickTranscript(tester);
    expect(_boxFocused(tester), isFalse);
    await _type(tester, LogicalKeyboardKey.keyW);
    expect(_boxText(tester), 'Hellow');
    expect(_boxFocused(tester), isTrue);
    final caret = tester.widget<EditableText>(_box).controller.selection;
    expect(caret, const TextSelection.collapsed(offset: 6));

    d.chats['c']!.draft.text.text = '';
    await _clickTranscript(tester);
    await _type(tester, LogicalKeyboardKey.slash);
    expect(_boxText(tester), '/');
    expect(_boxFocused(tester), isTrue);
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('keys with ⌘, Control or Option, Esc, arrows, Tab, Enter and '
      'Space keep their meaning', (tester) async {
    final d = await _open(tester);
    await _clickTranscript(tester);
    for (final key in [
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
    ]) {
      await _type(tester, key);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(_boxText(tester), '');
    expect(_boxFocused(tester), isFalse);
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('R on a selection still replies', (tester) async {
    final d = await _open(tester);
    await _select(tester);
    await _type(tester, LogicalKeyboardKey.keyR);
    expect(find.byType(ReplyBox), findsOneWidget);
    expect(_boxText(tester), '');
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('a letter in a text field stays there', (tester) async {
    final d = await _open(tester);
    // The find bar's field.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    final focus = FocusManager.instance.primaryFocus;
    expect(
      focus?.context?.findAncestorStateOfType<EditableTextState>(),
      isNotNull,
    );
    await _type(tester, LogicalKeyboardKey.keyQ);
    expect(_boxText(tester), '');
    expect(FocusManager.instance.primaryFocus, focus);
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('a letter in a dialog doesn’t reach the box', (tester) async {
    final d = await _open(tester);
    await _clickTranscript(tester);
    final context = tester.element(find.byType(Composer));
    final asked = confirm(context, 'Delete?', 'It goes.', 'Delete');
    await tester.pumpAndSettle();
    await _type(tester, LogicalKeyboardKey.keyQ);
    expect(_boxText(tester), '');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await asked;
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('a letter while a menu is open doesn’t reach the box', (
    tester,
  ) async {
    final d = await _open(tester);
    await _clickTranscript(tester);
    await tester.tap(find.byTooltip('Chat menu').first);
    await tester.pumpAndSettle();
    await _type(tester, LogicalKeyboardKey.keyQ);
    expect(_boxText(tester), '');
    await closeView(tester, d);
  }, variant: mac);
}
