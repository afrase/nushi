import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/motion.dart';

/// On CI (GitHub's macOS image draws text a few pixels differently from a
/// Mac), a golden may differ in up to 1% of its pixels (a card dense with
/// text, as a review's findings, reaches 0.56% from anti-aliasing alone);
/// here it must match. Every shine stands still, its band before the text,
/// and so does every loop on the shared clock that reads `loopPhase` (a
/// pull request's running ring, a streaming reply's caret), so goldens are
/// one frame and pumpAndSettle settles while a call runs.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Shine.stopAt = 0;
  final local = goldenFileComparator;
  if (Platform.environment['CI'] == 'true' && local is LocalFileComparator) {
    goldenFileComparator = _Tolerant(
      local.basedir.resolve('flutter_test_config.dart'),
    );
  }
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
