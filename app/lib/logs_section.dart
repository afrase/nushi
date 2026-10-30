import 'dart:io';

import 'package:flutter/material.dart';

import 'package:nushi/app_log.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/commits.dart' show dateTime;
import 'package:nushi/daemon.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/widgets.dart';

/// Reveals the daemon's log (nushid.log, app.log beside it) in Finder.
Future<void> showLogs() async {
  final log = '$dataDir/nushid.log';
  await Process.run(
    '/usr/bin/open',
    File(log).existsSync() ? ['-R', log] : [dataDir],
  );
}

/// When a daemon build (`<size>-<mtime in ms>`) was made, if it says.
DateTime? buildTime(String build) => switch (int.tryParse(
  build.split('-').last,
)) {
  final ms? when build.contains('-') => DateTime.fromMillisecondsSinceEpoch(ms),
  _ => null,
};

/// Settings › Logs & advanced: Show logs, whether the daemon's log has
/// DEBUG lines ([debug] null: the daemon didn't say, so no switch), and the
/// daemon: its release, its API, its build, and Restart (the packaged
/// app's).
class LogsSection extends StatelessWidget {
  const new({
    required this.daemon,
    required this.debug,
    required this.onDebug,
    super.key,
    this.reveal = showLogs,
  });

  final Daemon daemon;
  final bool? debug;
  final ValueChanged<bool> onDebug;
  final Future<void> Function() reveal;

  Future<void> _restart(BuildContext context) async {
    if (await confirm(
          context,
          'Restart the daemon?',
          'Running turns stop and terminals close; chats reopen as you '
              'open them.',
          'Restart',
        ) &&
        context.mounted) {
      await tryOrShow(context, daemon.restartDaemon);
    }
  }

  @override
  Widget build(BuildContext context) {
    final built = buildTime(daemon.daemonBuild);
    return SettingsPage(
      title: 'Logs & advanced',
      children: [
        SettingsGroup(
          title: 'Logs',
          children: [
            SettingsRow(
              'Logs',
              description: 'nushid.log, and app.log beside it.',
              control: Button(label: 'Show logs', onPressed: reveal),
            ),
            if (debug case final on?)
              SettingsRow(
                'Debug lines',
                description: 'Every agent and API call, with timings.',
                control: SettingsSwitch(value: on, onChanged: onDebug),
              ),
          ],
        ),
        ListenableBuilder(
          listenable: daemon,
          builder: (context, _) => SettingsGroup(
            title: 'Daemon',
            children: [
              SettingsRow(
                'Daemon',
                description: [
                  if (daemon.daemonVersion.isNotEmpty)
                    'Version ${daemon.daemonVersion}',
                  'API ${daemon.daemonApi}',
                  if (built != null) 'built ${dateTime(built)}',
                  if (daemon.replaced) 'a newer one is installed',
                ].join(' · '),
                control: bundledDaemon == null
                    ? null
                    : Button(
                        label: daemon.restarting ? 'Restarting…' : 'Restart…',
                        onPressed: daemon.restarting
                            ? null
                            : () => _restart(context),
                      ),
              ),
              if (appVersion.isNotEmpty)
                SettingsRow('App', description: 'Version $appVersion'),
            ],
          ),
        ),
      ],
    );
  }
}
