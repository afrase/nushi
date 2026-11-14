import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The cask that follows beta versions (ADR 0108); `nushi` has releases
/// only.
const betaCask = 'nushi@beta';

/// What upgrades a Nushi that Homebrew's [cask] installed.
String brewUpgrade(String cask) => 'brew update && brew upgrade --cask $cask';

/// The cask of Homebrew's that installed the app running as [executable],
/// if one did: it is Nushi.app in /Applications or ~/Applications (the
/// casks' places), and Homebrew's Caskroom has nushi@beta or nushi (one
/// of them: they conflict; under /opt/homebrew, or /usr/local on an Intel
/// Mac). A few looks at folders; running `brew --prefix` to find a moved
/// prefix would cost far more.
String? homebrewCask(
  String executable,
  String home,
  bool Function(String folder) exists,
) {
  // Nushi.app/Contents/MacOS/Nushi
  final app = File(executable).parent.parent.parent.path;
  if (app != '/Applications/Nushi.app' &&
      app != '$home/Applications/Nushi.app') {
    return null;
  }
  for (final cask in [betaCask, 'nushi']) {
    if (exists('/opt/homebrew/Caskroom/$cask') ||
        exists('/usr/local/Caskroom/$cask')) {
      return cask;
    }
  }
  return null;
}

/// The cask this app came from, if Homebrew installed it; tests set it.
String? brewCask = homebrewCask(
  Platform.resolvedExecutable,
  Platform.environment['HOME'] ?? '',
  (f) => Directory(f).existsSync(),
);

/// The cask whose upgrade brings [version], if Homebrew installed the app
/// and has it: a beta version is only nushi@beta's.
String? caskWith(String version) => switch (brewCask) {
  final cask? when cask == betaCask || !isBeta(version) => cask,
  _ => null,
};

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
  final mine = native.install.version.split('+').first;
  if (mine.isNotEmpty && compareVersions(mine, v) >= 0) return null;
  return v;
}

/// Opens the newer release's page on GitHub, saying under [context] why
/// when it doesn't open.
void openRelease(BuildContext context, Daemon d) =>
    openWeb(context, d.update.url);

/// Whether [version] is a beta version: a pre-release ("0.29.0-beta.1";
/// ADR 0108).
bool isBeta(String version) => version.split('+').first.contains('-');

/// Says a newer release is out, in the window's bottom right corner, out
/// of the way: not modal, no sound. When Homebrew installed the app and
/// its cask has the release ([caskWith]), Update has the daemon run
/// Homebrew's upgrade (ADR 0109; Release notes opens the release's page):
/// the card says "Updating…" until Homebrew quits the app and opens the
/// new one, or why it failed, with Retry and Copy (Homebrew's upgrade on
/// the clipboard, all a daemon older than [installApi] offers). Without a
/// cask, Download opens the release's page. × dismisses it until a newer
/// one.
class UpdateToast extends StatefulWidget {
  const new(this.daemon, {super.key});

  /// As wide as the details panel's text, over whose empty bottom it sits
  /// in a wide window: the panel's width inside its side margins.
  static const width = 288.0;

  /// Its room from the window's right and bottom edges: the window's
  /// margin and the panel's side margin, so it lines up with the details
  /// cards' text.
  static const double inset = NushiTheme.windowPad + 16;

  final Daemon daemon;

  @override
  State<UpdateToast> createState() => _UpdateToastState();
}

class _UpdateToastState extends State<UpdateToast> {
  bool _copied = false;
  Timer? _unmark;
  final _install = Runner();

  @override
  void dispose() {
    _unmark?.cancel();
    _install.dispose();
    super.dispose();
  }

  Future<void> _copy(String cask) async {
    await Clipboard.setData(ClipboardData(text: brewUpgrade(cask)));
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
      return Presence(
        // It rises 8 px as it fades in, and only fades as it goes.
        builder: (context, run, child) => AnimatedBuilder(
          animation: run,
          builder: (context, child) => Faded(
            opacity: run.value,
            child: Transform.translate(
              offset: Offset(
                0,
                run.status == AnimationStatus.reverse ? 0 : 8 * (1 - run.value),
              ),
              child: child,
            ),
          ),
          child: child,
        ),
        child: version == null ? null : _toast(version),
      );
    },
  );

  Widget _toast(String version) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final d = widget.daemon;
    final u = d.update;
    final cask = caskWith(version);
    // What the daemon's own install says, when it has one to offer.
    final installs = cask != null && d.daemonApi >= installApi;
    final installing = installs && u.installing;
    final installed = installs && !installing && u.installed == version;
    final error = installs && !installing && !installed ? u.installError : '';
    final notes = Button(
      label: 'Release notes',
      onPressed: () => openRelease(context, d),
    );
    Widget copy(String cask) => Button(
      label: _copied ? 'Copied' : 'Copy',
      kind: ButtonKind.primary,
      tooltip: 'Copy “${brewUpgrade(cask)}”',
      onPressed: () => _copy(cask),
    );
    Widget update(String cask, {required bool again}) => ListenableBuilder(
      listenable: _install,
      builder: (context, _) => Button(
        label: installing
            ? 'Updating…'
            : again
            ? 'Retry'
            : 'Update',
        kind: again ? ButtonKind.secondary : ButtonKind.primary,
        tooltip: installing ? '' : 'Runs “${brewUpgrade(cask)}”',
        onPressed: installing || _install.value
            ? null
            : () => _install.run(context, d.installUpdate),
      ),
    );
    return Container(
      key: const ValueKey('update-toast'),
      width: UpdateToast.width,
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 12),
      decoration: floatBox(t, radius: NushiTheme.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Row(
            spacing: 8,
            children: [
              if (installing)
                const SizedBox.square(dimension: 16, child: Spinner())
              else
                Icon(
                  installed ? Icons.check_circle : Icons.arrow_circle_up,
                  size: 16,
                  color: installed ? t.done : t.accent,
                ),
              Expanded(
                child: Text(
                  installing
                      ? 'Updating to Nushi $version…'
                      : installed
                      ? 'Nushi $version is installed.'
                      : 'Nushi $version is available.',
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
          if (installed)
            // Homebrew didn't quit this app, so it didn't open the new one.
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                'Quit Nushi and open it again.',
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: tooltip(
                context,
                error,
                Text(
                  error,
                  key: const ValueKey('update-error'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.crashed, size: 12),
                ),
              ),
            ),
          Row(
            spacing: 8,
            children: [
              if (installed)
                notes
              else if (cask == null)
                Button(
                  label: 'Download',
                  kind: ButtonKind.primary,
                  tooltip: "Open the release's page",
                  onPressed: () => openRelease(context, d),
                )
              else if (!installs) ...[
                copy(cask),
                notes,
              ] else if (error.isNotEmpty) ...[
                copy(cask),
                update(cask, again: true),
                notes,
              ] else ...[
                update(cask, again: false),
                notes,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks the daemon for a newer release now (the palette's Check for
/// updates): the toast shows a newer one, even one dismissed before;
/// otherwise a note says the app is up to date.
Future<void> checkForUpdates(BuildContext context, Daemon d) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  // From the menu bar or the palette: nothing else shows it's asking.
  final slow = Timer(
    Waits.slow,
    () => showToast(
      messenger,
      'Checking for updates…',
      duration: const Duration(minutes: 1),
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
      showToast(messenger, switch (u.latest) {
        '' => 'Nushi has no release yet.',
        final latest when d.daemonVersion.isEmpty =>
          'The latest release is $latest; this is a development build.',
        final latest => 'Nushi is up to date ($latest).',
      });
    }
  });
}
