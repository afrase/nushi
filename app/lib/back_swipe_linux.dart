import 'package:flutter/widgets.dart';

import 'package:nushi/back_swipe.dart';

/// Linux has no swipe of its own beyond what Flutter sees: GTK sends a
/// touchpad's two-finger pans, and the mouse's back button, to the engine,
/// which [BackSwipe] already takes.
class LinuxPageSwipes implements PageSwipes {
  const new();

  @override
  void onBack(void Function(Offset at) back) {}
}
