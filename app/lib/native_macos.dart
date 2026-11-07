import 'package:nushi/alerts_macos.dart';
import 'package:nushi/back_swipe_macos.dart';
import 'package:nushi/clipboard_files_macos.dart';
import 'package:nushi/desktop_macos.dart';
import 'package:nushi/file_mode_macos.dart';
import 'package:nushi/fonts_macos.dart';
import 'package:nushi/login_item_macos.dart';
import 'package:nushi/mermaid_macos.dart';
import 'package:nushi/native.dart';
import 'package:nushi/speller_macos.dart';
import 'package:nushi/web_views_macos.dart';
import 'package:nushi/window_drag_macos.dart';

/// The Mac's implementation of each native capability (ADR 0097), each
/// over its Swift side in `macos/Runner`.
Native macosNative() => Native(
  alerts: const MacAlertCenter(),
  clipboard: const MacClipboardFiles(),
  desktop: const MacDesktop(),
  diagrams: const MacDiagrams(),
  fileModes: const MacFileModes(),
  fonts: const MacFonts(),
  loginItem: const MacLoginItem(),
  swipes: const MacPageSwipes(),
  web: const MacWebViews(),
  window: const MacWindow(),
  speller: const MacSpeller(),
);
