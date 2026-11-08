import 'package:flutter/services.dart';

import 'package:nushi/window_drag.dart';

const _channel = MethodChannel('nushi/window');

/// Linux's window, which keeps the system's title bar (ADR 0102): it moves
/// and zooms the window, so a header does neither, and there's no menu bar
/// for the app's menus. The runner's `nushi/window`
/// (`linux/runner/window.cc`) presents it.
class LinuxWindow implements AppWindow {
  const new();

  /// The title bar is above the content, so nothing is in the way: the
  /// button that shows the sidebar keeps a header's margin.
  @override
  double get titleInset => 8;

  @override
  bool get headersMoveWindow => false;

  @override
  bool get menuBar => false;

  @override
  Future<void> present({String? token}) =>
      _channel.invokeMethod<void>('present', {'token': ?token});

  @override
  Future<void> arm(int micros) async {}

  @override
  Future<void> zoom() async {}
}
