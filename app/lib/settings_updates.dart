import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';

import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/update_toast.dart';
import 'package:nushi/widgets.dart';

/// "Last checked 12m ago", or "Not checked yet".
String lastChecked(Int64 ms, DateTime now) {
  if (ms == 0) return 'Not checked yet';
  return 'Last checked ${agoAt(ms.toInt(), now)}';
}

/// Settings › General's Updates: [login] first (Start at login's rows,
/// which make it "Startup and updates"), whether the daemon checks GitHub
/// for a newer release (on by default; at start and every 2 hours), then
/// the version running, when GitHub was last asked, and Check now. Shown
/// once [settings] came.
class UpdatesGroup extends StatefulWidget {
  const new({
    required this.daemon,
    required this.settings,
    super.key,
    this.login = const [],
  });

  final Daemon daemon;
  final DaemonSettings settings;
  final List<Widget> login;

  @override
  State<UpdatesGroup> createState() => _UpdatesGroupState();
}

class _UpdatesGroupState extends State<UpdatesGroup> {
  final _checking = Runner();

  @override
  void initState() {
    super.initState();
    minuteClock.addListener(_aged); // "12m ago" moves on while it shows
  }

  void _aged() => setState(() {});

  @override
  void dispose() {
    minuteClock.removeListener(_aged);
    _checking.dispose();
    super.dispose();
  }

  /// What the version's row says under it: whether this is the latest
  /// release, and when GitHub was last asked.
  String _state() {
    final d = widget.daemon;
    final u = d.update;
    final checked = lastChecked(u.checkedMs, clock());
    if (u.version.isNotEmpty) return '$checked, ${u.version} is out';
    if (u.latest.isNotEmpty && u.latest == d.daemonVersion) {
      return '$checked, up to date';
    }
    return checked;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.daemon, _checking]),
    builder: (context, _) {
      final version = widget.daemon.daemonVersion;
      return SettingsGroup(
        title: widget.login.isEmpty ? 'Updates' : 'Startup and updates',
        children: [
          ...widget.login,
          SettingsRow(
            'Check for updates',
            description: 'At start and every 2 hours.',
            control: SettingsSwitch(
              value: widget.settings.value?.checkUpdates ?? false,
              run: ({required on}) =>
                  widget.settings.change((s) => s.checkUpdates = on),
            ),
          ),
          SettingsRow(
            version.isEmpty ? 'Nushi' : 'Nushi $version',
            description: _state(),
            // An action, so a button, not a link (docs/design.md).
            control: Button(
              key: const ValueKey('check-now'),
              label: _checking.value ? 'Checking…' : 'Check now',
              // Its width while it checks, so it doesn't change.
              roomFor: const ['Checking…'],
              onPressed: _checking.value
                  ? null
                  : () => unawaited(
                      _checking.run(
                        context,
                        () => checkForUpdates(context, widget.daemon),
                      ),
                    ),
            ),
          ),
        ],
      );
    },
  );
}
