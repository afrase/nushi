import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/theme/theme.dart';

/// A toast's action: its words and what pressing it does (Undo, Go to
/// chat). Pressing it also takes the toast away.
typedef ToastAction = ({String label, VoidCallback onPressed});

/// Shows the app's one toast in [toasts] (`Toasts.maybeOf(context)`):
/// [text], after [leading] or [icon] when given, then [action] as a
/// compact button and, when [closable], a × (docs/design.md's Toasts). It
/// stays [duration]; with [replace], it takes the place of the one
/// showing (never a failure's), else it waits its turn. A failure goes
/// through [showFailure].
void showToast(
  Toasts? toasts,
  String text, {
  IconData? icon,
  Widget? leading,
  ToastAction? action,
  bool closable = false,
  bool replace = false,
  Duration duration = const Duration(seconds: 4),
  Key? key,
}) => _show(
  toasts,
  text,
  icon: icon,
  leading: leading,
  action: action,
  closable: closable,
  replace: replace,
  duration: duration,
  key: key,
);

/// How long a failure stays: twice a plain toast's, so an error that
/// comes while the user looks elsewhere is still there to read.
const failureFor = Duration(seconds: 8);

/// Shows [text] as a failure, the one look every error has: the toast on
/// the failure's soft fill (`crashedSoft`) with [icon] in its ink and a ×,
/// staying [duration] (docs/design.md's Toasts). It takes a plain
/// toast's place at once, [replace] or not ([Toasts.show]); [replace]
/// lets it take a failure's too. [action] as [showToast]'s.
void showFailure(
  Toasts? toasts,
  String text, {
  IconData icon = Icons.error_outline,
  ToastAction? action,
  bool replace = false,
  Duration duration = failureFor,
  Key? key,
}) => _show(
  toasts,
  text,
  icon: icon,
  failed: true,
  action: action,
  closable: true,
  replace: replace,
  duration: duration,
  key: key,
);

void _show(
  Toasts? toasts,
  String text, {
  required bool closable,
  required bool replace,
  required Duration duration,
  IconData? icon,
  Widget? leading,
  bool failed = false,
  ToastAction? action,
  Key? key,
}) => toasts?.show(
  (close) => ToastLine(
    text,
    icon: icon,
    leading: leading,
    failed: failed,
    action: action == null
        ? null
        : (
            label: action.label,
            onPressed: () {
              close();
              action.onPressed();
            },
          ),
    onClose: closable ? close : null,
  ),
  key: key,
  duration: duration,
  replace: replace,
  holds: action != null,
  failed: failed,
);

/// Where the window's toasts show and their queue ([Toasts]), over
/// everything in [child] (the app's navigator: its views, Settings, a
/// dialog), ADR 0128. On the Mac and Linux a toast comes down from the
/// top, centred under the main area's header where a [ToastAnchor] says;
/// with none (no main area yet) under where its header would be. On the
/// phone ([atBottom]) it comes up from the bottom, near the thumb.
class ToastHost extends StatefulWidget {
  const new({required this.child, super.key, this.atBottom = false});

  final Widget child;
  final bool atBottom;

  /// A toast's width on the Mac and Linux, where there's room; a phone's
  /// fills the width.
  static const width = 420.0;

  /// The least room between a toast and the main area's edges.
  static const margin = 8.0;

  @override
  State<ToastHost> createState() => Toasts();
}

/// The window's toasts: one shows at a time, the rest wait their turn;
/// each goes after its duration, or when its action, its × or [hide]
/// takes it away. [show] is what `showToast` calls.
class Toasts extends State<ToastHost> with SingleTickerProviderStateMixin {
  /// The toasts of the window [context] is in, if it has them.
  static Toasts? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<Toasts>();

  /// What a [ToastAnchor] holds and the showing toast follows.
  final LayerLink anchor = LayerLink();

  late final _run = AnimationController(
    vsync: this,
    duration: Motion.enter,
    reverseDuration: Motion.exit,
  )..addStatusListener(_ran);
  late final _curved = CurvedAnimation(
    parent: _run,
    curve: Motion.settle,
    reverseCurve: Motion.leave.flipped,
  );
  late final _app = OverlayEntry(
    builder: (_) => widget.child,
    maintainState: true,
  );
  late final _layer = OverlayEntry(builder: _place);
  final _queue = <_Toast>[];
  _Toast? _showing;
  bool _going = false;
  Timer? _timer;

  /// The width the [ToastAnchor] gives a toast, while one is in the tree,
  /// and which one told it: one going (as the main view changes) clears it
  /// only if no other has told it since.
  double? _anchorWidth;
  Object? _anchorBy;

  void _anchored(Object by, double? width) {
    if (!mounted || (width == null && by != _anchorBy)) return;
    _anchorBy = width == null ? null : by;
    if (width == _anchorWidth) return;
    _anchorWidth = width;
    _layer.markNeedsBuild();
  }

  /// Shows a toast whose line [line] builds, given what closes it; it
  /// goes after [duration], unless it [holds] an action and VoiceOver is
  /// on (as Material's snack bar does). With [replace] it takes the place
  /// of the one showing at once; else it waits its turn. A [failed] one
  /// sits on the failure's soft fill ([showFailure]), and is never unseen
  /// behind a plain one: it takes a plain one's place at once (that one
  /// is gone; a slow call's spinner can stay minutes), and waits only for
  /// a failure, ahead of the plain ones waiting. A plain one never takes
  /// a failure's place, [replace] or not: it waits its turn.
  void show(
    Widget Function(VoidCallback close) line, {
    Duration duration = const Duration(seconds: 4),
    bool replace = false,
    bool holds = false,
    bool failed = false,
    Key? key,
  }) {
    if (!mounted) return;
    final toast = _Toast(key, duration, holds: holds, failed: failed);
    toast.line = line(() => _close(toast));
    final showing = _showing;
    final now = switch (showing) {
      null => false,
      _Toast(failed: true) => failed && replace,
      _ => failed || replace,
    };
    if (now) {
      _put(toast);
    } else {
      final plain = _queue.indexWhere((t) => !t.failed);
      _queue.insert(failed && plain >= 0 ? plain : _queue.length, toast);
      if (showing == null) _next();
    }
  }

  /// Takes the showing toast away, unless it's a failure (it goes on its
  /// own or by its ×); the next waiting comes once it's gone.
  void hide() {
    if (_showing?.failed ?? true) return;
    _close(_showing);
  }

  void _close(_Toast? toast) {
    if (toast == null || _going || toast != _showing) return;
    _timer?.cancel();
    if (reduceMotion(context)) {
      _gone();
    } else {
      _going = true;
      _run.reverse().ignore();
      _layer.markNeedsBuild();
    }
  }

  /// Takes away the showing toast and those waiting, at once: for tests.
  @visibleForTesting
  void clear() {
    _queue.clear();
    _timer?.cancel();
    _gone();
  }

  void _next() {
    if (_queue.isEmpty) return;
    _put(_queue.removeAt(0));
  }

  void _put(_Toast toast) {
    _timer?.cancel();
    _showing = toast;
    _going = false;
    if (reduceMotion(context)) {
      _run.value = 1;
    } else if (!_run.isForwardOrCompleted || _run.isAnimating) {
      _run.forward().ignore();
    }
    final stays = toast.holds && MediaQuery.accessibleNavigationOf(context);
    if (!stays) _timer = Timer(toast.duration, () => _close(toast));
    _layer.markNeedsBuild();
  }

  void _ran(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _going) _gone();
  }

  void _gone() {
    _going = false;
    _showing = null;
    _run.value = 0;
    if (mounted) _layer.markNeedsBuild();
    _next();
  }

  @override
  void didUpdateWidget(ToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _app.markNeedsBuild();
    _layer.markNeedsBuild();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curved.dispose();
    _run.dispose();
    _app
      ..remove()
      ..dispose();
    _layer
      ..remove()
      ..dispose();
    super.dispose();
  }

  // An overlay of its own over the app, so a toast's tooltips have one.
  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_app, _layer]);

  Widget _place(BuildContext context) {
    final toast = _showing;
    if (toast == null) return const SizedBox.shrink();
    final bottom = widget.atBottom;
    // It slides in from its edge as it fades in, and only fades as it goes.
    final card = AnimatedBuilder(
      animation: _curved,
      builder: (context, child) => Faded(
        opacity: _curved.value,
        child: Transform.translate(
          offset: Offset(
            0,
            _going ? 0 : (bottom ? 12 : -12) * (1 - _curved.value),
          ),
          child: child,
        ),
      ),
      child: IgnorePointer(
        ignoring: _going,
        child: _ToastCard(
          key: toast.key,
          failed: toast.failed,
          child: toast.line,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (bottom) {
          final mq = MediaQuery.of(context);
          return Stack(
            children: [
              Positioned(
                left: 8,
                right: 8,
                bottom: mq.padding.bottom + mq.viewInsets.bottom + 8,
                child: card,
              ),
            ],
          );
        }
        // As wide as the anchor says (narrower in a narrow main area);
        // without one, at most the window less 8 points a side.
        final wide =
            _anchorWidth ??
            max(0.0, min(ToastHost.width, box.maxWidth - 2 * ToastHost.margin));
        // The follower is the stack's own child: it takes pointers where
        // the anchor puts it, not where it's laid out.
        return Stack(
          children: [
            Positioned(
              top: PaneHeader.height + ToastHost.margin,
              left: (box.maxWidth - wide) / 2,
              width: wide,
              child: CompositedTransformFollower(
                link: anchor,
                targetAnchor: Alignment.topCenter,
                followerAnchor: Alignment.topCenter,
                child: card,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Where the window's toasts show: the top of the box it's laid out as,
/// whose width is a toast's (`NoticesPlace` puts it under the header and
/// the bars, inside the main area). Nothing without [Toasts] above it.
class ToastAnchor extends StatefulWidget {
  const new({super.key});

  @override
  State<ToastAnchor> createState() => _ToastAnchorState();
}

class _ToastAnchorState extends State<ToastAnchor> {
  Toasts? _toasts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _toasts = Toasts.maybeOf(context);
  }

  @override
  void dispose() {
    final toasts = _toasts;
    // After the frame: the host's layer isn't built while this goes.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => toasts?._anchored(this, null),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_toasts) {
    final toasts? => CompositedTransformTarget(
      link: toasts.anchor,
      child: _Widths(onWidth: (width) => toasts._anchored(this, width)),
    ),
    null => const SizedBox.shrink(),
  };
}

/// As big as it's let be, telling [onWidth] its width after a frame that
/// changed it: the toast's layer takes it the next.
class _Widths extends SingleChildRenderObjectWidget {
  const new({required this.onWidth});

  final void Function(double width) onWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderWidths(onWidth);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderWidths).onWidth = onWidth;
}

class _RenderWidths extends RenderBox {
  new(this.onWidth);

  void Function(double width) onWidth;
  double? _told;

  @override
  void performLayout() {
    size = constraints.biggest.isFinite ? constraints.biggest : Size.zero;
    if (size.width == _told) return;
    final width = _told = size.width;
    WidgetsBinding.instance.addPostFrameCallback((_) => onWidth(width));
  }
}

class _Toast {
  new(this.key, this.duration, {required this.holds, required this.failed});

  final Key? key;
  final Duration duration;
  final bool holds;
  final bool failed;
  late final Widget line;
}

/// A toast's card: the lifted fill (the failure's soft fill when
/// [failed]), a hairline and the float's shadow, the app's text, said to
/// VoiceOver as it comes.
class _ToastCard extends StatelessWidget {
  const new({required this.child, required this.failed, super.key});

  final Widget child;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    // A layer of its own: it fades over the app as it comes and goes. The
    // float's shadow, as the update card's (floatBox), so it stands off a
    // view, Settings or a dialog under it.
    return RepaintBoundary(
      child: Semantics(
        container: true,
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NushiTheme.card),
            boxShadow: floatShadows(t),
          ),
          child: Material(
            color: failed ? t.crashedSoft : t.lifted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NushiTheme.card),
              side: BorderSide(color: t.line),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: DefaultTextStyle(style: theme.ui(t.text), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A toast's line: [leading] or [icon] (the failure's color when
/// [failed]), [text], then [action] (a primary button) and × ([onClose])
/// when given, from the app's own controls, compact (ADR 0122).
class ToastLine extends StatelessWidget {
  const new(
    this.text, {
    super.key,
    this.icon,
    this.leading,
    this.action,
    this.onClose,
    this.failed = false,
  });

  final IconData? icon;
  final Widget? leading;
  final String text;
  final ToastAction? action;
  final VoidCallback? onClose;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Row(
      spacing: 8,
      children: [
        if (leading case final leading?)
          SizedBox.square(dimension: 16, child: leading)
        else if (icon case final icon?)
          Icon(icon, size: 16, color: failed ? t.crashed : t.textSecondary),
        Expanded(child: Text(text)),
        if (action case final action?)
          // The accent's fill: a plain button's lifted fill is the card's
          // own, and its action would read as a word, not a button.
          ControlScale.compact(
            child: Button(
              label: action.label,
              onPressed: action.onPressed,
              kind: ButtonKind.primary,
            ),
          ),
        if (onClose case final close?)
          IconTap(Icons.close, size: 14, tooltip: 'Dismiss', onTap: close),
      ],
    );
  }
}
