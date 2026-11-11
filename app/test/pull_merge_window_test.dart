import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pull_merge.dart';

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
/// both themes, all of it inside the window; and the confirmation. Each a
/// render (harness.dart's [render]), not a golden.
/// The Merge control and its words inside a window [width] wide.
void _inside(WidgetTester tester, double width) {
  final control = find.byType(MergeControl);
  final box = tester.getRect(control);
  expect(box.left, greaterThanOrEqualTo(0));
  expect(box.right, lessThanOrEqualTo(width));
  for (final text in tester.widgetList<Text>(
    find.descendant(of: control, matching: find.byType(Text)),
  )) {
    expect(
      tester.getRect(find.byWidget(text)).right,
      lessThanOrEqualTo(box.right),
    );
  }
}

void main() {
  setUpAll(loadFonts);

  for (final (theme, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final state in ['ready', 'blocked', 'auto', 'queue']) {
      for (final width in [1700.0, 720.0]) {
        testWidgets('$state at ${width.toInt()}, $theme', (tester) async {
          final d = await _tab(tester, mergePull(state), width, brightness);
          _inside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            'pull_merge_${state}_${width.toInt()}_$theme',
          );
          d.dispose();
        }, variant: _mac);
      }

      testWidgets('$state in the widget, $theme', (tester) async {
        final (d, _) = await openPullTab(
          tester,
          mergePull(state),
          size: const Size(1700, 1000),
          brightness: brightness,
          details: true,
          open: false,
        );
        _inside(tester, 1700);
        await render(
          tester,
          find.byType(NushiApp),
          'pull_merge_widget_${state}_$theme',
        );
        d.dispose();
      }, variant: _mac);
    }

    for (final width in [1700.0, 720.0]) {
      testWidgets('merged at ${width.toInt()}, $theme', (tester) async {
        final d = await _tab(
          tester,
          mergePull('ready')..item.state = 'merged',
          width,
          brightness,
        );
        expect(find.text('Merged'), findsWidgets);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'pull_merged_${width.toInt()}_$theme',
        );
        d.dispose();
      }, variant: _mac);
    }

    for (final width in [1700.0, 720.0]) {
      testWidgets('the confirmation at ${width.toInt()}, $theme', (
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
        final dialog = tester.getRect(find.byType(Dialog));
        expect(dialog.left, greaterThanOrEqualTo(0));
        expect(dialog.right, lessThanOrEqualTo(width));
        await render(
          tester,
          find.byType(NushiApp),
          'pull_merge_confirm_${width.toInt()}_$theme',
        );
        d.dispose();
      }, variant: _mac);
    }
  }
}
