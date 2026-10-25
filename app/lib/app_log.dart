import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// The app's log (ADR 0038): its errors with their stacks, and what helps
/// afterwards (starting, connecting, an outdated daemon, restarts). Lines
/// go to the daemon's log (Log) while it answers, else to app.log in the
/// data folder, in the daemon's format, rotated as the daemon rotates its
/// own. Never message text or anything else the user wrote.
final appLog = AppLog('$dataDir/app.log');

/// The API version with Log.
const _logApi = 51;

class AppLog {
  new(this.path);

  final String path;

  /// The daemon, once there is one: lines go there while it has Log.
  NushiServiceClient? client;
  bool Function() reachable = () => false;

  /// How large app.log grows before it rotates, and how many older copies
  /// stay (as the daemon's `logs.MaxSize`, `logs.Keep`).
  int maxSize = 10 << 20;
  static const keep = 2;

  // At most _burst lines, then one every _every: an error each frame
  // can't flood the log. What's dropped is counted on the next line.
  static const _burst = 20;
  static const _every = Duration(seconds: 3);
  double _tokens = _burst.toDouble();
  DateTime _last = DateTime.now();
  int _dropped = 0;

  void info(String message, [Map<String, String> attrs = const {}]) =>
      write('info', message, attrs: attrs);

  void warn(String message, [Map<String, String> attrs = const {}]) =>
      write('warn', message, attrs: attrs);

  void error(
    String message,
    Object error,
    StackTrace? stack, [
    String from = 'zone',
  ]) => write(
    'error',
    message,
    stack: '${stack ?? ''}',
    attrs: {'from': from, 'err': '$error'},
  );

  Future<void> write(
    String level,
    String message, {
    String stack = '',
    Map<String, String> attrs = const {},
  }) async {
    final now = DateTime.now();
    _tokens =
        (_tokens + now.difference(_last).inMilliseconds / _every.inMilliseconds)
            .clamp(0, _burst.toDouble());
    _last = now;
    if (_tokens < 1) {
      _dropped++;
      return;
    }
    _tokens--;
    final all = {...attrs, if (_dropped > 0) 'dropped': '$_dropped'};
    _dropped = 0;
    if (client case final client? when reachable()) {
      try {
        await client
            .log(
              LogRequest(
                level: level,
                message: message,
                stack: stack,
                attrs: all.entries,
              ),
            )
            .timeout(const Duration(seconds: 2));
        return;
      } on Object {
        // to the file
      }
    }
    _toFile(now, level, message, {
      'source': 'app',
      ...all,
      if (stack.isNotEmpty) 'stack': stack,
    });
  }

  void _toFile(
    DateTime t,
    String level,
    String message,
    Map<String, String> attrs,
  ) {
    try {
      final f = File(path)..parent.createSync(recursive: true);
      if (f.existsSync() && f.lengthSync() > maxSize) {
        for (var i = keep; i > 1; i--) {
          final older = File('$path.${i - 1}');
          if (older.existsSync()) older.renameSync('$path.$i');
        }
        f.renameSync('$path.1');
      }
      final line = StringBuffer(
        'time=${timestamp(t)} level=${level.toUpperCase()} '
        'msg=${quote(message)}',
      );
      attrs.forEach((k, v) => line.write(' $k=${quote(v)}'));
      f.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } on Object catch (e) {
      debugPrint('app.log: $e');
    }
  }
}

/// [t] as Go's slog writes it: 2026-10-25T15:16:55.513+09:00.
String timestamp(DateTime t) {
  String two(int n) => '$n'.padLeft(2, '0');
  final o = t.timeZoneOffset;
  final sign = o.isNegative ? '-' : '+';
  final date = '${t.year}-${two(t.month)}-${two(t.day)}';
  final time = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  final ms = '${t.millisecond}'.padLeft(3, '0');
  final zone = '$sign${two(o.inHours.abs())}:${two(o.inMinutes.abs() % 60)}';
  return '${date}T$time.$ms$zone';
}

/// [s] as Go's slog text format writes a value: bare when it can be, else
/// quoted with Go's escapes.
String quote(String s) {
  if (s.isNotEmpty && !RegExp(r'[\s"=\\\x00-\x1f\x7f]').hasMatch(s)) return s;
  final b = StringBuffer('"');
  for (final r in s.runes) {
    b.write(switch (r) {
      0x22 => r'\"',
      0x5c => r'\\',
      0x0a => r'\n',
      0x0d => r'\r',
      0x09 => r'\t',
      < 0x20 || 0x7f => '\\x${r.toRadixString(16).padLeft(2, '0')}',
      _ => String.fromCharCode(r),
    });
  }
  return '$b"';
}

/// Sends what the app doesn't catch to [appLog]: Flutter's errors
/// (building, layout, painting), the platform's (an async error nobody
/// awaited), and the zone's, each with its stack.
void catchErrors() {
  final present = FlutterError.onError;
  FlutterError.onError = (d) {
    present?.call(d);
    unawaited(
      appLog.write(
        'error',
        d.exceptionAsString(),
        stack: '${d.stack ?? ''}',
        attrs: {
          'from': 'flutter',
          'library': ?d.library,
          'context': ?d.context?.toDescription(),
        },
      ),
    );
  };
  PlatformDispatcher.instance.onError = (e, s) {
    appLog.error('uncaught error', e, s, 'platform');
    return true;
  };
}

/// The app's version from its bundle (Info.plist), "" outside one.
final String appVersion = () {
  try {
    final plist = File(
      '${File(Platform.resolvedExecutable).parent.parent.path}/Info.plist',
    ).readAsStringSync();
    String key(String k) =>
        RegExp('<key>$k</key>\\s*<string>([^<]*)</string>')
            .firstMatch(plist)
            ?.group(1) ??
        '';
    return '${key('CFBundleShortVersionString')}+${key('CFBundleVersion')}';
  } on Object {
    return '';
  }
}();

/// Whether the daemon has Log.
bool hasLog(int daemonApi) => daemonApi >= _logApi;
