import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/account_rows.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/native.dart';
import 'package:nushi/token_notices.dart';

import 'harness.dart';

void main() {
  // A token that needs the user's OK says so in the platform's words: the
  // Mac's keychain for a new build, Linux's locked keyring, as the
  // daemon's errors do (ADR 0104). "This build" is only the Mac's case.
  for (final (system, words) in [
    ('macOS', macConventions),
    ('Linux', linuxConventions),
  ]) {
    testWidgets('needing an OK names the $system store', (tester) async {
      native.conventions = words;
      final want =
          'Nushi needs your OK to read the token from the ${words.keyring}: '
          '$system asks for your password.';
      expect(needsOkStatus, want);
      await tester.pumpWidget(
        themed(
          TokenNotices(
            needsOk: true,
            needsRestart: false,
            problem: '',
            onAllow: () {},
            onRestart: () {},
          ),
        ),
      );
      expect(find.textContaining(want), findsOneWidget);
    });
  }
}
