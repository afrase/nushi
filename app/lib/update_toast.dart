import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_log.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// What upgrades a Nushi that Homebrew's cask installed.
const brewUpgrade = 'brew update && brew upgrade --cask nushi';

/// Whether Homebrew's cask installed the app running as [executable]: it
/// is Nushi.app in /Applications or ~/Applications (the cask's places),
/// and Homebrew's Caskroom has nushi (under /opt/homebrew, or /usr/local
/// on an Intel Mac). Two looks at folders; running `brew --prefix` to
/// find a moved prefix would cost far more.
bool installedByHomebrew(
  String executable,
  String home,
  bool Function(String folder) exists,
) {
  // Nushi.app/Contents/MacOS/Nushi
  final app = File(executable).parent.parent.parent.path;
  if (app != '/Applications/Nushi.app' &&
      app != '$home/Applications/Nushi.app') {
    return false;
  }
  return exists('/opt/homebrew/Caskroom/nushi') ||
      exists('/usr/local/Caskroom/nushi');
}

/// Whether this app came from Homebrew's cask; tests set it.
bool byHomebrew = installedByHomebrew(
  Platform.resolvedExecutable,
  Platform.environment['HOME'] ?? '',
  (f) => Directory(f).existsSync(),
);

/// Orders two versions as semantic versioning does (a pre-release before
/// its release; build metadata aside); one that isn't a version is before
/// any that is. The daemon's `updates.Compare`.
int compareVersions(String a, String b) {
  (List<int>, List<String>)? parse(String s) {
    final [core, ...pre] = s.split('+').first.split('-');
    final parts = core.split('.');
    final nums = [for (final p in parts) int.tryParse(p)];
    if (parts.length != 3 || nums.contains(null)) return null;
    final ids = pre.isEmpty ? <String>[] : pre.join('-').split('.');
    if (ids.contains('')) return null;
    return ([for (final n in nums) n!], ids);
  }

  final (va, vb) = (parse(a), parse(b));
  if (va == null || vb == null) {
    return (va == null ? 0 : 1).compareTo(vb == null ? 0 : 1);
  }
  for (var i = 0; i < 3; i++) {
    if (va.$1[i] != vb.$1[i]) return va.$1[i].compareTo(vb.$1[i]);
  }
  final (pa, pb) = (va.$2, vb.$2);
  if (pa.isEmpty || pb.isEmpty) {
    return (pa.isEmpty ? 1 : 0).compareTo(pb.isEmpty ? 1 : 0);
  }
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final (na, nb) = (int.tryParse(pa[i]), int.tryParse(pb[i]));
    final c = switch ((na, nb)) {
      (final x?, final y?) => x.compareTo(y),
      (_?, null) => -1, // numeric identifiers come first
      (null, _?) => 1,
      _ => pa[i].compareTo(pb[i]),
    };
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

/// The newer release to tell of, if any: one the daemon found, newer than
/// this app (an upgraded app waits for its daemon's restart, ADR 0056,
/// and has nothing to say), and not dismissed.
String? updateToShow(Daemon d) {
  final v = d.update.version;
  if (d.remote || v.isEmpty || v == dismissedUpdate.value) return null;
  final mine = appVersion.split('+').first;
  if (mine.isNotEmpty && compareVersions(mine, v) >= 0) return null;
  return v;
}

/// Opens the newer release's page on GitHub.
void openRelease(Daemon d) {
  if (webLink(d.update.url) case final u?) unawaited(launchUrl(u));
}

/// Says a newer release is out, in the window's bottom right corner, out
/// of the way: not modal, no sound. Copy puts Homebrew's upgrade on the
/// clipboard when Homebrew installed the app (Release notes opens the
/// release's page), else Download opens the release's page; × dismisses
/// it until a newer one.
class UpdateToast extends StatefulWidget {
  const new(this.daemon, {super.key});

  /// As wide as the details panel's widgets, over whose empty bottom it
  /// sits in a wide window.
  static const width = 240.0;

  /// Its room from the window's right edge: the cards' own.
  static const inset = 12.0;

  final Daemon daemon;

  @override
  State<UpdateToast> createState() => _UpdateToastState();
}

class _UpdateToastState extends State<UpdateToast> {
  bool _copied = false;
  Timer? _unmark;

  @override
  void dispose() {
    _unmark?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: brewUpgrade));
    if (!mounted) return;
    setState(() => _copied = true);
    _unmark?.cancel();
    _unmark = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.daemon, dismissedUpdate]),
    builder: (context, _) {
      final version = updateToShow(widget.daemon);
      if (version == null) return const SizedBox.shrink();
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final d = widget.daemon;
      return Container(
        key: const ValueKey('update-toast'),
        width: UpdateToast.width,
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 12),
        decoration: box(
          t.borderStrong,
          fill: t.raised,
        ).copyWith(boxShadow: [BoxShadow(color: t.shadow, blurRadius: 12)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Row(
              spacing: 8,
              children: [
                Icon(Icons.arrow_circle_up, size: 16, color: t.accent),
                Expanded(
                  child: Text(
                    'Nushi $version is available.',
                    style: theme.ui(t.text),
                  ),
                ),
                IconTap(
                  Icons.close,
                  size: 14,
                  tooltip: 'Dismiss: not again until a newer one',
                  onTap: () => dismissedUpdate.value = version,
                ),
              ],
            ),
            Row(
              spacing: 8,
              children: [
                if (byHomebrew) ...[
                  Button(
                    label: _copied ? 'Copied' : 'Copy',
                    kind: ButtonKind.primary,
                    tooltip: 'Copy “$brewUpgrade”',
                    onPressed: _copy,
                  ),
                  Button(
                    label: 'Release notes',
                    onPressed: () => openRelease(d),
                  ),
                ] else
                  Button(
                    label: 'Download',
                    kind: ButtonKind.primary,
                    tooltip: "Open the release's page",
                    onPressed: () => openRelease(d),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Asks the daemon for a newer release now (the palette's Check for
/// updates): the toast shows a newer one, even one dismissed before;
/// otherwise a note says the app is up to date.
Future<void> checkForUpdates(BuildContext context, Daemon d) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  // From the menu bar or the palette: nothing else shows it's asking.
  final slow = Timer(
    const Duration(milliseconds: 300),
    () => messenger?.showSnackBar(
      const SnackBar(
        content: Text('Checking for updates…'),
        duration: Duration(minutes: 1),
      ),
    ),
  );
  await tryOrShow(context, () async {
    final u = await d.checkForUpdates().whenComplete(() {
      slow.cancel();
      messenger?.hideCurrentSnackBar();
    });
    if (u.version.isNotEmpty && dismissedUpdate.value == u.version) {
      dismissedUpdate.value = null;
    }
    if (updateToShow(d) == null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(switch (u.latest) {
            '' => 'Nushi has no release yet.',
            final latest when d.daemonVersion.isEmpty =>
              'The latest release is $latest; this is a development build.',
            final latest => 'Nushi is up to date ($latest).',
          }),
        ),
      );
    }
  });
}
