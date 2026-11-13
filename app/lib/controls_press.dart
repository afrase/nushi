part of 'controls.dart';

/// Says the controls below are for a finger (the phone): each gets a
/// target of at least [TouchTargets.size] points, as iOS asks.
class TouchTargets extends InheritedWidget {
  const new({required super.child, super.key});

  static const size = 44.0;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TouchTargets>() != null;

  @override
  bool updateShouldNotify(TouchTargets oldWidget) => false;
}

/// [child] centred in a target of at least 44 points under [TouchTargets],
/// else as it is.
Widget touchTarget(BuildContext context, Widget child) =>
    TouchTargets.of(context)
    ? ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: TouchTargets.size,
          minHeight: TouchTargets.size,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      )
    : child;

/// Tells [onPress] true as the primary pointer goes down on [child], and
/// false as it lifts, is cancelled or moves past the touch slop (a drag,
/// not a click): a control's pressed look, from the pointer itself rather
/// than the tap's win, which can wait on a drag recognizer beside it.
class PressWatch extends StatefulWidget {
  const new({required this.onPress, required this.child, super.key});

  final ValueChanged<bool> onPress;
  final Widget child;

  @override
  State<PressWatch> createState() => _PressWatchState();
}

class _PressWatchState extends State<PressWatch> {
  Offset? _at; // where the pointer went down, while it is

  void _end() {
    if (_at == null) return;
    _at = null;
    widget.onPress(false);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) {
      if (e.buttons != kPrimaryButton) return;
      _at = e.position;
      widget.onPress(true);
    },
    onPointerMove: (e) {
      if (_at case final at? when (e.position - at).distance > kTouchSlop) {
        _end();
      }
    },
    onPointerUp: (_) => _end(),
    onPointerCancel: (_) => _end(),
    child: widget.child,
  );
}

/// Hover, keyboard focus and press for a control that [builder] draws:
/// the pointing hand, a click or Enter or Space press it. Pressed from the
/// pointer's going down, not the tap's win, which can wait on a drag
/// beside it. Without [onTap] it's disabled: no hand, no focus.
class Pressable extends StatefulWidget {
  const new({
    required this.onTap,
    required this.builder,
    super.key,
    this.tooltip = '',
    this.autofocus = false,
    this.slop,
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, ControlLook look) builder;
  final String tooltip;
  final bool autofocus;

  /// How far the pointer may move in a click, for a control that also
  /// drags (`dragSlop`, its drag's own): else Flutter's, a point for a
  /// mouse.
  final double? slop;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false;
  bool _focus = false;
  bool _down = false;

  void _press(bool down) {
    if (mounted && down != _down) setState(() => _down = down);
  }

  void _set(bool hover, bool focus) {
    if (mounted && (hover != _hover || focus != _focus)) {
      setState(() {
        _hover = hover;
        _focus = focus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    final control = FocusableActionDetector(
      enabled: on,
      autofocus: widget.autofocus,
      mouseCursor: on ? SystemMouseCursors.click : MouseCursor.defer,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap?.call(),
        ),
      },
      onShowHoverHighlight: (v) => _set(v, _focus),
      onShowFocusHighlight: (v) => _set(_hover, v),
      child: PressWatch(
        onPress: (down) => _press(down && on),
        child: _taps(
          touchTarget(
            context,
            widget.builder(context, (
              hover: (_hover || _down) && on,
              focus: _focus && on,
              pressed: _down && on,
              enabled: on,
            )),
          ),
        ),
      ),
    );
    return widget.tooltip.isEmpty
        ? control
        : Tooltip(message: widget.tooltip, child: control);
  }

  /// [child] clicked, within [Pressable.slop] when it has one.
  Widget _taps(Widget child) => switch (widget.slop) {
    null => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: child,
    ),
    final slop => RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(
                preAcceptSlopTolerance: slop,
                postAcceptSlopTolerance: slop,
              ),
              (r) => r.onTap = widget.onTap,
            ),
      },
      child: child,
    ),
  };
}

/// A quiet pressable area: a light tint under the pointer (unless not
/// [tint]: a card's title, which shows its grip instead) or when
/// [selected], a deeper one from the pointer's going down (a click shows
/// at once, before what it opens is built), no ripple.
class Tap extends StatefulWidget {
  const new({
    required this.onTap,
    required this.child,
    super.key,
    this.onSecondaryTapUp,
    this.selected = false,
    this.padding = EdgeInsets.zero,
    this.radius = NushiTheme.control,
    this.tooltip = '',
    this.cursor,
    this.tint = true,
    this.fill,
  });

  final VoidCallback? onTap;
  final GestureTapUpCallback? onSecondaryTapUp;
  final Widget child;
  final bool selected;

  /// What it's filled with, selected or not, in the place of the selected
  /// color and of nothing: the pointer's tints go over it (a chat's color).
  final Color? fill;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String tooltip;

  /// The pointer over it, when not the pointing hand (a drag's open hand).
  final MouseCursor? cursor;

  /// Whether the pointer over it tints it.
  final bool tint;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _hover = false;
  bool _down = false;

  void _press(bool down) {
    if (mounted && down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final on = widget.onTap != null;
    final rest = widget.fill ?? (widget.selected ? t.selected : null);
    final tap = MouseRegion(
      cursor:
          widget.cursor ?? (on ? SystemMouseCursors.click : MouseCursor.defer),
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: PressWatch(
        onPress: (down) => _press(down && on),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onSecondaryTapUp: widget.onSecondaryTapUp,
          child: Container(
            padding: widget.padding,
            constraints: TouchTargets.of(context)
                ? const BoxConstraints(minHeight: TouchTargets.size)
                : null,
            alignment: TouchTargets.of(context)
                ? AlignmentDirectional.centerStart
                : null,
            decoration: BoxDecoration(
              color: _down && on
                  ? (rest == null
                        ? t.pressed
                        : Color.alphaBlend(t.pressed, rest))
                  : !widget.selected && _hover && on && widget.tint
                  ? (rest == null ? t.hover : Color.alphaBlend(t.hover, rest))
                  : rest,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
    return widget.tooltip.isEmpty
        ? tap
        : Tooltip(message: widget.tooltip, child: tap);
  }
}
