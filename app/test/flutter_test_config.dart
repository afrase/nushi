import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
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
import 'package:re_editor/re_editor.dart' show kIsAndroid, kIsIOS, kIsMacOS;

import 'config_home_linux.dart';
import 'fake_app_install.dart';
import 'fake_desktop.dart';
import 'golden_tolerance.dart';
import 'harness.dart';

/// Goldens are drawn on macOS only (on Linux about a third differ by 1–4%):
/// elsewhere they aren't compared or written, and in a run of the Linux
/// set's files (`NUSHI_TEST_SET=linux`) one fails. On CI (GitHub's macOS image
/// draws text a few pixels differently from a Mac), a golden may differ
/// by what `golden_tolerance.dart` allows; here it must match. Every
/// shine stands still, its band before the text, and so does every loop on
/// the shared clock that reads `loopPhase` (a pull request's running ring,
/// a streaming reply's caret), so goldens are one frame and pumpAndSettle
/// settles while a call runs; the app's clock stands at [fixtureNow], so an
/// age a golden shows never moves. No test sees what another left: the
/// app's prefs as at launch (`app.json` too), nothing the app holds in
/// memory while it runs (`run_state.dart`'s: agents, caches, drafts,
/// groups opened…), no pull request read, review comments, clones or
/// theme files known, no file in the data folder but app.json, no image
/// decoded, the shared
/// clock of what loops at its start; the Mac's native edge (on every
/// host), no speller, a fake install, so nothing starts or stops a
/// daemon, a fake file manager, so nothing opens on the desktop, and a
/// phone paired with a Mac.
/// The test process's data folder goes when its tests end; on Linux it
/// holds the process's `XDG_CONFIG_HOME` too, where enchant makes its
/// folder, so no test writes in the user's.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Shine.stopAt = 0;
  if (Platform.isLinux) configHomeAt('$dataDir/config');
  // re_editor asks which platform it is on once, when its first editor is
  // built, and keeps the answer for the process: asked here as the Mac,
  // or the file's first editor test would decide whether every later one
  // has a desktop's scrollbar and the Mac's keys (a test's platform is
  // Android unless it says).
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  if (!kIsMacOS || kIsAndroid || kIsIOS) {
    throw StateError('re_editor had asked its platform already');
  }
  debugDefaultTargetPlatformOverride = null;
  // A tap or a drag that lands on nothing, or on another widget, fails its
  // test: one that misses checks nothing after it.
  WidgetController.hitTestWarningShouldBeFatal = true;
  final local = goldenFileComparator;
  if (Platform.environment['NUSHI_TEST_SET'] == 'linux') {
    goldenFileComparator = _NotInSet();
  } else if (!Platform.isMacOS) {
    goldenFileComparator = _NotHere();
  } else if (Platform.environment['CI'] == 'true' &&
      local is LocalFileComparator) {
    goldenFileComparator = _Tolerant(
      local.basedir.resolve('flutter_test_config.dart'),
    );
  }
  setUp(startAfresh);
  tearDownAll(() {
    final dir = Directory(dataDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  await testMain();
}

/// What every test starts with, as the comment above says: run before
/// each (setUp), and by a test that checks what one test leaves the next
/// (`test_setup_test.dart`), in the place of the test after it.
void startAfresh() {
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
  // Nothing another test left in the process's data folder (pull
  // requests read, tile images, theme files, the app's log, a file a test
  // wrote…), so a new kind of file needs no line here: everything goes
  // but app.json, which resetAppSettings next writes as at launch (and
  // which a file's setUpAll may have written for the app to find, read
  // and set aside at the first test's), and on Linux `config`, the
  // process's XDG_CONFIG_HOME.
  final data = Directory(dataDir);
  if (data.existsSync()) {
    for (final e in data.listSync()) {
      final name = e.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (name == 'app.json' || name == 'config') continue;
      e.deleteSync(recursive: true);
    }
  }
  // The prefs as at launch, and `app.json` on disk as it was then.
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
  // What loops starts at its rest, not where the test before left the
  // shared clock.
  pulseClock.rewind();
  // No image another test decoded: one in the cache is drawn in a
  // widget's first frame, one that isn't only once its decode ends, so
  // a picture would depend on the tests before it. (A test that never
  // made the binding has no cache.)
  if (BindingBase.debugBindingType() != null) {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }
}

/// Off macOS: every golden passes unseen, and none is written.
class _NotHere extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      throw FlutterError('Goldens are drawn on macOS only: $golden');
}

/// A run of the Linux set's files (tools/test-shards, `NUSHI_TEST_SET`):
/// a golden here fails, on any host, since the set's CI jobs would
/// otherwise pass it unseen.
class _NotInSet extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) => throw FlutterError(
    'This file compares goldens, which CI draws only in the macOS set: '
    'tools/test-shards must put it there (it looks for '
    'matchesGoldenFile( in the test file itself): $golden',
  );

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      compare(imageBytes, golden);
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
