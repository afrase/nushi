import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

const _channel = MethodChannel('nushi/login');

/// "Start at login" in Settings › General, a group of its own: the app's
/// launch agent, which opens the daemon's helper app at login (ADR 0036).
/// macOS keeps whether it's on; the row shows only once the app's Swift
/// side answers.
class StartAtLogin extends StatefulWidget {
  const new({super.key});

  @override
  State<StartAtLogin> createState() => _StartAtLoginState();
}

class _StartAtLoginState extends State<StartAtLogin> {
  // enabled, requiresApproval, notRegistered, or notFound: what macOS
  // says of a job it hasn't seen (before the first register too).
  String? _status;

  @override
  void initState() {
    super.initState();
    _call('status').ignore(); // no answer (macOS 12, tests): no row
  }

  Future<void> _call(String method, [Object? argument]) async {
    final status = await _channel.invokeMethod<String>(method, argument);
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    final t = NushiTheme.of(context).t;
    final waiting = status == 'requiresApproval';
    return SettingsGroup(
      children: [
        SettingsRow(
          'Start at login',
          description: waiting
              ? 'Allow Nushi in Login Items to start it.'
              : 'The daemon starts when you log in, without the app.',
          descriptionColor: waiting ? t.needs : null,
          control: SettingsSwitch(
            value: status == 'enabled' || waiting,
            onChanged: (on) => tryOrShow(context, () => _call('set', on)),
          ),
        ),
        if (waiting)
          SettingsRow(
            'Login Items',
            control: Button(
              label: 'Open Login Items…',
              onPressed: () => tryOrShow(context, () => _call('openSettings')),
            ),
          ),
      ],
    );
  }
}
