import 'package:flutter/services.dart';

import 'package:nushi/window_drag.dart';

const _channel = MethodChannel('nushi/window');

/// The Mac's window, moved and zoomed by AppKit
/// (`macos/Runner/TitleBar.swift`'s HeaderDrag).
class MacWindow implements AppWindow {
  const new();

  @override
  bool get menuBar => true;

  @override
  Future<void> arm(int micros) => _channel.invokeMethod<void>('arm', micros);

  @override
  Future<void> zoom() => _channel.invokeMethod<void>('zoom');
}
