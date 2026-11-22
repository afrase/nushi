import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/theme/theme.dart';

/// A row of Settings › Keyboard shortcuts (ADR 0146), one line as the
/// keymaps of desktop apps are: the action's [label] at the left, its key
/// as a cap ([cap]) at the group's right edge, and left of it a [second]
/// key's quieter cap (where the name leaves it room) and the row's
/// buttons, each in a slot that keeps its
/// room shown or not, so the cap never moves: [reset], always shown when
/// given (it marks the row as changed), and [clear], shown only while the
/// row is under the pointer or holds the focus (it stays a Tab stop, and
/// shows once it has the focus). A [line] (a clash, a refusal, why a key
/// isn't used, a note) takes a second line under the label in
/// [lineColor], with [lineEnd] (a clash's Take it and Cancel) at its
/// right end, or under it where both don't fit. [onTap]: a click anywhere
/// else on the row, with its hover tint (the cap listens); none on a row
/// that can't change.
class ShortcutRow extends StatefulWidget {
  const new({
    required this.label,
    required this.cap,
    super.key,
    this.second,
    this.reset,
    this.clear,
    this.line,
    this.lineColor,
    this.lineEnd = const [],
    this.onTap,
    this.slots = true,
    this.lane = 0,
  });

  final String label;
  final Widget cap;
  final Widget? second;
  final Widget? reset;
  final Widget? clear;
  final String? line;
  final Color? lineColor;
  final List<Widget> lineEnd;
  final VoidCallback? onTap;

  /// Whether the row keeps the buttons' slots (a fixed key's has none).
  final bool slots;

  /// The least room the cap takes, its group's widest cap's, the cap at
  /// its right end: the slots and the second key then line up down the
  /// group however long each key is (Linux's words). A cap wider than it
  /// (listening) grows to the left.
  final double lane;

  /// The least height of a row of one line.
  static const height = 36.0;

  /// A button's slot: an `IconTap`'s size.
  static const slot = 26.0;

  /// Whether the row round [context] is under the pointer, with its tint:
  /// its cap takes the tint too, so it keeps its edge on the row.
  static bool pointedAt(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PointedAt>()?.on ?? false;

  @override
  State<ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<ShortcutRow> {
  bool _hover = false;
  bool _focus = false;

  void _hovered(bool on) {
    if (on != _hover) setState(() => _hover = on);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final tappable = widget.onTap != null;
    final name = Text(
      widget.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.ui(t.text),
    );
    final first = Row(
      children: [
        // The second key gives way where the name wouldn't fit on its line
        // beside it: never a name broken mid-word.
        Expanded(
          child: switch (widget.second) {
            final s? => GivesWay(lead: name, extra: s, gap: 8, fill: true),
            null => name,
          },
        ),
        const SizedBox(width: 12),
        if (widget.slots) ...[
          _slot(widget.reset, shown: true),
          const SizedBox(width: NushiTheme.iconGap),
          _slot(widget.clear, shown: _hover || _focus),
          const SizedBox(width: 6),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: widget.lane),
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            heightFactor: 1,
            child: widget.cap,
          ),
        ),
      ],
    );
    final line = widget.line;
    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _hovered(true),
      onExit: (_) => _hovered(false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (on) => setState(() => _focus = on),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: _PointedAt(
            on: _hover && tappable,
            child: Container(
              color: _hover && tappable ? t.hover : null,
              constraints: const BoxConstraints(minHeight: ShortcutRow.height),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              alignment: Alignment.centerLeft,
              child: line == null || line.isEmpty
                  ? first
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        first,
                        _Line(
                          line,
                          style: theme
                              .ui(widget.lineColor ?? t.textMuted, size: 12)
                              .copyWith(
                                fontFamilyFallback: [
                                  ...?theme.uiFallback,
                                  NushiTheme.codeFont,
                                ],
                              ),
                          end: widget.lineEnd,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// [button] in its slot, which keeps its room when it isn't [shown]:
  /// not painted and not hit, but still the keyboard's, so Tab reaches it
  /// and it shows once it has the focus.
  Widget _slot(Widget? button, {required bool shown}) => SizedBox(
    width: ShortcutRow.slot,
    height: ShortcutRow.slot,
    child: button == null
        ? null
        : IgnorePointer(
            ignoring: !shown,
            child: Opacity(
              opacity: shown ? 1 : 0,
              child: Center(child: button),
            ),
          ),
  );
}

/// Says a row is under the pointer ([ShortcutRow.pointedAt]).
class _PointedAt extends InheritedWidget {
  const new({required this.on, required super.child});

  final bool on;

  @override
  bool updateShouldNotify(_PointedAt old) => old.on != on;
}

/// A row's second line: [text] (two lines at most), and [end] at its
/// right end, or on a line of their own under it where both don't fit.
class _Line extends StatelessWidget {
  const new(this.text, {required this.style, required this.end});

  final String text;
  final TextStyle style;
  final List<Widget> end;

  @override
  Widget build(BuildContext context) {
    final words = Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (end.isEmpty) {
      return Padding(padding: const EdgeInsets.only(top: 1), child: words);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: _BesideOrUnder(
        words: words,
        // A list's row: compact buttons.
        buttons: ControlScale.compact(
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: end),
        ),
      ),
    );
  }
}

/// Words and buttons side by side, the buttons at the right end, when
/// the words' one line fits beside them; else the words over the buttons,
/// which stay at the right end.
class _BesideOrUnder extends MultiChildRenderObjectWidget {
  new({required Widget words, required Widget buttons})
    : super(children: [words, buttons]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBesideOrUnder();
}

class _BesideData extends ContainerBoxParentData<RenderBox>;

class _RenderBesideOrUnder extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BesideData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BesideData> {
  /// The room between the words and the buttons beside them.
  static const _gap = 12.0;

  /// The room between the words and the buttons under them.
  static const _under = 6.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BesideData) child.parentData = _BesideData();
  }

  @override
  void performLayout() {
    final words = firstChild!;
    final buttons = childAfter(words)!;
    final width = constraints.maxWidth;
    buttons.layout(const BoxConstraints(), parentUsesSize: true);
    final b = buttons.size;
    final beside =
        words.getMaxIntrinsicWidth(double.infinity) + _gap + b.width <= width;
    words.layout(
      BoxConstraints(maxWidth: beside ? width - _gap - b.width : width),
      parentUsesSize: true,
    );
    final w = words.size;
    final wd = words.parentData! as _BesideData;
    final bd = buttons.parentData! as _BesideData;
    if (beside) {
      final h = w.height > b.height ? w.height : b.height;
      wd.offset = Offset(0, (h - w.height) / 2);
      bd.offset = Offset(width - b.width, (h - b.height) / 2);
      size = constraints.constrain(Size(width, h));
    } else {
      wd.offset = Offset.zero;
      bd.offset = Offset(width - b.width, w.height + _under);
      size = constraints.constrain(Size(width, w.height + _under + b.height));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
