import 'package:nushi/alerts.dart';
import 'package:nushi/app_install.dart';
import 'package:nushi/back_swipe.dart';
import 'package:nushi/clipboard_files.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/desktop.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/fonts.dart';
import 'package:nushi/login_item.dart';
import 'package:nushi/mermaid.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/web_views.dart';
import 'package:nushi/window_drag.dart';

/// The app's native edge (ADR 0097, 0104): what it asks of the machine it
/// runs on, each capability an interface declared beside what uses it, and
/// each platform's implementations in files of their own (`*_macos.dart`
/// and `*_linux.dart`, the only files that may hold platform channels or
/// FFI; WebKit's plugin only the Mac's, dbus only Linux's:
/// `tools/native-edge` checks). main.dart sets [native] once at startup
/// (`linuxNative` on Linux, else `macosNative`); each test starts from the
/// Mac's (`flutter_test_config.dart`) and puts a fake in a capability's
/// place. The phone's web app reaches none of it.
class Native {
  new({
    required this.alerts,
    required this.clipboard,
    required this.conventions,
    required this.desktop,
    required this.diagrams,
    required this.fileModes,
    required this.fonts,
    required this.install,
    required this.loginItem,
    required this.swipes,
    required this.web,
    required this.window,
    this.speller,
  });

  /// Notifications and the app icon's badge.
  AlertCenter alerts;

  /// The clipboard's files and picture, for ⌘V.
  ClipboardFiles clipboard;

  /// What the platform names differently, and its shortcuts' modifier
  /// (widgets read `conventions`, which the phone has too).
  Conventions conventions;

  /// The file manager and default apps.
  Desktop desktop;

  /// Mermaid diagrams drawn as pictures.
  Diagrams diagrams;

  /// The user's files made theirs only.
  FileModes fileModes;

  /// The installed fonts.
  Fonts fonts;

  /// The installed app: its data folder, version and daemon.
  AppInstall install;

  /// What starts the daemon at login.
  LoginItem loginItem;

  /// The system's swipe back between pages.
  PageSwipes swipes;

  /// The web views, and the default browser.
  WebViews web;

  /// The window, moved and zoomed from a header.
  AppWindow window;

  /// The spell checker, where there's one (ADR 0083).
  Speller? speller;
}

/// The native edge main.dart chose.
late Native native;
