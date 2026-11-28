import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:nushi/app_log.dart';

/// The file editor's scrolling down, never above its start. re_editor's
/// layout calls itself again while its first line lies below the scroll
/// offset, which a negative offset makes true for ever: the stack
/// overflows at every frame, the text is never drawn and the window stops
/// answering (the owner's app log, 2026-11-27, with a find open; a test
/// shows it with a jump to -5). Physics keep a drag and a glide inside the
/// range, but a jump and a correction pass them by, and re_editor makes
/// both; so the position itself refuses an offset below zero, whoever
/// asks, and says in the app's log who did (the first few times: how it
/// was asked and the stack, never the file or its text).
class FlooredScroll extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _Floored(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

/// How many times an offset below zero was refused, for tests.
@visibleForTesting
int flooredAsks = 0;

class _Floored extends ScrollPositionWithSingleContext {
  new({
    required super.physics,
    required super.context,
    super.oldPosition,
    super.debugLabel,
  });

  static const _told = 5;

  double _floor(double value, String how) {
    if (value >= 0 || value.isNaN) return value.isNaN ? 0 : value;
    if (flooredAsks++ < _told) {
      unawaited(
        appLog.write(
          'warn',
          "the editor's scroll was asked below its start",
          stack: '${StackTrace.current}',
          attrs: {'how': how, 'by': value.toStringAsFixed(2)},
        ),
      );
    }
    return 0;
  }

  @override
  double setPixels(double newPixels) =>
      super.setPixels(_floor(newPixels, 'setPixels'));

  @override
  void correctPixels(double value) =>
      super.correctPixels(_floor(value, 'correctPixels'));

  @override
  void correctBy(double correction) =>
      super.correctPixels(_floor(pixels + correction, 'correctBy'));

  @override
  void forcePixels(double value) =>
      super.forcePixels(_floor(value, 'forcePixels'));

  @override
  void jumpTo(double value) => super.jumpTo(_floor(value, 'jumpTo'));
}
