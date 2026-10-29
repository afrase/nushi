import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';

import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings_general.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/update_toast.dart';
import 'package:nushi/widgets.dart';

/// "Last checked 12m ago", or "Not checked yet".
String lastChecked(Int64 ms, DateTime now) {
  if (ms == 0) return 'Not checked yet';
  final at = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
  return 'Last checked ${ago(now.difference(at), at)}';
}

/// Settings › General's Updates: whether the daemon checks GitHub for a
/// newer release (on by default), when it last did, and Check now.
class UpdatesGroup extends StatefulWidget {
  const new({
    required this.daemon,
    required this.settings,
    required this.onChange,
    super.key,
  });

  final Daemon daemon;
  final Settings settings;
  final SettingsChange onChange;

  @override
  State<UpdatesGroup> createState() => _UpdatesGroupState();
}

class _UpdatesGroupState extends State<UpdatesGroup> {
  late final Timer _minute; // "12m ago" moves on while the page shows
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _minute = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _minute.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    await checkForUpdates(context, widget.daemon);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.daemon,
    builder: (context, _) => SettingsGroup(
      title: 'Updates',
      footer: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${lastChecked(widget.daemon.update.checkedMs, clock())} · '),
          LinkText(
            _checking ? 'Checking…' : 'Check now',
            size: 12,
            onTap: _checking ? null : () => unawaited(_check()),
          ),
        ],
      ),
      children: [
        SettingsRow(
          'Check for updates',
          description:
              'Asks GitHub for a newer release of Nushi at start and every '
              '2 hours.',
          control: SettingsSwitch(
            value: widget.settings.checkUpdates,
            onChanged: (on) => tryOrShow(
              context,
              () => widget.onChange((s) => s.checkUpdates = on),
            ),
          ),
        ),
      ],
    ),
  );
}
