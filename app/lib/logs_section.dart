import 'dart:io';

import 'package:flutter/material.dart';

import 'package:nushi/app_install.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/commits.dart' show dateTime;
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_settings.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/status_bar.dart' show restartDaemonAsking;
import 'package:nushi/widgets.dart';

/// Reveals the daemon's log (nushid.log, app.log beside it) in the file
/// manager.
Future<void> showLogs() async {
  final log = '$dataDir/nushid.log';
  await (File(log).existsSync()
      ? native.desktop.reveal(log)
      : native.desktop.openFolder(dataDir));
}

/// Settings › Logs & advanced: Show logs, whether the daemon's log has
/// DEBUG lines (a switch once [settings] came), and the daemon: its
/// release, its API, its build, and Restart (the packaged app's).
class LogsSection extends StatelessWidget {
  const new({
    required this.daemon,
    required this.settings,
    super.key,
    this.reveal = showLogs,
  });

  final Daemon daemon;
  final DaemonSettings settings;
  final Future<void> Function() reveal;

  @override
  Widget build(BuildContext context) {
    final built = buildTime(daemon.daemonBuild);
    // One group: a group of each was a heading over a row or two.
    return SettingsPage(
      title: 'Logs & advanced',
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([daemon, settings]),
          builder: (context, _) => SettingsGroup(
            children: [
              SettingsRow(
                'Logs',
                description: 'nushid.log, and app.log beside it.',
                control: Button(label: 'Show logs', onPressed: reveal),
              ),
              if (settings.value?.debugLog case final on?)
                SettingsRow(
                  'Debug lines',
                  description: 'Every agent and API call, with timings.',
                  control: SettingsSwitch(
                    value: on,
                    run: ({required on}) =>
                        settings.change((s) => s.debugLog = on),
                  ),
                ),
              SettingsRow(
                'Daemon',
                description: [
                  if (daemon.daemonVersion.isNotEmpty)
                    'Version ${daemon.daemonVersion}',
                  'API ${daemon.daemonApi}',
                  if (built != null) 'built ${dateTime(built)}',
                  if (daemon.replaced) 'a newer one is installed',
                ].join(' · '),
                control: native.install.restartsDaemon
                    ? Button(
                        label: daemon.restarting ? 'Restarting…' : 'Restart',
                        // Its width while it runs, so it doesn't grow.
                        roomFor: const ['Restarting…'],
                        onPressed: daemon.restarting
                            ? null
                            : () => restartDaemonAsking(context, daemon),
                      )
                    : null,
              ),
              if (native.install.version case final v when v.isNotEmpty)
                SettingsRow('App', description: 'Version $v'),
            ],
          ),
        ),
      ],
    );
  }
}
