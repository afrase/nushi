import 'package:flutter/services.dart';

import 'package:nushi/window_drag.dart';

const _channel = MethodChannel('nushi/window');

/// The Mac's window, moved and zoomed by AppKit
/// (`macos/Runner/TitleBar.swift`'s HeaderDrag) from the headers, which
/// run under its title bar.
class MacWindow implements AppWindow {
  const new();

  /// Past the traffic lights, which stay where macOS puts them (ADR 0080).
  @override
  double get titleInset => 84;

  @override
  bool get headersMoveWindow => true;

  @override
  bool get menuBar => true;

  /// The Swift side already brings the app forward when a notification is
  /// clicked (`macos/Runner/Alerts.swift`), and nothing else asks.
  @override
  Future<void> present({String? token}) async {}

  @override
  Future<void> arm(int micros) => _channel.invokeMethod<void>('arm', micros);

  @override
  Future<void> zoom() => _channel.invokeMethod<void>('zoom');
}
