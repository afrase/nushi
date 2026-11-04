import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer_code.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'spell_harness.dart';

// Code in the composer's text shows in the code font (codeRuns, codePaints),
// inline code in its ink with its backticks hidden while the caret is
// elsewhere, and the field stays as plain text's: its text, height and caret.

List<String> _code(String text) => [
  for (final c in codeRuns(text)) text.substring(c.start, c.end),
];

/// The spans drawn in [family], by their text.
List<String> _inFont(WidgetTester tester, String family) {
  final found = <String>[];
  editable(tester).text!.visitChildren((span) {
    if (span is TextSpan && span.style?.fontFamily == family) {
      found.add(span.text!);
    }
    return true;
  });
  return found;
}

/// The style of the character at [offset] as drawn.
TextStyle? _styleAt(WidgetTester tester, int offset) {
  var at = 0;
  TextStyle? found;
  editable(tester).text!.visitChildren((span) {
    final text = (span as TextSpan).text;
    if (text == null) return true;
    if (offset < at + text.length) {
      found = span.style;
      return false;
    }
    at += text.length;
    return true;
  });
  return found;
}

/// Whether the backtick at [offset] is drawn.
bool _shown(WidgetTester tester, int offset) {
  expect(editable(tester).text!.toPlainText()[offset], '`');
  return _styleAt(tester, offset)?.fontSize != 0;
}

/// Where the caret at [offset] is drawn, from the box's left.
double _caretX(WidgetTester tester, int offset) =>
    editable(tester).getLocalRectForCaret(TextPosition(offset: offset)).left;

Future<void> _select(WidgetTester tester, TextSelection s) async {
  final text = tester.state<EditableTextState>(find.byType(EditableText));
  text.userUpdateTextEditingValue(
    text.textEditingValue.copyWith(selection: s),
    SelectionChangedCause.keyboard,
  );
  await tester.pump();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

TextStyle? _styleOf(WidgetTester tester, String text) {
  TextStyle? found;
  editable(tester).text!.visitChildren((span) {
    if (span is TextSpan && span.text == text) found = span.style;
    return found == null;
  });
  return found;
}

void main() {
  setUpAll(loadFonts);

  group('code is', () {
    test('a closed pair of single backticks on one line', () {
      expect(_code('run `make check` and `go vet`'), [
        '`make check`',
        '`go vet`',
      ]);
      expect(_code('an open `one'), isEmpty);
      expect(_code('across `two\nlines`'), isEmpty);
      expect(_code('empty `` and ``double`` and ```triple```'), isEmpty);
    });

    test('a fenced block from fence line to fence line, inline code in it '
        'left as it is', () {
      const block = '```dart\nfinal a = `b`;\n```';
      expect(_code('see:\n$block\nafter `c`'), [block, '`c`']);
      expect(_code('```\n```'), ['```\n```']);
      expect(_code('an open fence\n```\nstill typing'), isEmpty);
      expect(_code('not at a line start ```\nx\n```'), isEmpty);
    });
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    spellTest('inline code in the box is in the code font, in its ink on '
        'its chip, backticks muted while the caret is in it, $name', (
      tester,
    ) async {
      await spellBox(
        tester,
        FakeSpeller({}),
        text: 'run `make check` now',
        tokens: tokens,
      );
      await _select(tester, const TextSelection.collapsed(offset: 8));
      expect(_inFont(tester, NushiTheme.codeFont), ['`', 'make check', '`']);
      final body = _styleOf(tester, 'make check')!;
      expect(body.backgroundColor, tokens.inlineCode);
      expect(body.color, tokens.inlineCodeText);
      expect(_styleAt(tester, 4)!.color, tokens.textMuted);
      expect(_styleAt(tester, 4)!.fontSize, greaterThan(0));
      expect(_styleOf(tester, ' now')?.fontFamily, isNull);
    });
  }

  spellTest('a fenced block is in the code font, its fences muted', (
    tester,
  ) async {
    await spellBox(tester, FakeSpeller({}), text: 'a\n```sh\nls -la\n```');
    expect(_inFont(tester, NushiTheme.codeFont), [
      '```sh\n',
      'ls -la\n',
      '```',
    ]);
    expect(_styleOf(tester, '```sh\n')!.color, Tokens.dark.textMuted);
    expect(_styleOf(tester, 'ls -la\n')!.backgroundColor, isNull);
  });

  spellTest("a word in backticks isn't checked; one after them is, and is "
      'underlined where it is', (tester) async {
    final speller = FakeSpeller({'chekc'});
    final (_, chat) = await spellBox(tester, speller);
    await typed(tester, 'the `chekc` and chekc ');
    expect(flagged(chat), ['chekc']);
    expect(chat.draft.text.marks.single.start, 16);
    expect(underlined(tester).map((u) => u.$1), ['chekc']);
    expect(_inFont(tester, NushiTheme.codeFont), ['`', 'chekc', '`']);
  });

  spellTest('the text drawn is the text, and the box is as tall as for '
      'plain text', (tester) async {
    final (_, chat) = await spellBox(tester, FakeSpeller({}), width: 900);
    Future<double> heightOf(String text) async {
      await typed(tester, text);
      expect(editable(tester).text!.toPlainText(), text);
      return tester.getSize(find.byType(TextField)).height;
    }

    final plain = await heightOf('one line');
    expect(await heightOf('`one line`'), plain);
    final three = await heightOf('a\nb\nc');
    expect(await heightOf('```\nb\n```'), three);
    expect(await heightOf('`a`\n`b`\n`c`'), three);
    expect(chat.draft.text.code, hasLength(3));
  });

  spellTest('a caret after code is where the code ends, drawn', (tester) async {
    await spellBox(tester, FakeSpeller({}), width: 900);
    await typed(tester, 'x `wide code here` y');
    final e = editable(tester);
    const end = 18; // after the closing backtick
    final caret = e.getLocalRectForCaret(const TextPosition(offset: end));
    final code = e.getBoxesForSelection(
      const TextSelection(baseOffset: 2, extentOffset: end),
    );
    // A Mac's caret is drawn a little left of its offset (cursorOffset).
    expect(caret.left, moreOrLessEquals(code.last.right, epsilon: 2.5));
    // In the UI font it would end elsewhere: the caret follows the code font.
    final plain = TextPainter(
      text: TextSpan(
        text: 'x `wide code here`',
        style: const NushiTheme(Tokens.dark).ui(Tokens.dark.text),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(plain.dispose);
    expect((plain.width - code.last.right).abs(), greaterThan(4));
  });

  spellTest('text being composed in code is underlined and still code', (
    tester,
  ) async {
    final (_, chat) = await spellBox(tester, FakeSpeller({}));
    chat.draft.text.value = const TextEditingValue(
      text: 'a `kana` b',
      selection: TextSelection.collapsed(offset: 7),
      composing: TextRange(start: 3, end: 7),
    );
    await tester.pump();
    final style = _styleOf(tester, 'kana')!;
    expect(style.fontFamily, NushiTheme.codeFont);
    expect(style.decoration, TextDecoration.underline);
    expect(editable(tester).text!.toPlainText(), 'a `kana` b');
  });

  group('backticks', () {
    // "a `bc` d": the code is 2 to 6, its backticks at 2 and 5.
    const text = 'a `bc` d';

    spellTest('show only with the caret strictly between them', (tester) async {
      await spellBox(tester, FakeSpeller({}), text: text);
      for (final (caret, shown) in [
        (0, false),
        (2, false), // before the opening one
        (3, true),
        (4, true),
        (5, true), // before the closing one
        (6, false), // after it
        (8, false),
      ]) {
        await _select(tester, TextSelection.collapsed(offset: caret));
        expect(_shown(tester, 2), shown, reason: 'caret at $caret');
        expect(_shown(tester, 5), shown, reason: 'caret at $caret');
        expect(editable(tester).text!.toPlainText(), text);
      }
    });

    spellTest('show with either end of a selection in the code, not with '
        'one across it', (tester) async {
      await spellBox(tester, FakeSpeller({}), text: text);
      for (final (base, extent, shown) in [
        (0, 8, false),
        (2, 6, false),
        (0, 4, true),
        (4, 8, true),
        (8, 3, true),
        (3, 4, true),
      ]) {
        await _select(
          tester,
          TextSelection(baseOffset: base, extentOffset: extent),
        );
        expect(_shown(tester, 2), shown, reason: '$base to $extent');
        expect(_shown(tester, 5), shown, reason: '$base to $extent');
      }
    });

    spellTest('hidden, a backtick takes no width and paints nothing; the '
        'caret is on the line as anywhere', (tester) async {
      await spellBox(tester, FakeSpeller({}), text: text, width: 900);
      await _select(tester, const TextSelection.collapsed(offset: 8));
      final e = editable(tester);
      expect(_caretX(tester, 2), _caretX(tester, 3));
      expect(_caretX(tester, 5), _caretX(tester, 6));
      for (final at in [2, 5]) {
        expect(
          e.getBoxesForSelection(
            TextSelection(baseOffset: at, extentOffset: at + 1),
          ),
          isEmpty,
        );
      }
      final line = e.getLocalRectForCaret(const TextPosition(offset: 0));
      for (final at in [2, 3, 5, 6]) {
        final caret = e.getLocalRectForCaret(TextPosition(offset: at));
        expect((caret.top, caret.height), (line.top, line.height));
      }
      // Shown, they take their width again.
      await _select(tester, const TextSelection.collapsed(offset: 4));
      expect(_caretX(tester, 3), greaterThan(_caretX(tester, 2) + 4));
    });

    spellTest('typing the closing backtick hides both; arrowing back in '
        'shows them, and each arrow moves the caret', (tester) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({}), width: 900);
      await typed(tester, 'run `make');
      expect(chat.draft.text.code, isEmpty);
      expect(
        _styleAt(tester, 4)?.fontFamily,
        isNot(NushiTheme.codeFont),
        reason: 'not code yet',
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'run `make`',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      await tester.pump();
      expect(_shown(tester, 4), isFalse);
      expect(_shown(tester, 9), isFalse);
      expect(chat.draft.text.text, 'run `make`');

      final end = _caretX(tester, 10);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(chat.draft.text.selection.baseOffset, 9);
      expect(_shown(tester, 4), isTrue);
      // The caret is before the closing backtick, drawn again; the opening
      // one's width moves it right of where the code ended.
      final closing = editable(tester).getBoxesForSelection(
        const TextSelection(baseOffset: 9, extentOffset: 10),
      );
      expect(closing.single.right - closing.single.left, greaterThan(4));
      expect(
        _caretX(tester, 9),
        moreOrLessEquals(closing.single.left, epsilon: 2.5),
      );
      expect(_caretX(tester, 9), isNot(end));
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(chat.draft.text.selection.baseOffset, 10);
      expect(_shown(tester, 9), isFalse);
      expect(_caretX(tester, 10), end);

      await _select(tester, const TextSelection.collapsed(offset: 4));
      final before = _caretX(tester, 4);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(chat.draft.text.selection.baseOffset, 5);
      expect(_shown(tester, 4), isTrue);
      expect(_caretX(tester, 5), greaterThan(before));
    });

    spellTest('backspace after a hidden closing backtick deletes it, and '
        'the open one shows as typed', (tester) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({}));
      await typed(tester, 'run `make` now');
      await _select(tester, const TextSelection.collapsed(offset: 10));
      expect(_shown(tester, 9), isFalse);
      await tester.pump(const Duration(seconds: 1)); // undo's pause
      await _key(tester, LogicalKeyboardKey.backspace);
      await tester.pump(const Duration(seconds: 1));
      expect(chat.draft.text.text, 'run `make now');
      expect(
        chat.draft.text.selection,
        const TextSelection.collapsed(offset: 9),
      );
      expect(chat.draft.text.code, isEmpty);
      expect(_styleAt(tester, 4)?.fontFamily, isNot(NushiTheme.codeFont));
      expect(_styleAt(tester, 4)?.fontSize, isNot(0));
      // Undone, it's back, and hidden again.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(chat.draft.text.text, 'run `make` now');
      expect(_shown(tester, 9), isFalse, reason: 'the caret is after it');
    });

    spellTest('what is sent keeps its backticks', (tester) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({}));
      await typed(tester, 'run `make check` and `go vet`');
      expect(_shown(tester, 4), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sentPrompts().single.text, 'run `make check` and `go vet`');
      expect(chat.draft.text.text, isEmpty);
    });
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    spellTest('golden: code in the box, $name', (tester) async {
      await spellBox(
        tester,
        FakeSpeller({'chekc'}),
        tokens: tokens,
        width: 720,
      );
      await typed(
        tester,
        'Why does `make check` chekc twice? It runs:\n'
        '```sh\ngo vet ./... && go test ./...\n```\n'
        'and then `flutter test`.',
      );
      await expectLater(
        find.byKey(const Key('window')),
        matchesGoldenFile('goldens/composer_code_$name.png'),
      );
    });
  }
}
