import 'package:diff_view/diff_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/back_swipe.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_pull.dart';

import 'fake_daemon.dart';
import 'github_view_test.dart' show closeView, openView;

/// Two fingers on the trackpad at [at], panning [pan] in five moves; let
/// go unless [lift] is false (the gesture is returned to end later).
Future<TestGesture> swipe(
  WidgetTester tester,
  Offset at,
  Offset pan, {
  bool lift = true,
}) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.trackpad);
  await g.panZoomStart(at);
  for (var i = 1; i <= 5; i++) {
    await g.panZoomUpdate(at, pan: pan * (i / 5));
  }
  await tester.pump();
  if (lift) {
    await g.panZoomEnd();
    await tester.pumpAndSettle();
  }
  return g;
}

/// The middle of the pull request's pane.
Offset _pane(WidgetTester tester) =>
    tester.getCenter(find.byType(GitHubPullPane));

/// Pull request 1 open in the GitHub view.
Future<void> _openPull(WidgetTester tester) async {
  await tester.tap(find.text('Add Sub and Neg'));
  await tester.pumpAndSettle();
  expect(find.byType(GitHubPullPane), findsOneWidget);
}

/// A file whose lines are wider than the diff.
final _wide = FileChange(
  path: 'wide.go',
  status: 'modified',
  oldText: '// ${'x' * 300}\n' * 3,
  newText: '// ${'y' * 300}\n' * 3,
  added: 3,
  removed: 3,
);

void main() {
  setUpAll(loadFonts);

  testWidgets('two fingers right past the threshold go back; short of it, '
      "or up and down, they don't", (tester) async {
    final (_, d) = await openView(tester);
    await _openPull(tester);
    await swipe(tester, _pane(tester), const Offset(backSwipeAt * 0.7, 0));
    expect(find.byType(GitHubPullPane), findsOneWidget);
    expect(find.byType(BackArrow), findsNothing); // it faded
    await swipe(tester, _pane(tester), const Offset(40, 220)); // a scroll
    expect(find.byType(GitHubPullPane), findsOneWidget);
    await swipe(tester, _pane(tester), const Offset(-200, 0)); // forward
    expect(find.byType(GitHubPullPane), findsOneWidget);
    await swipe(tester, _pane(tester), const Offset(backSwipeAt + 10, 8));
    expect(find.byType(GitHubPullPane), findsNothing);
    expect(find.text('Review requested  1'), findsOneWidget);
    await closeView(tester, d);
  });

  testWidgets("the mouse's back button goes back", (tester) async {
    final (_, d) = await openView(tester);
    await _openPull(tester);
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    await mouse.down(_pane(tester));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.byType(GitHubPullPane), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('over a diff scrolled right, the swipe scrolls the diff; at '
      'its left edge it goes back', (tester) async {
    final (_, d) = await openView(
      tester,
      size: const Size(1300, 800),
      more: (input) => input is GetGitHubFilesRequest
          ? GetGitHubFilesResponse(files: [_wide])
          : null,
    );
    await _openPull(tester);
    await tester.tap(find.text('Files 3'));
    await tester.pumpAndSettle();
    final diff = find.byType(SideBySideDiff);
    final horizontal = tester
        .widget<SideBySideDiff>(diff)
        .controller
        .horizontal;
    // On the new side's first line.
    final box = tester.getRect(diff);
    final at = Offset(box.left + box.width * 0.75, box.top + 20);
    await swipe(tester, at, const Offset(-300, 0));
    expect(horizontal.value, 300);
    await swipe(tester, at, const Offset(backSwipeAt + 60, 0));
    expect(horizontal.value, 300 - backSwipeAt - 60);
    expect(find.byType(GitHubPullPane), findsOneWidget);
    // Scrolled back to its edge in this swipe: still the diff's.
    await swipe(tester, at, const Offset(backSwipeAt + 60, 0));
    expect(horizontal.value, 0);
    expect(find.byType(GitHubPullPane), findsOneWidget);
    // From the edge: back.
    await swipe(tester, at, const Offset(backSwipeAt + 60, 0));
    expect(find.byType(GitHubPullPane), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('with Reduce Motion no arrow, only the going back', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final (_, d) = await openView(tester);
    await _openPull(tester);
    final g = await swipe(
      tester,
      _pane(tester),
      const Offset(backSwipeAt, 0),
      lift: false,
    );
    expect(find.byType(BackArrow), findsNothing);
    await g.panZoomEnd();
    await tester.pumpAndSettle();
    expect(find.byType(GitHubPullPane), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('golden: the arrow mid-swipe, dark', (tester) async {
    final (_, d) = await openView(tester);
    await _openPull(tester);
    final g = await swipe(
      tester,
      _pane(tester),
      const Offset(20 + (backSwipeAt - 20) * 0.6, 0),
      lift: false,
    );
    expect(find.byType(BackArrow), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/back_swipe_dark.png'),
    );
    await g.panZoomEnd();
    await tester.pumpAndSettle();
    expect(find.byType(GitHubPullPane), findsOneWidget);
    await closeView(tester, d);
  });
}
