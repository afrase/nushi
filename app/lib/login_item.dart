import 'package:flutter/material.dart';

import 'package:nushi/native.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What starts the daemon at login (ADR 0036): on the Mac, the app's
/// launch agent (`login_item_macos.dart`). Each call answers its status
/// after it, in the Mac's words: "enabled", "requiresApproval" (on, until
/// the user allows it in Login Items), "notRegistered", or "notFound"
/// (what macOS says of a job it hasn't seen, before the first register
/// too).
abstract interface class LoginItem {
  /// Its status.
  Future<String?> status();

  /// Turns it [on] or off.
  Future<String?> set({required bool on});

  /// Opens the system's settings where the user allows it.
  Future<String?> openSettings();
}

/// "Start at login" in Settings › General, a group of its own: the app's
/// launch agent, which opens the daemon's helper app at login (ADR 0036).
/// macOS keeps whether it's on; the row shows only once the [LoginItem]
/// answers.
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
    // No answer (macOS 12, tests): no row.
    _call(native.loginItem.status).ignore();
  }

  Future<void> _call(Future<String?> Function() call) async {
    final status = await call();
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
            run: ({required on}) => _call(() => native.loginItem.set(on: on)),
          ),
        ),
        if (waiting)
          SettingsRow(
            'Login Items',
            control: Button(
              label: 'Open Login Items…',
              onPressed: () => tryOrShow(
                context,
                () => _call(native.loginItem.openSettings),
              ),
            ),
          ),
      ],
    );
  }
}
