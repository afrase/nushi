import 'package:flutter/material.dart';
import 'package:nushi/native.dart';
import 'package:nushi/widgets.dart';

/// The notice over Jira's or GitHub's list while the daemon can't read a
/// site's or host's token from the keychain: this build needs the user's
/// OK ([needsOk]; Allow… runs [onAllow]), or the daemon must start again
/// first ([needsRestart], [problem] says why; Restart daemon runs
/// [onRestart], with a daemon the app bundles). Nothing else.
class TokenNotices extends StatelessWidget {
  const new({
    required this.needsOk,
    required this.needsRestart,
    required this.problem,
    required this.onAllow,
    required this.onRestart,
    super.key,
  });

  final bool needsOk;
  final bool needsRestart;
  final String problem;
  final VoidCallback onAllow;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) => needsOk
      ? Notice(
          'This build of Nushi needs your OK to read the token from the '
          'keychain; macOS asks for your password.',
          action: 'Allow…',
          onAction: onAllow,
        )
      : needsRestart
      ? Notice(
          '$problem. Restarting stops running turns and closes terminals.',
          action: native.install.daemon == null ? null : 'Restart daemon',
          onAction: onRestart,
        )
      : const SizedBox.shrink();
}
