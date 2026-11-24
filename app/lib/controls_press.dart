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

/// Makes every [Pressable] and [Tap] below it look hovered, focused or
/// pressed as [look] says, whatever the pointer and the keyboard do: for
/// the component gallery (`app/test/gallery`), which draws each state side
/// by side. Never in the app.
class ShowLook extends InheritedWidget {
  const new({required this.look, required super.child, super.key});

  final ({bool hover, bool focus, bool pressed}) look;

  static ({bool hover, bool focus, bool pressed})? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShowLook>()?.look;

  @override
  bool updateShouldNotify(ShowLook oldWidget) => oldWidget.look != look;
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

/// [fill] with the pointer's tint over it while [look] is under it.
Color _over(Tokens t, ControlLook look, Color fill) =>
    look.hover ? Color.alphaBlend(_tint(t, look), fill) : fill;

/// What a press control is to a screen reader (VoiceOver, Orca, the
/// web's): a button unless it says otherwise.
enum PressRole {
  /// A button, dimmed when disabled: most controls.
  button,

  /// A link, which goes somewhere ([LinkText]).
  link,

  /// Nothing of its own: the caller's Semantics says what it is (a
  /// [Toggle]'s switch), which a button's flag would override.
  none,
}

/// Hover, keyboard focus and press for a control that [builder] draws:
/// the pointing hand (or [cursor]), a click or Enter or Space press it,
/// and a button (or its [role]) to a screen reader. Pressed from the
/// pointer's going down, not the tap's win, which can wait on a drag
/// beside it; hovered from the pointer's being over it, which a touch
/// highlight mode doesn't hide. Without [onTap] it's disabled: no hand,
/// no focus, a dimmed button. Every press control is one (ADR 0049;
/// `tools/design-check` keeps a second press path out).
class Pressable extends StatefulWidget {
  const new({
    required this.onTap,
    required this.builder,
    super.key,
    this.onSecondaryTapUp,
    this.tooltip = '',
    this.autofocus = false,
    this.slop,
    this.tooltipAt,
    this.focusNode,
    this.cursor,
    this.role = PressRole.button,
    this.selected,
    this.ownTarget = false,
  });

  final VoidCallback? onTap;

  /// A right-click on it (a row's menu), whether or not it's enabled.
  final GestureTapUpCallback? onSecondaryTapUp;
  final Widget Function(BuildContext context, ControlLook look) builder;
  final String tooltip;
  final bool autofocus;

  /// What it is to a screen reader.
  final PressRole role;

  /// Whether it's the one picked, to a screen reader (a theme's card, a
  /// list's selected row); null when it's never picked.
  final bool? selected;

  /// Its focus, for a view that moves the keyboard to it (a clash's
  /// Cancel in Settings › Keyboard shortcuts); its own without one.
  final FocusNode? focusNode;

  /// How far the pointer may move in a click, for a control that also
  /// drags (`dragSlop`, its drag's own): else Flutter's, a point for a
  /// mouse.
  final double? slop;

  /// Where its tooltip goes, when not below it as every tooltip's is
  /// (beside the project rail's tiles).
  final TooltipPositionDelegate? tooltipAt;

  /// The pointer over it, when not the pointing hand (a drag's open hand).
  final MouseCursor? cursor;

  /// Whether [builder] makes a finger's target itself (a [Tap]'s row, 44
  /// high and as wide as it is), not centred in 44 square under
  /// [TouchTargets].
  final bool ownTarget;

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

  void _set({bool? hover, bool? focus}) {
    final h = hover ?? _hover;
    final f = focus ?? _focus;
    if (mounted && (h != _hover || f != _focus)) {
      setState(() {
        _hover = h;
        _focus = f;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    final shown = ShowLook.of(context);
    final hover = shown?.hover ?? _hover;
    final focus = shown?.focus ?? _focus;
    final down = shown?.pressed ?? _down;
    final look = widget.builder(context, (
      hover: (hover || down) && on,
      focus: focus && on,
      pressed: down && on,
      enabled: on,
    ));
    final control = MouseRegion(
      cursor:
          widget.cursor ?? (on ? SystemMouseCursors.click : MouseCursor.defer),
      onEnter: (_) => _set(hover: true),
      onExit: (_) => _set(hover: false),
      child: FocusableActionDetector(
        enabled: on,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        onShowFocusHighlight: (v) => _set(focus: v),
        child: PressWatch(
          onPress: (down) => _press(down && on),
          child: _taps(widget.ownTarget ? look : touchTarget(context, look)),
        ),
      ),
    );
    // Over the tooltip, so its words name the same node.
    return Semantics(
      button: widget.role == PressRole.button ? true : null,
      link: widget.role == PressRole.link ? true : null,
      enabled: widget.role == PressRole.none ? null : on,
      selected: widget.selected,
      child: widget.tooltip.isEmpty
          ? control
          : tooltip(
              context,
              widget.tooltip,
              control,
              positionDelegate: widget.tooltipAt,
            ),
    );
  }

  /// [child] clicked, within [Pressable.slop] when it has one.
  Widget _taps(Widget child) => switch (widget.slop) {
    null => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onSecondaryTapUp: widget.onSecondaryTapUp,
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
              (r) => r
                ..onTap = widget.onTap
                ..onSecondaryTapUp = widget.onSecondaryTapUp,
            ),
      },
      child: child,
    ),
  };
}

/// A quiet pressable area, a [Pressable] that draws its tint: a light one
/// under the pointer or with the keyboard's focus (unless not [tint]: a
/// card's title, which shows its grip instead) or when [selected], a
/// deeper one from the pointer's going down (a click shows at once, before
/// what it opens is built), no ripple. A button to the keyboard (Tab
/// reaches it, Enter or Space press it) and to a screen reader (or its
/// [role]); without [onTap], none. Under [TouchTargets] at least 44 high.
class Tap extends StatelessWidget {
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
    this.focusNode,
    this.role = PressRole.button,
  });

  final VoidCallback? onTap;
  final GestureTapUpCallback? onSecondaryTapUp;

  /// Its focus, for a view that moves the keyboard to it or listens to
  /// its keys (Settings › Keyboard shortcuts' key field); its own without
  /// one.
  final FocusNode? focusNode;
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

  /// What it is to a screen reader when it has [onTap]: a row that holds
  /// a switch is [PressRole.none], so it stays a switch.
  final PressRole role;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final on = onTap != null;
    final rest = fill ?? (selected ? t.selected : null);
    final touch = TouchTargets.of(context);
    return Pressable(
      onTap: onTap,
      onSecondaryTapUp: onSecondaryTapUp,
      focusNode: focusNode,
      tooltip: tooltip,
      cursor: cursor,
      role: on ? role : PressRole.none,
      selected: on && selected ? true : null,
      ownTarget: true,
      builder: (context, look) => Container(
        padding: padding,
        constraints: touch
            ? const BoxConstraints(minHeight: TouchTargets.size)
            : null,
        alignment: touch ? AlignmentDirectional.centerStart : null,
        decoration: BoxDecoration(
          color: look.pressed
              ? (rest == null ? t.pressed : Color.alphaBlend(t.pressed, rest))
              : !selected && tint && (look.hover || look.focus)
              ? (rest == null ? t.hover : Color.alphaBlend(t.hover, rest))
              : rest,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}
