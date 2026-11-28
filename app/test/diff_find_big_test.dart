import 'package:diff_view/diff_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_find.dart';
import 'package:nushi/syntax.dart';

import 'big_sql.dart';

// ⌘F in a large diff (1 MiB a side, the most Changes shows): a line is
// drawn with its matches only once the view asks for it, and a step draws
// again only the lines whose current match it moved.

void main() {
  test("a large diff's lines are drawn with their matches as they're "
      'asked for; a step draws only the two it moved between', () {
    final old = bigSql(1000 << 10);
    final neu = old.replaceAll('released early', 'released late');
    final diff = TextDiff.compute(old, neu, path: 'dump.sql');
    final doc = diff.document;
    final lines = SyntaxLines(diff.lines, doc.oldLineCount, doc.newLineCount);
    final hits = findInDiff(
      lines.plainAt,
      doc.oldLineCount,
      doc.newLineCount,
      's',
    );
    final all = [...hits.steps, ...hits.also];
    expect(hits.steps.length, greaterThan(10000));
    // In sight: the new side's first 40 lines.
    void look() {
      for (var i = 0; i < 40; i++) {
        lines.lineAt(PaneSide.neu, i);
      }
    }

    SyntaxLines.linesMarked = 0;
    lines.mark(all, hits.steps.first);
    look();
    expect(SyntaxLines.linesMarked, lessThanOrEqualTo(40));
    SyntaxLines.linesMarked = 0;
    lines.mark(all, hits.steps[1]);
    look();
    expect(SyntaxLines.linesMarked, lessThanOrEqualTo(2));
    // Drawn as before: each of a line's matches a changed word, the
    // current one in its own capture.
    final first = hits.steps.first;
    final drawn = lines.lineAt(first.side, first.line)!;
    final plain = diff.lines.lineAt(first.side, first.line)!;
    final on = [
      for (final h in all)
        if (h.side == first.side && h.line == first.line) h,
    ];
    expect(drawn.inner.length, plain.inner.length + on.length * 3);
    expect(drawn.text, plain.text);
  });

  test('a second query reads the lines plain: none is drawn with the '
      "first one's marks while it looks", () {
    final old = bigSql(1000 << 10, rows: 1);
    final neu = old.replaceAll('released early', 'released late');
    final diff = TextDiff.compute(old, neu, path: 'dump.sql');
    final doc = diff.document;
    final lines = SyntaxLines(diff.lines, doc.oldLineCount, doc.newLineCount);
    final se = findInDiff(
      lines.plainAt,
      doc.oldLineCount,
      doc.newLineCount,
      'se',
    );
    lines.mark([...se.steps, ...se.also], se.steps.first);
    SyntaxLines.linesMarked = 0;
    final sel = findInDiff(
      lines.plainAt,
      doc.oldLineCount,
      doc.newLineCount,
      'sel',
    );
    expect(sel.steps, isNotEmpty);
    expect(SyntaxLines.linesMarked, 0);
  });
}
