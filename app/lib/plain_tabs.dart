import 'package:flutter/material.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// The app's one look for tabs (ADR 0071): plain text, the one showing in the
// primary color with a line under it, no box and no tint. The preview pane's
// file tabs (`preview_tabs.dart`) are drawn from these pieces too.

/// The color of a tab's text: the primary text on the one [showing], the
/// others muted, a step up under the pointer.
Color tabText(Tokens t, {required bool showing, required bool hover}) => showing
    ? t.text
    : hover
    ? t.textSecondary
    : t.textMuted;

/// A tab's [child], with a line along its bottom edge while [showing]. In a
/// [TabLine], [id] names it there, so the line can slide to it.
class TabFace extends StatelessWidget {
  const new({required this.showing, required this.child, super.key, this.id});

  final bool showing;
  final Widget child;
  final Object? id;

  @override
  Widget build(BuildContext context) {
    final line = _TabLineScope.maybeOf(context);
    if (line != null && id != null) line.state._faces[id] = context;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (showing && !(line?.moving ?? false))
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 2,
            child: ColoredBox(color: NushiTheme.of(context).t.textMuted),
          ),
      ],
    );
  }
}

/// Tabs ([child], their [TabFace]s named by their values) whose line
/// slides from the tab that showed to [value]'s over [Motion.standard]
/// through [Motion.settle]; what they show changes at once. At rest each
/// tab draws its own line; a tab new since the last frame gets it at once,
/// as does every tab under Reduce Motion.
class TabLine extends StatefulWidget {
  const new({required this.value, required this.child, super.key});

  final Object? value;
  final Widget child;

  @override
  State<TabLine> createState() => _TabLineState();
}

class _TabLineState extends State<TabLine> with SingleTickerProviderStateMixin {
  final _faces = <Object?, BuildContext>{};
  late final _run =
      AnimationController(vsync: this, duration: Motion.standard, value: 1)
        ..addStatusListener((s) {
          if (s.isCompleted) setState(() {});
        });
  late final _curved = CurvedAnimation(parent: _run, curve: Motion.settle);
  Rect _from = Rect.zero;
  Rect _to = Rect.zero;

  bool get _moving => _run.isAnimating;

  /// Where [value]'s tab's line lies in this box as last laid out.
  Rect? _lineOf(Object? value) {
    final face = _faces[value];
    final here = context.findRenderObject();
    if (face == null || !face.mounted || here is! RenderBox) return null;
    final box = face.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final at = box.localToGlobal(Offset.zero, ancestor: here);
    return Rect.fromLTWH(at.dx, at.dy + box.size.height - 2, box.size.width, 2);
  }

  @override
  void didUpdateWidget(TabLine old) {
    super.didUpdateWidget(old);
    if (widget.value == old.value) return;
    final from = _moving
        ? Rect.lerp(_from, _to, _curved.value)
        : _lineOf(old.value);
    final to = _lineOf(widget.value);
    if (from == null || to == null || reduceMotion(context)) {
      _run.value = 1;
      return;
    }
    _from = from;
    _to = to;
    _run.forward(from: 0).ignore();
  }

  @override
  void dispose() {
    _curved.dispose();
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TabLineScope(
    state: this,
    moving: _moving,
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_moving)
          AnimatedBuilder(
            animation: _curved,
            builder: (context, _) => Positioned.fromRect(
              rect: Rect.lerp(_from, _to, _curved.value)!,
              child: ColoredBox(color: NushiTheme.of(context).t.textMuted),
            ),
          ),
      ],
    ),
  );
}

class _TabLineScope extends InheritedWidget {
  const new({required this.state, required this.moving, required super.child});

  final _TabLineState state;
  final bool moving;

  static _TabLineScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TabLineScope>();

  @override
  bool updateShouldNotify(_TabLineScope old) => old.moving != moving;
}

/// One of a few views of the same thing (`Chat | Changes`), as labels. It
/// measures what [Segmented] measures for the same labels, so a row built
/// around that width keeps it (the chat header's fold, ADR 0071). A value a
/// form saves or sends stays a [Segmented]: it isn't a place to go.
class PlainTabs<T> extends StatelessWidget {
  const new({
    required this.value,
    required this.tabs,
    required this.onChanged,
    super.key,
    this.tooltip,
    this.fill = false,
  });

  final T value;
  final List<(T, String)> tabs;
  final ValueChanged<T> onChanged;
  final String Function(T)? tooltip; // a tab's, such as its key

  /// Takes the height of its row, so the line lies on the row's bottom
  /// border as the file tabs' does. Off the pill's height is kept.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: TabLine(
        value: value,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: fill
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: [
            for (final (v, text) in tabs)
              Semantics(
                selected: v == value,
                child: Pressable(
                  onTap: () => onChanged(v),
                  tooltip: tooltip?.call(v) ?? '',
                  builder: (context, look) => Container(
                    foregroundDecoration: focusRing(t, look),
                    child: TabFace(
                      showing: v == value,
                      id: v,
                      child: Container(
                        alignment: fill ? Alignment.center : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          text,
                          style: theme.ui(
                            tabText(t, showing: v == value, hover: look.hover),
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return fill ? SizedBox(height: double.infinity, child: row) : row;
  }
}
