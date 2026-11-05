import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A line started by the line key (startLine) after a list item continues the
// list; on an empty item it ends it. `|` marks the caret, `[` and `]` a
// selection.

TextEditingValue _value(String marked) {
  final caret = marked.indexOf('|');
  if (caret >= 0) {
    return TextEditingValue(
      text: marked.replaceFirst('|', ''),
      selection: TextSelection.collapsed(offset: caret),
    );
  }
  final start = marked.indexOf('[');
  final end = marked.indexOf(']') - 1;
  return TextEditingValue(
    text: marked.replaceFirst('[', '').replaceFirst(']', ''),
    selection: TextSelection(baseOffset: start, extentOffset: end),
  );
}

String _marked(TextEditingValue v) {
  expect(v.selection.isCollapsed, isTrue);
  return v.text.replaceRange(v.selection.start, v.selection.start, '|');
}

String _line(String before) {
  final c = TextEditingController.fromValue(_value(before));
  addTearDown(c.dispose);
  startLine(c);
  return _marked(c.value);
}

Future<void> _shiftEnter(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  group('a line after', () {
    test('a numbered item starts the next number', () {
      expect(_line('1. one|'), '1. one\n2. |');
      expect(_line('9) nine|'), '9) nine\n10) |');
      expect(_line('intro\n41. ok|\nafter'), 'intro\n41. ok\n42. |\nafter');
    });

    test('a bullet starts the same bullet', () {
      expect(_line('- one|'), '- one\n- |');
      expect(_line('* one|'), '* one\n* |');
    });

    test('an indented item keeps its indent', () {
      expect(_line('- a\n  - b|'), '- a\n  - b\n  - |');
      expect(_line('\t3. c|'), '\t3. c\n\t4. |');
    });

    test('the middle of an item carries the rest down', () {
      expect(_line('1. one|two'), '1. one\n2. |two');
      expect(_line('- [some] text'), '- \n- | text');
    });

    test('an empty item ends the list: the marker goes, the line is blank', () {
      expect(_line('1. one\n2. |'), '1. one\n|');
      expect(_line('- one\n- |  '), '- one\n|');
      expect(_line('- one\n  - |\nnext'), '- one\n|\nnext');
    });

    test('anything else is a plain line', () {
      for (final (before, after) in [
        ('plain|', 'plain\n|'),
        ('|1. one', '\n|1. one'),
        ('1|. one', '1\n|. one'),
        ('1.one|', '1.one\n|'),
        ('-one|', '-one\n|'),
        ('--- |', '--- \n|'),
        ('+ one|', '+ one\n|'),
        ('|', '\n|'),
      ]) {
        expect(_line(before), after, reason: before);
      }
    });
  });

  group('in the composer', () {
    Future<(TextEditingController, Future<void> Function())> composer(
      WidgetTester tester,
    ) async {
      viewport(tester, const Size(1200, 700));
      showDetails.value = false;
      final fake = FakeDaemon([chat('c', 'claude', 'Lists')]);
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
      return (
        tester.widget<TextField>(field).controller!,
        () => closeView(tester, d),
      );
    }

    testWidgets('⇧⏎ continues a list and ends it on an empty item', (
      tester,
    ) async {
      final (c, close) = await composer(tester);
      c.value = _value('1. one|');
      await tester.pump();
      await _shiftEnter(tester);
      expect(_marked(c.value), '1. one\n2. |');
      await _shiftEnter(tester);
      expect(_marked(c.value), '1. one\n|');
      await close();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('one undo takes the line and its marker back', (tester) async {
      final (c, close) = await composer(tester);
      c.value = _value('- one|');
      await tester.pump(const Duration(seconds: 1)); // its own undo step
      await _shiftEnter(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(_marked(c.value), '- one\n- |');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(_marked(c.value), '- one|');
      await close();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('pasted or typed text with list lines is left as it is', (
      tester,
    ) async {
      final (c, close) = await composer(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(Composer),
          matching: find.byType(TextField),
        ),
        '1. one\n',
      );
      await tester.pump();
      expect(c.text, '1. one\n');
      await close();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  testWidgets('a reply box continues lists too', (tester) async {
    final text = TextEditingController();
    addTearDown(text.dispose);
    await tester.pumpWidget(
      themed(
        ReplyField(
          text,
          autofocus: true,
          onEnter: () {},
          decoration: const InputDecoration(),
        ),
      ),
    );
    await tester.pump();
    text.value = _value('- one|');
    await tester.pump();
    await _shiftEnter(tester);
    expect(_marked(text.value), '- one\n- |');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
