import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// On CI (GitHub's macOS image draws text a few pixels differently from a
/// Mac), a golden may differ in up to 0.5% of its pixels; here it must
/// match.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
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
    if (result.passed || result.diffPercent <= 0.005) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
