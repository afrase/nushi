import 'dart:convert';
import 'dart:io';

import 'package:nushi/app_install.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/login_item.dart';
import 'package:nushi/native.dart';

/// What starts the daemon at login on Linux (ADR 0104): an XDG autostart
/// entry, `$XDG_CONFIG_HOME/autostart/com.nushihq.Nushi.daemon.desktop`
/// (`~/.config` unless that's an absolute path), which the desktop session
/// runs as you log in, with the session's environment, as the Mac's
/// launch agent does: `nushid -login` from the installed package. It's
/// there while on, written whole (0600), and removed to turn it off. An
/// entry naming another nushid than this package's (a copy the user kept,
/// or one moved or removed) is off; turning it on writes it anew.
class LinuxLoginItem implements LoginItem {
  /// A test passes the package whose daemon the entry starts ([install],
  /// else the app's) and the [environment] the config folder comes from.
  new({this.install, Map<String, String>? environment})
    : _env = environment ?? Platform.environment;

  /// The package a test gives, in the app's place.
  final AppInstall? install;
  final Map<String, String> _env;

  /// The entry's file.
  File get file {
    final config = switch (_env['XDG_CONFIG_HOME']) {
      final xdg? when xdg.startsWith('/') => xdg,
      _ => '${_env['HOME']}/.config',
    };
    return File('$config/autostart/com.nushihq.Nushi.daemon.desktop');
  }

  @override
  Future<LoginItemState?> status() async => _state();

  /// The package's daemon, null when the app runs from none.
  String? get _daemon => (install ?? native.install).daemon;

  LoginItemState _state() {
    final String text;
    try {
      text = file.readAsStringSync();
    } on FileSystemException {
      return LoginItemState.off;
    }
    return switch (_daemon) {
      final daemon? when autostartOn(text, daemon) => LoginItemState.on,
      _ => LoginItemState.off,
    };
  }

  @override
  Future<LoginItemState?> set({required bool on}) async {
    if (!on) {
      if (file.existsSync()) file.deleteSync();
    } else if (_daemon case final daemon?) {
      // A package path no entry can start stays off.
      if (autostartEntry(daemon) case final entry?) {
        file.parent.createSync(recursive: true);
        writeWhole(file, utf8.encode(entry));
      }
    }
    return _state();
  }

  /// No system settings hold it: the switch is the whole of it.
  @override
  Future<LoginItemState?> openSettings() => status();
}

/// The autostart entry that runs [daemon] with `-login` (the desktop entry
/// spec's keys; GNOME's own to say it's on), null when its path can't be
/// an Exec's (see [execValue]).
String? autostartEntry(String daemon) {
  final exec = execValue([daemon, '-login']);
  if (exec == null) return null;
  return '''
[Desktop Entry]
Type=Application
Name=Nushi daemon
Exec=$exec
NoDisplay=true
X-GNOME-Autostart-enabled=true
''';
}

/// Whether an autostart entry's text starts [daemon], this package's
/// nushid, while it's there: its Exec's program is that file, and neither
/// `Hidden` nor GNOME's switch turns it off.
bool autostartOn(String text, String daemon) {
  String? key(String k) => RegExp(
    '^${RegExp.escape(k)}=(.*)\$',
    multiLine: true,
  ).firstMatch(text)?.group(1)?.trim();
  if (key('Hidden') == 'true' || key('X-GNOME-Autostart-enabled') == 'false') {
    return false;
  }
  return execProgram(key('Exec') ?? '') == daemon && File(daemon).existsSync();
}

/// [args] as a desktop entry's Exec value: each argument quoted when it
/// has a character the spec reserves (`"`, `` ` ``, `$` and `\` escaped
/// inside the quotes), then the value's own escape of `\`, which the spec
/// applies before the quoting: a backslash in a path is four. Null when
/// an argument has a control character, which a line can't hold, or a
/// `%`: the spec doubles it, but GLib looks for the program before it
/// undoes that, finds none, and won't load the entry (GLib 2.90).
String? execValue(List<String> args) {
  if (args.any(_unwritable.hasMatch)) return null;
  return args
      .map((arg) {
        if (!arg.contains(_reserved)) return arg;
        final escaped = arg.replaceAllMapped(_quoted, (m) => '\\${m[0]}');
        return '"$escaped"';
      })
      .join(' ')
      .replaceAll(r'\', r'\\');
}

/// What no Exec argument [execValue] writes may hold.
final _unwritable = RegExp(r'[\x00-\x1f\x7f%]');

/// What a quoted Exec argument escapes.
final _quoted = RegExp(r'["`$\\]');

/// The characters the desktop entry spec says an Exec argument is quoted
/// for.
final _reserved = RegExp(r'''[\s"'\\><~|&;$*?#()`]''');

/// An Exec value's program, read back as [execValue] writes it: the
/// value's escapes undone, then the first argument unquoted; null when
/// the quoting is broken.
String? execProgram(String value) {
  final s = value.replaceAllMapped(
    RegExp(r'\\(.)'),
    (m) => switch (m[1]) {
      's' => ' ',
      'n' => '\n',
      't' => '\t',
      'r' => '\r',
      _ => m[1]!,
    },
  );
  if (!s.startsWith('"')) return s.split(' ').first;
  final out = StringBuffer();
  for (var i = 1; i < s.length; i++) {
    switch (s[i]) {
      case '"':
        return out.toString();
      case r'\' when i + 1 < s.length:
        out.write(s[++i]);
      default:
        out.write(s[i]);
    }
  }
  return null;
}
