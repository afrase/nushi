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
import 'package:nushi/native.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/web_views.dart';
import 'package:nushi/window_drag.dart';

// The phone's native edge in a VM test: it has none (the web app never sets
// `native`, ADR 0097), so a phone test that reaches a native call fails
// there as it would in the browser. The VM runs the desktop side of each
// kIsWeb guard, so the few reads the shared widgets make behind one answer
// what the guard answers on the web: the phone's conventions, no window
// to move, no embedded web views, no speller.

/// A [Native] whose every capability throws when the phone reaches it,
/// read or called.
class PhoneNative extends Native {
  new()
    : super(
        alerts: _Refused<AlertCenter>(),
        clipboard: _Refused<ClipboardFiles>(),
        conventions: phoneHost.withKey(CommandKey.meta),
        desktop: _Refused<Desktop>(),
        fileModes: _Refused<FileModes>(),
        fonts: _Refused<Fonts>(),
        install: _Refused<AppInstall>(),
        loginItem: _Refused<LoginItem>(),
        web: _NoWebViews(),
        window: _NoWindow(),
      );

  @override
  Conventions get conventions => phoneHost.withKey(CommandKey.meta);

  @override
  AlertCenter get alerts => _refuse('alerts');

  @override
  ClipboardFiles get clipboard => _refuse('clipboard');

  @override
  Desktop get desktop => _refuse('desktop');

  @override
  FileModes get fileModes => _refuse('fileModes');

  @override
  Fonts get fonts => _refuse('fonts');

  @override
  AppInstall get install => _refuse('install');

  @override
  LoginItem get loginItem => _refuse('loginItem');

  @override
  Diagrams? get diagrams => _refuse('diagrams');

  @override
  PageSwipes? get swipes => _refuse('swipes');

  @override
  Speller? get speller => null;
}

Never _refuse(String what) =>
    throw StateError('the phone reached native.$what: it has no native edge');

/// A capability the phone hasn't, for Native's constructor: whatever is
/// asked of it throws.
class _Refused<T>
    implements
        AlertCenter,
        ClipboardFiles,
        Desktop,
        FileModes,
        Fonts,
        AppInstall,
        LoginItem {
  @override
  Never noSuchMethod(Invocation invocation) =>
      _refuse('$T.${_name(invocation)}');
}

/// The window as `headersMoveWindow` answers on the web: none to move.
class _NoWindow implements AppWindow {
  @override
  bool get headersMoveWindow => false;

  @override
  Never noSuchMethod(Invocation invocation) =>
      _refuse('window.${_name(invocation)}');
}

/// The web views as `webEmbedded` answers on the web: none of the app's own.
class _NoWebViews implements WebViews {
  @override
  bool get embedded => false;

  @override
  Never noSuchMethod(Invocation invocation) =>
      _refuse('web.${_name(invocation)}');
}

String _name(Invocation i) =>
    i.memberName.toString().replaceAll('Symbol("', '').replaceAll('")', '');
