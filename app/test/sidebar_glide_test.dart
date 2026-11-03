import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_button.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The sidebar's button is one button: as the sidebar slides out it moves
// from the sidebar's header to past the lights, and back as it slides in,
// rather than one leaving with the sidebar while another is already there.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Future<Daemon> _window(
  WidgetTester tester, {
  required bool hidden,
  bool still = false,
}) async {
  viewport(tester, const Size(1700, 700));
  if (still) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  sidebarHidden.value = hidden;
  paneWidths.value = {};
  final d = await FakeDaemon([chat('a', 'claude', 'Fix the login redirect')])
      .connect(tester);
  d.select('a');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

/// Whether [box] is drawn: nothing over it skips it (offstage, faded out)
/// and, for a [SidebarButton], its own box draws it.
bool _drawn(RenderObject box) {
  for (RenderObject? r = box; r != null; r = r.parent) {
    if (r is RenderOffstage && r.offstage) return false;
    if (r is RenderOpacity && r.opacity == 0) return false;
    if (r is RenderAnimatedOpacity && r.opacity.value == 0) return false;
  }
  return !paintsNothing.matches(box, {});
}

/// The sidebar buttons drawn, where they're drawn.
List<Rect> _buttons(WidgetTester tester) => [
  for (final e in find.byType(SidebarButton).evaluate())
    if (_drawn(e.renderObject!))
      // The button in it: the moving one's own box stays at its origin.
      tester.getRect(
        find
            .descendant(
              of: find.byElementPredicate((x) => x == e),
              matching: find.byType(IconTap),
            )
            .first,
      ),
];

/// Where the chat's title in its header is drawn.
double _title(WidgetTester tester) => tester
    .getTopLeft(
      find.descendant(
        of: find.byType(ChatHeader),
        matching: find.text('Fix the login redirect'),
      ),
    )
    .dx;

/// Where the sidebar's right edge is drawn.
double _sidebarEnd(WidgetTester tester) =>
    tester.getTopRight(find.byType(Sidebar)).dx;

/// The one sidebar button drawn.
Rect _button(WidgetTester tester) {
  final drawn = _buttons(tester);
  expect(drawn, hasLength(1), reason: 'one button drawn, not $drawn');
  return drawn.single;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('hiding, the one button moves from the sidebar to past the '
      'lights with the slide; showing, back', (tester) async {
    final d = await _window(tester, hidden: false);
    final inSidebar = _button(tester);
    sidebarHidden.value = true;
    await tester.pumpAndSettle();
    final pastLights = _button(tester);
    expect(pastLights.left, lightsInset);
    sidebarHidden.value = false;
    await tester.pumpAndSettle();
    expect(_button(tester), inSidebar);

    for (final (hide, length) in [(true, Motion.exit), (false, Motion.enter)]) {
      final (from, to) = hide
          ? (inSidebar, pastLights)
          : (pastLights, inSidebar);
      sidebarHidden.value = hide;
      await tester.pump();
      expect(_button(tester).topLeft, from.topLeft);
      var was = from.left;
      for (final _ in [1, 2]) {
        await tester.pump(length ~/ 3);
        final at = _button(tester);
        // Between its two places, a step further on each time.
        expect(at.left, inExclusiveRange(pastLights.left, inSidebar.left));
        expect(hide ? at.left < was : at.left > was, isTrue);
        was = at.left;
        // The header's title moves with the sidebar's edge, clear of it.
        expect(_title(tester), greaterThan(at.right));
        expect(_title(tester), greaterThan(_sidebarEnd(tester)));
      }
      await tester.pumpAndSettle();
      expect(_button(tester), to);
    }
    d.dispose();
  }, variant: _mac);

  testWidgets('hidden at launch, the button moves into the sidebar as it '
      'first slides in', (tester) async {
    final d = await _window(tester, hidden: true);
    final pastLights = _button(tester);
    sidebarHidden.value = false;
    await tester.pump();
    expect(_button(tester), pastLights);
    await tester.pump(Motion.enter ~/ 3);
    final at = _button(tester);
    await tester.pumpAndSettle();
    final inSidebar = _button(tester);
    expect(at.left, inExclusiveRange(pastLights.left, inSidebar.left));
    expect(inSidebar.right, tester.getRect(find.byType(Sidebar)).right - 10);
    d.dispose();
  }, variant: _mac);

  testWidgets('a click mid-slide lands on the button where it is drawn and '
      'turns the slide back from there', (tester) async {
    final d = await _window(tester, hidden: false);
    final inSidebar = _button(tester);
    var toggles = 0;
    void count() => toggles++;
    sidebarHidden.addListener(count);
    addTearDown(() => sidebarHidden.removeListener(count));

    toggleSidebar();
    await tester.pump();
    await tester.pump(Motion.exit ~/ 2);
    final at = _button(tester);
    final sidebar = tester.getTopLeft(find.byType(Sidebar)).dx;
    expect(at.left, lessThan(inSidebar.left));
    await tester.tapAt(at.center);
    await tester.pump();
    expect(toggles, 2);
    expect(sidebarHidden.value, isFalse);
    // From where it was, back toward the sidebar's header.
    expect(_button(tester).left, moreOrLessEquals(at.left, epsilon: 2));
    await tester.pump(const Duration(milliseconds: 40));
    expect(_button(tester).left, greaterThan(at.left));
    expect(tester.getTopLeft(find.byType(Sidebar)).dx, greaterThan(sidebar));
    await tester.pumpAndSettle();
    expect(_button(tester), inSidebar);
    expect(toggles, 2);
    d.dispose();
  }, variant: _mac);

  testWidgets('with Reduce Motion the button is at its place at once', (
    tester,
  ) async {
    final d = await _window(tester, hidden: false, still: true);
    sidebarHidden.value = true;
    await tester.pump();
    expect(_button(tester).left, lightsInset);
    sidebarHidden.value = false;
    await tester.pump();
    final at = _button(tester);
    await tester.pumpAndSettle();
    expect(_button(tester), at);
    d.dispose();
  }, variant: _mac);
}
