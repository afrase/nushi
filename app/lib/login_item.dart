import 'package:flutter/material.dart';

import 'package:nushi/native.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What starts the daemon at login (ADR 0036, 0104): on the Mac, the
/// app's launch agent (`login_item_macos.dart`); on Linux, an XDG
/// autostart entry (`login_item_linux.dart`). Each call answers its state
/// after it.
abstract interface class LoginItem {
  /// Its state.
  Future<LoginItemState?> status();

  /// Turns it [on] or off.
  Future<LoginItemState?> set({required bool on});

  /// Opens the system's settings where the user allows it.
  Future<LoginItemState?> openSettings();
}

/// Whether the daemon starts at login: [needsApproval] is on, until the
/// user allows it in the system's settings.
enum LoginItemState { on, needsApproval, off }

/// "Start at login" in Settings › General, a group of its own: the
/// [LoginItem], which starts the packaged daemon at login (ADR 0036,
/// 0104). The system keeps whether it's on; the row shows only once the
/// [LoginItem] answers.
class StartAtLogin extends StatefulWidget {
  const new({super.key});

  @override
  State<StartAtLogin> createState() => _StartAtLoginState();
}

class _StartAtLoginState extends State<StartAtLogin> {
  LoginItemState? _status;

  @override
  void initState() {
    super.initState();
    // No answer (macOS 12, tests): no row.
    _call(native.loginItem.status).ignore();
  }

  Future<void> _call(Future<LoginItemState?> Function() call) async {
    final status = await call();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    final t = NushiTheme.of(context).t;
    final waiting = status == LoginItemState.needsApproval;
    return SettingsGroup(
      children: [
        SettingsRow(
          'Start at login',
          description: waiting
              ? 'Allow Nushi in Login Items to start it.'
              : 'The daemon starts when you log in, without the app.',
          descriptionColor: waiting ? t.needs : null,
          control: SettingsSwitch(
            value: status != LoginItemState.off,
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
