import 'package:flutter/services.dart';

import 'package:nushi/back_swipe.dart';

/// The Mac's three-finger swipe between pages, an `NSEvent` swipe the
/// window sends over `nushi/swipe` (`macos/Runner/MainFlutterWindow.swift`).
class MacPageSwipes implements PageSwipes {
  const new();

  @override
  void onBack(void Function(Offset at) back) =>
      const MethodChannel('nushi/swipe').setMethodCallHandler((call) async {
        if ((call.method, call.arguments) case (
          'back',
          [final num x, final num y],
        )) {
          back(Offset(x.toDouble(), y.toDouble()));
        }
      });
}
