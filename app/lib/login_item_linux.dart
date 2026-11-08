import 'dart:convert';
import 'dart:io';

import 'package:nushi/app_install.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/login_item.dart';
import 'package:nushi/native.dart';

/// What starts the daemon at login on Linux (ADR 0102): an XDG autostart
/// entry, `$XDG_CONFIG_HOME/autostart/com.nushihq.Nushi.daemon.desktop`
/// (`~/.config` unless that's an absolute path), which the desktop session
/// runs as you log in, with the session's environment, as the Mac's
/// launch agent does: `nushid -login` from the installed package. It's
/// there while on, written whole (0600), and removed to turn it off. An
/// entry naming a nushid that's gone (the package moved or removed) is
/// off; turning it on writes it anew.
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

  LoginItemState _state() {
    final String text;
    try {
      text = file.readAsStringSync();
    } on FileSystemException {
      return LoginItemState.off;
    }
    return autostartOn(text) ? LoginItemState.on : LoginItemState.off;
  }

  @override
  Future<LoginItemState?> set({required bool on}) async {
    if (!on) {
      if (file.existsSync()) file.deleteSync();
    } else if ((install ?? native.install).daemon case final daemon?) {
      file.parent.createSync(recursive: true);
      writeWhole(file, utf8.encode(autostartEntry(daemon)));
    }
    return _state();
  }

  /// No system settings hold it: the switch is the whole of it.
  @override
  Future<LoginItemState?> openSettings() => status();
}

/// The autostart entry that runs [daemon] with `-login` (the desktop entry
/// spec's keys; GNOME's own to say it's on).
String autostartEntry(String daemon) =>
    '''
[Desktop Entry]
Type=Application
Name=Nushi daemon
Exec=${execValue([daemon, '-login'])}
NoDisplay=true
X-GNOME-Autostart-enabled=true
''';

/// Whether an autostart entry's text starts a nushid that's there: its
/// Exec's program is a file named nushid, and neither `Hidden` nor GNOME's
/// switch turns it off.
bool autostartOn(String text) {
  String? key(String k) => RegExp(
    '^${RegExp.escape(k)}=(.*)\$',
    multiLine: true,
  ).firstMatch(text)?.group(1)?.trim();
  if (key('Hidden') == 'true' || key('X-GNOME-Autostart-enabled') == 'false') {
    return false;
  }
  final program = execProgram(key('Exec') ?? '');
  return program != null &&
      program.endsWith('/nushid') &&
      File(program).existsSync();
}

/// [args] as a desktop entry's Exec value: each argument quoted when it
/// has a character the spec reserves (`"`, `` ` ``, `$` and `\` escaped
/// inside the quotes), `%` doubled (a field code otherwise), then the
/// value's own escape of `\`, which the spec applies before the quoting:
/// a backslash in a path is four. A path with a control character can't
/// be written.
String execValue(List<String> args) => args
    .map((a) {
      if (a.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
        throw ArgumentError.value(a, 'args', 'has a control character');
      }
      final arg = a.replaceAll('%', '%%');
      if (!arg.contains(_reserved)) return arg;
      final escaped = arg.replaceAllMapped(_quoted, (m) => '\\${m[0]}');
      return '"$escaped"';
    })
    .join(' ')
    .replaceAll(r'\', r'\\');

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
  if (!s.startsWith('"')) return s.split(' ').first.replaceAll('%%', '%');
  final out = StringBuffer();
  for (var i = 1; i < s.length; i++) {
    switch (s[i]) {
      case '"':
        return out.toString().replaceAll('%%', '%');
      case r'\' when i + 1 < s.length:
        out.write(s[++i]);
      default:
        out.write(s[i]);
    }
  }
  return null;
}
