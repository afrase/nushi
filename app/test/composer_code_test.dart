import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer_code.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'spell_harness.dart';

// Code in the composer's text shows in the code font (codeRuns, codePaints),
// and the field stays as plain text's: its text, height and caret.

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
        'its chip, backticks muted, $name', (tester) async {
      await spellBox(
        tester,
        FakeSpeller({}),
        text: 'run `make check` now',
        tokens: tokens,
      );
      expect(_inFont(tester, NushiTheme.codeFont), ['`', 'make check', '`']);
      final body = _styleOf(tester, 'make check')!;
      expect(body.backgroundColor, tokens.inlineCode);
      expect(body.color, tokens.inlineCodeText);
      expect(_styleOf(tester, '`')!.color, tokens.textMuted);
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
