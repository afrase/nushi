import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/native.dart';
import 'package:nushi/native_macos.dart';
import 'package:nushi/pull_cache.dart';
import 'package:nushi/review.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme_files.dart';
import 'package:nushi/tile_mark.dart';

import 'config_home_linux.dart';
import 'fake_app_install.dart';
import 'fake_desktop.dart';
import 'golden_tolerance.dart';
import 'harness.dart';

/// Goldens are drawn on macOS only (on Linux about a third differ by 1–4%):
/// elsewhere they aren't compared or written. On CI (GitHub's macOS image
/// draws text a few pixels differently from a Mac), a golden may differ
/// by what `golden_tolerance.dart` allows; here it must match. Every
/// shine stands still, its band before the text, and so does every loop on
/// the shared clock that reads `loopPhase` (a pull request's running ring,
/// a streaming reply's caret), so goldens are one frame and pumpAndSettle
/// settles while a call runs; the app's clock stands at [fixtureNow], so an
/// age a golden shows never moves. No test sees what another left: the
/// app's prefs as at launch, nothing the app holds in memory while it runs
/// (`run_state.dart`'s: agents, caches, drafts, groups opened…), no pull
/// request read, review comments, clones or theme files known; the Mac's
/// native edge (on every host), no speller, a fake install, so nothing
/// starts or stops a daemon, a fake file manager, so nothing opens on
/// the desktop, and a phone paired with a Mac.
/// The test process's data folder goes when its tests end; on Linux it
/// holds the process's `XDG_CONFIG_HOME` too, where enchant makes its
/// folder, so no test writes in the user's.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Shine.stopAt = 0;
  if (Platform.isLinux) configHomeAt('$dataDir/config');
  final local = goldenFileComparator;
  if (!Platform.isMacOS) {
    goldenFileComparator = _NotHere();
  } else if (Platform.environment['CI'] == 'true' &&
      local is LocalFileComparator) {
    goldenFileComparator = _Tolerant(
      local.basedir.resolve('flutter_test_config.dart'),
    );
  }
  setUp(() {
    clock = () => fixtureNow;
    // The Mac's native edge, over channels a test may answer, but no
    // speller: one that sets its own gets it (ADR 0097); an install that
    // runs nothing; a file manager that opens nothing (the Mac's runs
    // `open`, which would show Finder or the user's own files): a test
    // that wants the real one sets it.
    native = macosNative()
      ..speller = null
      ..install = FakeAppInstall()
      ..desktop = FakeDesktop();
    phoneHost = macConventions;
    resetAppSettings();
    // What the app holds while it runs (caches, half-written comments,
    // groups opened…), each made through run_state.dart.
    forgetRunState();
    // A mark's ink is measured by the engine, on the real clock: a
    // test that looks at where it lands turns it on and waits.
    centreMarksByInk = false;
    // And what's kept beside it: pull requests read (on disk too),
    // review comments (read from disk at first), the Jira and GitHub
    // views' places, theme files.
    forgetPulls();
    forgetReviews();
    forgetReviewDrafts();
    forgetJiraView();
    forgetGitHubView();
    unawaited(themeFiles.forget());
  });
  tearDownAll(() {
    final dir = Directory(dataDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  await testMain();
}

/// Off macOS: every golden passes unseen, and none is written.
class _NotHere extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      throw FlutterError('Goldens are drawn on macOS only: $golden');
}

/// CI's comparator: a golden within `goldenWithin` passes. Each that
/// isn't exact prints its numbers, passed or not, so how near a golden is
/// to failing shows in CI's log before it fails.
class _Tolerant extends LocalFileComparator {
  new(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) {
      result.dispose();
      return true;
    }
    final total = pngPixels(imageBytes);
    final diff = (result.diffPercent * total).round();
    final within = total > 0 && goldenWithin(diff, total);
    // Into CI's log, where the margins are read.
    // ignore: avoid_print
    print(
      'golden ${golden.pathSegments.last}: $diff px of $total '
      '(${(result.diffPercent * 100).toStringAsFixed(2)}%), '
      '${within ? 'within' : 'past'} what CI allows '
      '($goldenFewPixels px, or 1% up to $goldenMostPixels px)',
    );
    if (within) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
