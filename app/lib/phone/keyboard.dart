import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// How much of the app's box the on-screen keyboard covers, in logical
/// pixels: the part of the box below what the browser shows. iOS's
/// keyboard (and its form bar, ˄ ˅ ✓) shrinks the visual viewport only;
/// the app's box stays the layout viewport's, its bottom under the
/// keyboard. [appBottom] is the box's bottom and [viewportTop] the visual
/// viewport's top, both from the layout viewport's top.
double keyboardInset({
  required double appBottom,
  required double viewportTop,
  required double viewportHeight,
}) {
  final covered = appBottom - (viewportTop + viewportHeight);
  // Less than a pixel is rounding, not a keyboard.
  return covered < 1 ? 0 : covered.roundToDouble();
}

/// Gives what's below it the keyboard's height as the bottom view inset,
/// as a native app gets it: a Scaffold's body shrinks above it, a dialog
/// or a sheet moves up. Flutter's web engine does it itself only when it
/// owns the whole page; the phone's app draws into a box of its own
/// (`#app`, inside the safe area), for which it reports none. A text field
/// scrolls itself into view when the view's own inset grows, which this
/// one isn't: the focused field is brought into view here instead.
class KeyboardInset extends StatefulWidget {
  const new(this.inset, {required this.child, super.key});

  /// The keyboard's height over the app's box.
  final ValueListenable<double> inset;
  final Widget child;

  @override
  State<KeyboardInset> createState() => _KeyboardInsetState();
}

class _KeyboardInsetState extends State<KeyboardInset> {
  double _last = 0;

  @override
  void initState() {
    super.initState();
    _last = widget.inset.value;
    widget.inset.addListener(_changed);
  }

  @override
  void didUpdateWidget(KeyboardInset old) {
    super.didUpdateWidget(old);
    if (old.inset != widget.inset) {
      old.inset.removeListener(_changed);
      widget.inset.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.inset.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final grew = widget.inset.value > _last;
    _last = widget.inset.value;
    setState(() {});
    if (!grew) return;
    // After the layout above the keyboard: the field being typed in shows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = FocusManager.instance.primaryFocus?.context
          ?.findRenderObject();
      // With room around it, as a text field scrolls itself (its
      // scrollPadding).
      if (box != null && box.attached) {
        box.showOnScreen(rect: box.paintBounds.inflate(20));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = widget.inset.value;
    final mq = MediaQuery.of(context);
    if (bottom <= mq.viewInsets.bottom) return widget.child;
    return MediaQuery(
      data: mq.copyWith(
        viewInsets: mq.viewInsets.copyWith(bottom: bottom),
        // What the keyboard covers needs no padding (the framework's own
        // rule for view insets).
        padding: mq.padding.copyWith(
          bottom: math.max(0, mq.padding.bottom - bottom),
        ),
      ),
      child: widget.child,
    );
  }
}
