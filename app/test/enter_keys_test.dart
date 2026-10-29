import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/reply_cards.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

// Enter in the boxes that send (isSendKey): ⏎ and ⌘⏎ send; ⇧, ⌥ and ⌃ (with
// ⌘ too) start a line, which Nushi writes itself at the selection. Real key
// events, the modifiers held down; a widget test has no platform text
// input, so a line here is Nushi's own (left to macOS, a release build's
// field got none for ⌘⏎ and a space for ⌃⏎, step 346).

const _lineKeys = <String, List<LogicalKeyboardKey>>{
  '⇧⏎': [LogicalKeyboardKey.shiftLeft],
  '⌥⏎': [LogicalKeyboardKey.altLeft],
  '⌃⏎': [LogicalKeyboardKey.controlLeft],
  '⌘⇧⏎': [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.shiftLeft],
};

Future<void> _enter(
  WidgetTester tester, [
  List<LogicalKeyboardKey> holding = const [],
]) async {
  for (final k in holding) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  for (final k in holding.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  await tester.pump();
}

/// 'abcd' in [field], with the cursor after b, or b and c selected.
Future<TextEditingController> _abcd(
  WidgetTester tester,
  Finder field, {
  bool range = false,
}) async {
  final c = tester.widget<TextField>(field).controller!
    ..value = TextEditingValue(
      text: 'abcd',
      selection: range
          ? const TextSelection(baseOffset: 1, extentOffset: 3)
          : const TextSelection.collapsed(offset: 2),
    );
  await tester.pump();
  return c;
}

void _startedLine(TextEditingController c, {bool range = false}) {
  expect(c.text, range ? 'a\nd' : 'ab\ncd');
  expect(c.selection, TextSelection.collapsed(offset: range ? 2 : 3));
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a reply: ⇧, ⌥, ⌃ and ⌘⇧ with Enter start one line at the '
      'cursor or in place of the selection; ⏎ and ⌘⏎ send', (tester) async {
    final sent = <String>[];
    final text = TextEditingController();
    addTearDown(text.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: ReplyField(
            text,
            autofocus: true,
            onEnter: () => sent.add(text.text),
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );
    await tester.pump();
    final field = find.byType(TextField);
    for (final MapEntry(key: name, value: holding) in _lineKeys.entries) {
      for (final range in [false, true]) {
        final c = await _abcd(tester, field, range: range);
        await _enter(tester, holding);
        _startedLine(c, range: range);
        expect(sent, isEmpty, reason: '$name sent');
      }
    }
    await _abcd(tester, field);
    await _enter(tester);
    await _enter(tester, [LogicalKeyboardKey.metaLeft]);
    expect(sent, ['abcd', 'abcd']);
    expect(text.text, 'abcd', reason: 'no line from ⌘⏎');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the reply dialog: ⌥⏎ starts a line, ⌘⏎ saves', (tester) async {
    final replies = Replies([
      (quote: 'kept as a DateTime', text: 'abcd', from: ''),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(body: ReplyCards(replies, onDone: () {})),
      ),
    );
    await tester.tap(find.text('abcd'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    final c = await _abcd(tester, field);
    await _enter(tester, [LogicalKeyboardKey.altLeft]);
    _startedLine(c);
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'not saved');
    await _enter(tester, [LogicalKeyboardKey.metaLeft]);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(replies.value.single.text, 'ab\ncd');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the composer: the same keys start a line and send nothing; '
      '⌘⏎ sends', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 700);
    addTearDown(tester.view.reset);
    showDetails.value = false;
    final fake = FakeDaemon([chat('c', 'claude', 'Keys')]);
    final d = await fake.connect(tester);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(Composer),
      matching: find.byType(TextField),
    );
    await tester.tap(field);
    await tester.pump();
    for (final MapEntry(key: name, value: holding) in _lineKeys.entries) {
      for (final range in [false, true]) {
        final c = await _abcd(tester, field, range: range);
        await _enter(tester, holding);
        _startedLine(c, range: range);
        expect(
          fake.calls.whereType<SendPromptRequest>(),
          isEmpty,
          reason: name,
        );
      }
    }
    final c = await _abcd(tester, field);
    await _enter(tester, [LogicalKeyboardKey.metaLeft]);
    await tester.pumpAndSettle();
    final sent = fake.calls.whereType<SendPromptRequest>().single;
    expect(sent.text, 'abcd');
    expect(sent.now, isFalse, reason: 'nothing to stop');
    expect(c.text, isEmpty);
    await tester.pumpWidget(const SizedBox()); // its timers end
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a review comment: the same keys; the keypad’s Enter saves, '
      'Escape drops it', (tester) async {
    final saved = <String>[];
    var dropped = false;
    final text = TextEditingController();
    addTearDown(text.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: CommentBox(
            lines: 'Line 3',
            controller: text,
            onSave: saved.add,
            onCancel: () => dropped = true,
          ),
        ),
      ),
    );
    await tester.pump();
    final field = find.byType(TextField);
    for (final MapEntry(key: name, value: holding) in _lineKeys.entries) {
      final c = await _abcd(tester, field);
      await _enter(tester, holding);
      _startedLine(c);
      expect(saved, isEmpty, reason: name);
    }
    await _abcd(tester, field);
    await _enter(tester, [LogicalKeyboardKey.metaLeft]);
    expect(saved, ['abcd']);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pump();
    expect(saved, ['abcd', 'abcd']);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dropped, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a subagent’s box: the same keys', (tester) async {
    final fake = FakeDaemon([]);
    final d = await fake.connect(tester);
    final c = ChatState('c', '/tmp')
      ..agent = 'claude'
      ..items.add(
        Item(
          id: 'a',
          kind: ItemKind.ITEM_KIND_TOOL_CALL,
          agent: 'Explore',
          agentId: 'ab59',
          title: 'Find the redirect',
          status: 'in_progress',
          subagent: Subagent(state: 'running'),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: SubagentPane(chat: c, daemon: d, id: 'a', onClose: () {}),
        ),
      ),
    );
    await tester.pump();
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();
    for (final MapEntry(key: name, value: holding) in _lineKeys.entries) {
      final text = await _abcd(tester, field);
      await _enter(tester, holding);
      _startedLine(text);
      expect(fake.calls.whereType<SendPromptRequest>(), isEmpty, reason: name);
    }
    await _abcd(tester, field);
    await _enter(tester, [LogicalKeyboardKey.metaLeft]);
    await tester.pump();
    final sent = fake.calls.whereType<SendPromptRequest>().single;
    expect(sent.text, 'abcd');
    expect(sent.toSubagent, 'a');
    await tester.pumpWidget(const SizedBox()); // its timers end
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
