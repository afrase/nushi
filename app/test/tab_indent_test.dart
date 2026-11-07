import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/tab_indent.dart';
import 'package:re_editor/re_editor.dart';

CodeLineEditingValue _value(String text, CodeLineSelection s) =>
    CodeLineEditingValue(codeLines: CodeLines.fromText(text), selection: s);

String _text(CodeLineEditingValue v) => v.codeLines.asString(TextLineBreak.lf);

void main() {
  test('which files indent with tabs', () {
    expect(indentsWithTabs('Makefile', ''), isTrue);
    expect(indentsWithTabs('a/b/rules.mk', ''), isTrue);
    expect(indentsWithTabs('main.go', '  spaces\n'), isTrue);
    expect(indentsWithTabs('a.c', '\tx\n\ty\n  z\n'), isTrue);
    expect(indentsWithTabs('a.c', '\tx\n  y\n  z\n'), isFalse);
    expect(indentsWithTabs('a.txt', 'plain\n'), isFalse);
  });

  test('Tab and ⇧Tab over lines move each by a tab, the selection with '
      'them', () {
    const text = 'a\n\tb\nc\n';
    final indented = tabIndent(
      _value(
        text,
        const CodeLineSelection(
          baseIndex: 0,
          baseOffset: 0,
          extentIndex: 2,
          extentOffset: 0,
        ),
      ),
    );
    // The last line, reached only at its start, stays.
    expect(_text(indented), '\ta\n\t\tb\nc\n');
    expect(indented.selection.extentOffset, 0);
    final out = tabOutdent(indented);
    expect(_text(out), text);
    // Spaces go four at most.
    final spaces = tabOutdent(
      _value('      x', const CodeLineSelection.collapsed(index: 0, offset: 6)),
    );
    expect(_text(spaces), '  x');
    expect(spaces.selection.extentOffset, 2);
  });

  test('Return carries the line’s tabs and spaces', () {
    final v = tabNewLine(
      _value('\t  x()', const CodeLineSelection.collapsed(index: 0, offset: 5)),
    );
    expect(_text(v), '\t  x(\n\t  \t\n\t  )');
    expect(v.selection.extent, const CodeLinePosition(index: 1, offset: 4));
  });
}
