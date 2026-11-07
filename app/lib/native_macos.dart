import 'package:nushi/alerts_macos.dart';
import 'package:nushi/back_swipe_macos.dart';
import 'package:nushi/login_item_macos.dart';
import 'package:nushi/native.dart';
import 'package:nushi/speller_macos.dart';
import 'package:nushi/window_drag_macos.dart';

/// The Mac's implementation of each native capability (ADR 0097), each
/// over its Swift side in `macos/Runner`.
Native macosNative() => Native(
  alerts: const MacAlertCenter(),
  loginItem: const MacLoginItem(),
  swipes: const MacPageSwipes(),
  window: const MacWindow(),
  speller: const MacSpeller(),
);
