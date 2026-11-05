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
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, ControlLook look) builder;
  final String tooltip;
  final bool autofocus;

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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: touchTarget(
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
}
