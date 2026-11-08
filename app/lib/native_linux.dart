import 'package:nushi/alerts_linux.dart';
import 'package:nushi/app_install_linux.dart';
import 'package:nushi/back_swipe_linux.dart';
import 'package:nushi/clipboard_files_linux.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/desktop_linux.dart';
import 'package:nushi/file_mode_linux.dart';
import 'package:nushi/fonts_linux.dart';
import 'package:nushi/login_item_linux.dart';
import 'package:nushi/mermaid_linux.dart';
import 'package:nushi/native.dart';
import 'package:nushi/session_bus_linux.dart';
import 'package:nushi/speller_linux.dart';
import 'package:nushi/web_views_linux.dart';
import 'package:nushi/window_drag_linux.dart';

/// Linux's implementation of each native capability (ADR 0097, 0102), each
/// over GTK's runner in `linux/runner`, D-Bus, libc or a library of the
/// desktop's (enchant, whose dictionary in the user's language makes the
/// speller, none without it).
Native linuxNative() => Native(
  alerts: LinuxAlertCenter(sessionBus, const LinuxWindow()),
  clipboard: const LinuxClipboardFiles(),
  conventions: linuxConventions,
  desktop: const LinuxDesktop(),
  diagrams: const LinuxDiagrams(),
  fileModes: const LinuxFileModes(),
  fonts: const LinuxFonts(),
  install: LinuxAppInstall(),
  loginItem: LinuxLoginItem(),
  swipes: const LinuxPageSwipes(),
  web: const LinuxWebViews(),
  window: const LinuxWindow(),
  speller: LinuxSpeller.open(),
);
