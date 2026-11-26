part of 'source_view.dart';

// A source view's lines as one build draws them: their code's colours on
// a find's fills and on the selection (issue 117), the code style and its
// measures, and each line's text widget, the same in both wrappings.

/// What a build of [_SourceViewState] draws its lines with, worked out
/// once a build: the theme's colours and the fills code sits on, the code
/// font's measures, the line numbers' and indent guides' figures.
final class _Drawn {
  new(this.view, BuildContext context)
    : theme = NushiTheme.of(context),
      selectionColor =
          DefaultSelectionStyle.of(context).selectionColor ??
          DefaultSelectionStyle.defaultColor,
      scaler = MediaQuery.textScalerOf(context) {
    final t = theme.t;
    colors = findColors(t);
    style = theme.code(t.text, size: 12);
    gutter = theme.code(t.textMuted, size: 12);
    digits = '${view._lines.length}'.length;
    // Measured as a Text draws it, over the DefaultTextStyle: its letter
    // spacing widens each character, and the run-on width must hold them.
    final drawn = DefaultTextStyle.of(context).style.merge(style);
    final zero = TextPainter(
      text: TextSpan(text: '0', style: drawn),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    char = zero.width;
    view._lineHeight = zero.height;
    zero.dispose();
    // The letter spacing every character has, a tab's too; and the
    // strut that holds a line's height when a tab's font is larger.
    spacing = drawn.letterSpacing ?? 0;
    strut = StrutStyle.fromTextStyle(drawn, forceStrutHeight: true);
    // Indent guides, a level's columns apart (the file's own, [indents]).
    counted = view.widget.guides
        ? (view._indents ??= indents(view._lines, view.widget.tabSize))
        : null;
    step = (counted?.unit ?? view.widget.tabSize) * char;
  }

  final _SourceViewState view;
  final NushiTheme theme;
  final Color selectionColor;
  final TextScaler scaler;
  late final FindColors colors;
  late final TextStyle style; // the code's
  late final TextStyle gutter; // the line numbers' and a cut line's note
  late final int digits; // the last line number's
  late final double char; // a column's width
  late final double spacing; // the letter spacing
  late final StrutStyle strut;
  late final Indents? counted;
  late final double step; // an indent level's width

  Tokens get t => theme.t;

  /// The fills code sits on: a hit's and the current one's, the
  /// selection's, and a hit's and the current one's over it.
  late final Color hitFill = Color.alphaBlend(colors.hit, t.base);
  late final Color nowFill = Color.alphaBlend(colors.now, t.base);
  late final Color selected = Color.alphaBlend(selectionColor, t.base);
  late final Color hitSelected = Color.alphaBlend(colors.hit, selected);
  late final Color nowSelected = Color.alphaBlend(colors.now, selected);

  /// A hit's code keeps its contrast on the hit's fill (issue 117).
  Color ink(Color c, {required bool now}) => codeOn(
    c,
    now ? nowFill : hitFill,
    background: t.base,
    floor: codeOnTintContrast,
  );

  /// And on the selection, or a hit over it: drawn again over the
  /// selected part of a line ([_LineSelection]).
  Color inkSelected(Color c, LineHit? hit) => codeOn(
    c,
    hit == null
        ? selected
        : hit.now
        ? nowSelected
        : hitSelected,
    background: t.base,
    floor: codeOnTintContrast,
  );

  /// Line [i]'s number, as wide as the last one's.
  String number(int i) => '${i + 1}'.padLeft(digits);

  /// Line [i]'s indent level.
  int level(int i) => counted?.levels[i] ?? 0;

  /// Line [i]'s text; [overSelection]: as it's drawn again over the
  /// selection, null when nothing would change there. [found]: the
  /// line's hits when the caller has them, so a line in sight is searched
  /// once a build, not once for each thing drawn of it.
  TextSpan? spans(int i, {bool overSelection = false, List<LineHit>? found}) {
    final whole = view._lines[i];
    final cut = whole.length > _maxLine;
    final line = cut ? whole.substring(0, _maxLine) : whole;
    final runs = spansOf(t, line, view._spans?.elementAtOrNull(i));
    final hits = found ?? view._lineHits(i);
    final List<TextSpan> shown;
    if (!overSelection) {
      shown = onHits(runs, hits, plain: t.text, ink: ink);
    } else if (overSelected(runs, hits, plain: t.text, ink: inkSelected)
        case final over?) {
      shown = over;
    } else {
      return null;
    }
    // design: clear, not a colour: the line's note isn't drawn again
    const clear = TextStyle(color: Color(0x00000000));
    return TextSpan(
      style: style,
      children: [
        // An empty text can't be selected, so its break wouldn't copy.
        if (line.isEmpty)
          TextSpan(text: _blank, style: overSelection ? clear : null),
        ...tabStops(
          shown,
          fontSize: style.fontSize!,
          column: char,
          tabSize: view.widget.tabSize,
          spacing: spacing,
        ),
        if (cut)
          TextSpan(
            text: ' … (${whole.length - _maxLine} more)',
            style: overSelection ? gutter.merge(clear) : gutter,
          ),
      ],
    );
  }

  /// Line [i]'s text as a line of the list, its hits under it and its
  /// selection with it; run on, it doesn't wrap.
  Widget line(int i, {required bool wrapped}) {
    final hits = view._lineHits(i);
    return _Line(
      LineHits(
        hits: hits,
        colors: colors,
        // Run on, it paints again as it scrolls sideways: only the
        // matches in sight then.
        inSightAcross: !wrapped,
        child: Text.rich(
          spans(i, found: hits)!,
          softWrap: wrapped ? null : false,
          strutStyle: strut,
          selectionColor: Colors.transparent,
        ),
      ),
      whole: view._lines[i],
      overSelection: () => spans(i, overSelection: true, found: hits),
      column: char,
      level: level(i),
      step: step,
    );
  }
}
