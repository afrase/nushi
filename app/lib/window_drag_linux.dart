import 'package:nushi/window_drag.dart';

/// Linux's window, which keeps the system's title bar (ADR 0102): it moves
/// and zooms the window, so a header does neither, and there's no menu bar
/// for the app's menus.
class LinuxWindow implements AppWindow {
  const new();

  @override
  bool get menuBar => false;

  @override
  Future<void> arm(int micros) async {}

  @override
  Future<void> zoom() async {}
}
