import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

final _text = GetGitHubMergeTextResponse(
  squashTitle: "Ignore q params that aren't hashes in admin filters (#412)",
  squashBody:
      '* Treat a non-hash q as missing\n\n* Tests for each filter that reads q',
);

/// The Pull request tab of [p] at [width]. The header folds its tabs at 720,
/// so it's opened wide and the window narrowed, as a person would.
Future<Daemon> _tab(
  WidgetTester tester,
  GitHubPull p,
  double width,
  Brightness brightness, {
  Object? Function(Object input)? more,
}) async {
  final (d, _) = await openPullTab(
    tester,
    p,
    size: const Size(1700, 1000),
    brightness: brightness,
    more: more,
  );
  viewport(tester, Size(width, 1000));
  await tester.pumpAndSettle();
  return d;
}

/// The Merge control in each state, in the Pull request tab at the window's
/// real widths and in the details widget (which shows beside the chat), in
/// both themes; and the confirmation.
void main() {
  setUpAll(loadFonts);

  for (final (theme, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final state in ['ready', 'blocked', 'auto', 'queue']) {
      for (final width in [1700.0, 720.0]) {
        testWidgets('golden: $state at ${width.toInt()}, $theme', (
          tester,
        ) async {
          final d = await _tab(tester, mergePull(state), width, brightness);
          await expectLater(
            find.byType(NushiApp),
            matchesGoldenFile(
              'goldens/pull_merge_${state}_${width.toInt()}_$theme.png',
            ),
          );
          d.dispose();
        }, variant: _mac);
      }

      testWidgets('golden: $state in the widget, $theme', (tester) async {
        final (d, _) = await openPullTab(
          tester,
          mergePull(state),
          size: const Size(1700, 1000),
          brightness: brightness,
          details: true,
          open: false,
        );
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/pull_merge_widget_${state}_$theme.png'),
        );
        d.dispose();
      }, variant: _mac);
    }

    for (final width in [1700.0, 720.0]) {
      testWidgets('golden: the confirmation at ${width.toInt()}, $theme', (
        tester,
      ) async {
        final d = await _tab(
          tester,
          mergePull('ready'),
          width,
          brightness,
          more: (input) => input is GetGitHubMergeTextRequest ? _text : null,
        );
        await tester.tap(find.text('Squash and merge').first);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile(
            'goldens/pull_merge_confirm_${width.toInt()}_$theme.png',
          ),
        );
        d.dispose();
      }, variant: _mac);
    }
  }
}
