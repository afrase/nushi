import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/markdown_outline.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/rail.dart';
import 'package:nushi/rail_menu.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';
import 'outline_fixture.dart';

/// [text] outlined on its own, in a pane 900 by 600 in a bigger window, as
/// a preview has it.
Future<void> _outlined(WidgetTester tester, String text) {
  viewport(tester, const Size(1000, 700));
  return tester.pumpWidget(
    themed(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 900,
          height: 600,
          child: OutlinedMarkdown(
            text,
            images: (_, _) => const SizedBox.shrink(),
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
          ),
        ),
      ),
    ),
  );
}

Finder _title(String name) =>
    find.textContaining(name, findRichText: true).first;

void main() {
  setUpAll(loadFonts);

  testWidgets('no outline over the source', (tester) async {
    final d = await outlineApp(tester);
    expect(rail, findsOneWidget);
    await tester.tap(inPane(find.byType(SourceButton)));
    await tester.pumpAndSettle();
    expect(rail, findsNothing);
    await tester.tap(inPane(find.byType(SourceButton)));
    await tester.pumpAndSettle();
    expect(rail, findsOneWidget);
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('the rail: a dash per heading, the current one following '
      'the scroll', (tester) async {
    final d = await outlineApp(tester);
    final r = tester.widget<Rail>(rail);
    expect(
      [for (final e in r.entries) (e.title, e.depth)],
      [
        // A lone title stands with the sections under it, as Claude's.
        ('Roadmap', 0),
        ('Plans', 0),
        ('The app', 1),
        ('Previews', 1),
        ('Changes and review', 1),
        ('GitHub', 1),
        ('Decisions to revisit', 0),
      ],
    );
    expect(r.outline, isTrue);
    expect(railCurrent(tester), 0);
    final scroll = outlineScroll(tester);
    // A heading at the view's top is the current one.
    final previews = tester.getTopLeft(inPane(_title('Previews')));
    final top = tester.getTopLeft(find.byType(OutlinedMarkdown));
    scroll.jumpTo(previews.dy - top.dy - 10);
    await tester.pumpAndSettle();
    expect(railCurrent(tester), 3);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(railCurrent(tester), 0);
    // The rail stays put as the text scrolls, left of it.
    final dash = tester.getRect(find.byType(RailDash).first);
    final text = tester.getRect(inPane(_title('Roadmap')));
    expect(dash.right, lessThan(text.left - RailFit.gap + 0.5));
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('the text stands where it stays from its first frame, the '
      'rail beside it', (tester) async {
    await _outlined(tester, roadmap);
    // One frame: the marks haven't said where they are yet.
    final first = tester.getTopLeft(_title('Roadmap'));
    expect(rail, findsOneWidget);
    expect(tester.widget<Rail>(rail).entries, hasLength(7));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_title('Roadmap')), first);
    // A new text with one heading loses the rail as it shows.
    await _outlined(tester, flatNote);
    expect(rail, findsNothing);
    expect(tester.getTopLeft(_title('Notes')).dx, 28);
  });

  testWidgets("a short text's view fills the pane, for a selection started "
      'below it', (tester) async {
    await _outlined(tester, flatNote);
    await tester.pumpAndSettle();
    const pane = Size(900, 600);
    expect(tester.getSize(find.byType(SelectionArea)), pane);
    expect(tester.getSize(find.byType(Scrollable).first), pane);
    // A drag from under the text up over it selects it.
    final words = tester.getCenter(_title('No other heading'));
    final drag = await tester.startGesture(
      const Offset(600, 500),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveTo(Offset(28, words.dy));
    await drag.up();
    await tester.pump();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(copied, contains('No other heading'));
  }, variant: mac);

  testWidgets('hovering the rail lists the headings; a click scrolls there '
      'and leaving closes it', (tester) async {
    final d = await outlineApp(tester);
    expect(find.byType(RailMenu), findsNothing);
    final mouse = await hoverRail(tester);
    expect(find.byType(RailMenu), findsOneWidget);
    final menu = find.byType(RailMenu);
    expect(
      find.descendant(of: menu, matching: find.text('Changes and review')),
      findsOneWidget,
    );
    // Indented by its level.
    final plans = tester.getTopLeft(
      find.descendant(of: menu, matching: find.text('Plans')),
    );
    final app = tester.getTopLeft(
      find.descendant(of: menu, matching: find.text('The app')),
    );
    expect(app.dx, greaterThan(plans.dx));
    await mouse.moveTo(
      tester.getCenter(
        find.descendant(of: menu, matching: find.text('Previews')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: menu, matching: find.text('Previews')),
    );
    await tester.pumpAndSettle();
    expect(railCurrent(tester), 3);
    expect(outlineScroll(tester).pixels, greaterThan(0));
    final heading = tester.getTopLeft(inPane(_title('Previews')));
    // At the view's top, where the first heading was.
    final view = tester.getTopLeft(find.byType(OutlinedMarkdown));
    expect(heading.dy - view.dy, inInclusiveRange(18, 30));
    await mouse.moveTo(tester.getCenter(find.byType(PreviewBody)));
    await tester.pump(Rail.linger);
    await tester.pumpAndSettle();
    expect(find.byType(RailMenu), findsNothing);
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('under Reduce Motion a pick goes there at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final d = await outlineApp(tester);
    final mouse = await hoverRail(tester);
    final decisions = find.descendant(
      of: find.byType(RailMenu),
      matching: find.text('Decisions to revisit'),
    );
    await mouse.moveTo(tester.getCenter(decisions));
    await tester.pump();
    await tester.tap(decisions);
    await tester.pump();
    final scroll = outlineScroll(tester);
    expect(scroll.pixels, scroll.maxScrollExtent);
    // The last heading, though it can't reach the top.
    expect(railCurrent(tester), 6);
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('no rail with fewer than two headings', (tester) async {
    final d = await outlineApp(tester, file: 'docs/notes.md');
    expect(
      inPane(find.textContaining('No other heading', findRichText: true)),
      findsOneWidget,
    );
    expect(rail, findsNothing);
    await closeView(tester, d);
  }, variant: mac);

  testWidgets('narrow, the rail keeps the text its room', (tester) async {
    final d = await outlineApp(tester);
    paneWidths.value = {'preview': 400};
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PreviewPane)).width, 400);
    final dash = tester.getRect(find.byType(RailDash).first);
    final text = tester.getRect(inPane(_title('Roadmap')));
    final pane = tester.getRect(find.byType(PreviewPane));
    expect(text.left - pane.left, lessThanOrEqualTo(40));
    expect(dash.right, lessThanOrEqualTo(text.left - RailFit.gap + 0.5));
    expect(tester.takeException(), isNull);
    await closeView(tester, d);
  }, variant: mac);
}
