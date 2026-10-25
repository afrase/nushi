import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

const _channel = MethodChannel('nushi/login');

/// "Start at login" in Settings: the app's launch agent, which opens the
/// daemon's helper app at login (ADR 0036). macOS keeps whether it's on;
/// the row shows only once the app's Swift side answers.
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
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final waiting = status == 'requiresApproval';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Start at login',
              style: theme.ui(t.text, weight: FontWeight.w600),
            ),
            const Spacer(),
            SizedBox(
              height: 20,
              child: FittedBox(
                child: Switch(
                  value: status == 'enabled' || waiting,
                  onChanged: (on) => tryOrShow(context, () => _call('set', on)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (waiting)
          GestureDetector(
            onTap: () => _call('openSettings'),
            child: Text(
              'Allow Nushi in Login Items to start it.',
              style: theme.ui(t.accent, size: 12),
            ),
          )
        else
          Text(
            'The daemon starts when you log in, without the app.',
            style: theme.ui(t.textSecondary, size: 12),
          ),
      ],
    );
  }
}
