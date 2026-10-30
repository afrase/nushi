import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/github_files.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/pull_cache.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';

import 'harness.dart';

/// On CI (GitHub's macOS image draws text a few pixels differently from a
/// Mac), a golden may differ in up to 1% of its pixels (a card dense with
/// text, as a review's findings, reaches 0.56% from anti-aliasing alone);
/// here it must match. Every shine stands still, its band before the text,
/// and so does every loop on the shared clock that reads `loopPhase` (a
/// pull request's running ring, a streaming reply's caret), so goldens are
/// one frame and pumpAndSettle settles while a call runs; the app's clock
/// stands at [fixtureNow], so an age a golden shows never moves. No test
/// sees what another left: the app's prefs as at launch, no pull request
/// read, no agents, review comments or drafts, remote state or clones
/// known.
/// The test process's data folder goes when its tests end.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Shine.stopAt = 0;
  final local = goldenFileComparator;
  if (Platform.environment['CI'] == 'true' && local is LocalFileComparator) {
    goldenFileComparator = _Tolerant(
      local.basedir.resolve('flutter_test_config.dart'),
    );
  }
  setUp(() {
    clock = () => fixtureNow;
    resetAppSettings();
    forgetPulls();
    forgetReviews();
    forgetReviewDrafts();
    forgetCommentDrafts();
    forgetPullTabs();
    forgetFilesLeft();
    agentList.value = {};
    shellEnvironment.value = null;
    remoteState.value = null;
    githubFolders.value = {};
    revealWidget.value = null;
  });
  tearDownAll(() {
    final dir = Directory(dataDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  await testMain();
}

class _Tolerant extends LocalFileComparator {
  new(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= 0.01) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
