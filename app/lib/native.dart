import 'package:nushi/alerts.dart';
import 'package:nushi/back_swipe.dart';
import 'package:nushi/clipboard_files.dart';
import 'package:nushi/fonts.dart';
import 'package:nushi/login_item.dart';
import 'package:nushi/mermaid.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/window_drag.dart';

/// The app's native edge (ADR 0097): what it asks of the machine it runs
/// on, each capability an interface declared beside what uses it, and a
/// platform's implementations in files of their own (the Mac's are
/// `*_macos.dart`, the only files that may hold platform channels, WebKit's
/// plugin or FFI: `tools/native-edge` checks). main.dart sets [native]
/// once at startup (`macosNative`); each test starts from the same
/// (`flutter_test_config.dart`) and puts a fake in a capability's place.
/// The phone's web app reaches none of it.
class Native {
  new({
    required this.alerts,
    required this.clipboard,
    required this.diagrams,
    required this.fonts,
    required this.loginItem,
    required this.swipes,
    required this.window,
    this.speller,
  });

  /// Notifications and the app icon's badge.
  AlertCenter alerts;

  /// The clipboard's files and picture, for ⌘V.
  ClipboardFiles clipboard;

  /// Mermaid diagrams drawn as pictures.
  Diagrams diagrams;

  /// The installed fonts.
  Fonts fonts;

  /// What starts the daemon at login.
  LoginItem loginItem;

  /// The system's swipe back between pages.
  PageSwipes swipes;

  /// The window, moved and zoomed from a header.
  AppWindow window;

  /// The spell checker, where there's one (ADR 0083).
  Speller? speller;
}

/// The native edge main.dart chose.
late Native native;
