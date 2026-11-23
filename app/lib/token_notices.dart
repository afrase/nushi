import 'package:flutter/material.dart';
import 'package:nushi/app_install.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/native.dart';
import 'package:nushi/widgets.dart';

/// The notice over Jira's or GitHub's list while the daemon can't read a
/// site's or host's token from the keychain: it needs the user's OK (a
/// new build on the Mac, a locked keyring on Linux; [needsOk]; Allow…
/// runs [onAllow]), or the daemon must start again
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
          'Nushi needs your OK to read the token from the '
          '${conventions.keyring}: ${conventions.system} asks for your '
          'password.',
          action: 'Allow…',
          onAction: onAllow,
        )
      : needsRestart
      ? Notice(
          '$problem. Restarting stops running turns and closes terminals.',
          action: native.install.restartsDaemon ? 'Restart daemon' : null,
          onAction: onRestart,
        )
      : const SizedBox.shrink();
}
