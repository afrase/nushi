import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/remote.dart' show remoteState;
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What each of remote access's files holds, as the reset says it.
const _what = {
  'remote-key.json': 'its key file',
  'devices.json': 'its list of paired phones',
  'vapid.json': "its notifications' key file",
};

/// Why remote access was reset and what to do (ADR 0034's 2026-11-22
/// amendment): which files couldn't be read, Pair your phones again, and
/// where the old files went; [RemoteResetLine] names them under it.
String resetWords(RemoteReset r) {
  final what = [
    for (final f in r.files) _what[f.split('.unreadable-').first] ?? f,
  ];
  final which = switch (what) {
    [] => 'a file of it',
    [final one] => one,
    _ => '${what.sublist(0, what.length - 1).join(', ')} and ${what.last}',
  };
  final kept = switch (r.files) {
    [] => '',
    [_] => ' The old file is kept in the data folder as:',
    _ => ' The old files are kept in the data folder as:',
  };
  return "Remote access was reset because $which couldn't be read. "
      'Pair your phones again.$kept';
}

/// Settings › Remote access's line saying remote access was reset, at the
/// top of its first group: the failure's icon and words on its soft fill,
/// so it can't be missed (it stays until a phone is paired again), and the
/// old files' names under them in code's type, each on a line.
class RemoteResetLine extends StatelessWidget {
  const new(this.reset, {super.key});

  final RemoteReset reset;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ColoredBox(
      color: t.crashedSoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline, size: 16, color: t.crashed),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(resetWords(reset), style: theme.ui(t.crashed)),
                  for (final f in reset.files)
                    Text(f, style: theme.code(t.crashed, size: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Says once, in a failure toast, that remote access was reset, the first
/// time the app sees a reset while remote access is on; [remoteResetToasted]
/// keeps which one, so a later launch says nothing more of it. Its
/// Settings button opens Settings › Remote access, which says it until a
/// phone is paired again.
class RemoteResetToast extends StatefulWidget {
  const new(this.daemon, {required this.child, super.key});

  final Daemon daemon;
  final Widget child;

  @override
  State<RemoteResetToast> createState() => _RemoteResetToastState();
}

class _RemoteResetToastState extends State<RemoteResetToast> {
  @override
  void initState() {
    super.initState();
    remoteState.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    remoteState.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final r = remoteState.value;
    if (r == null || !r.on || !r.hasWasReset()) return;
    final at = r.wasReset.at.toInt();
    if (at == remoteResetToasted.value) return;
    remoteResetToasted.value = at;
    // After the frame: a remote event can come as the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showFailure(
        Toasts.maybeOf(context),
        'Remote access was reset. Pair your phones again.',
        key: const ValueKey('remote-reset'),
        duration: const Duration(seconds: 10),
        action: (
          label: 'Settings',
          onPressed: () =>
              widget.daemon.openSettings(section: SettingsSection.remote),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
