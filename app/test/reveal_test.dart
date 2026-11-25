import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/grow.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pinned_plan.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/thinking.dart';
import 'package:nushi/transcript_entries.dart';
import 'package:nushi/turn_status.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pinned_plan_fixture.dart';

// Every height reveal, part way, on the test's fixed clock: how tall it
// is, what of its child it clips to and where a pointer reaches it. The
// child is laid out whole throughout; a reveal from the top shows its
// top, one from the bottom its bottom, cut at the reveal's edge, and a
// pointer finds it only where it shows.

const _key = ValueKey<String>('child');

/// A child of 30 that a pointer hits anywhere on it.
Widget _box() => const ColoredBox(
  key: _key,
  color: Color(0xFF336699),
  child: SizedBox(height: 30),
);

/// [reveal] over a strip whose top says how tall the reveal is.
Widget _column(Widget reveal) => themed(
  Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          reveal,
          const SizedBox(key: ValueKey('below'), height: 10),
        ],
      ),
    ),
  ),
);

double _below(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('below'))).dy;

/// The clip that cuts [child]'s rect: the shortest clip layer, in the
/// window's coordinates, that's shorter than it and overlaps it.
Rect _clip(WidgetTester tester, Rect child) {
  final clips = <Rect>[];
  void walk(Layer layer, Offset at) {
    var origin = at;
    if (layer is OffsetLayer) origin += layer.offset;
    if (layer is ClipRectLayer) {
      final r = layer.clipRect!.shift(origin);
      if (r.overlaps(child) && r.height < child.height - 0.01) clips.add(r);
    }
    if (layer is ContainerLayer) {
      for (var c = layer.firstChild; c != null; c = c.nextSibling) {
        walk(c, origin);
      }
    }
  }

  walk(tester.binding.renderViews.first.debugLayer!, Offset.zero);
  expect(clips, isNotEmpty, reason: 'a clip cuts the child');
  // The nearest: a view's own clips around it (the window's, a scroll
  // view's) are taller.
  return clips.reduce((a, b) => a.height <= b.height ? a : b);
}

/// Whether a pointer at [p] reaches [target].
bool _hits(WidgetTester tester, Offset p, RenderObject target) =>
    tester.hitTestOnBinding(p).path.any((e) => e.target == target);

/// Checks a reveal at a moment: [child]'s rect is laid out whole, the
/// clip shows [f] of it from its top (or its bottom when [bottom]), and,
/// when [hit] is given, a pointer reaches it in the part that shows and
/// not in the part cut off.
void _check(
  WidgetTester tester,
  Finder child,
  double f, {
  bool bottom = false,
  RenderObject? hit,
  double? full,
}) {
  final r = tester.getRect(child);
  if (full != null) expect(r.height, full, reason: 'laid out whole');
  expect(f, inExclusiveRange(0, 1), reason: 'part way');
  final clip = _clip(tester, r);
  expect(clip.height, moreOrLessEquals(r.height * f, epsilon: 0.01));
  if (bottom) {
    expect(clip.bottom, moreOrLessEquals(r.bottom, epsilon: 0.01));
  } else {
    expect(clip.top, moreOrLessEquals(r.top, epsilon: 0.01));
  }
  expect(clip.left, lessThanOrEqualTo(r.left));
  expect(clip.right, greaterThanOrEqualTo(r.right));
  if (hit == null) return;
  final x = r.left + 4;
  // The middle of what shows, and of what's cut off.
  final shown = (clip.top + clip.bottom) / 2;
  final cut = bottom ? (r.top + clip.top) / 2 : (clip.bottom + r.bottom) / 2;
  expect(_hits(tester, Offset(x, shown), hit), isTrue, reason: 'shown');
  if (r.height - clip.height < 1) return;
  expect(_hits(tester, Offset(x, cut), hit), isFalse, reason: 'cut off');
}

/// The opacity [Faded] or an [Opacity] under [of] draws at.
double _opacity(WidgetTester tester, Finder of) {
  final faded = find.descendant(of: of, matching: find.byType(Faded));
  if (faded.evaluate().isNotEmpty) {
    return tester.widget<Faded>(faded.first).opacity;
  }
  return tester
      .widget<Opacity>(find.descendant(of: of, matching: find.byType(Opacity)))
      .opacity;
}

/// What the [Opacity] under [of] draws: the line a fold shows part of.
Finder _faded(Finder of) => find
    .descendant(
      of: find.descendant(of: of, matching: find.byType(Opacity)),
      matching: find.byWidgetPredicate((_) => true),
    )
    .first;

/// A moment [part] of the way through [d].
Duration _at(Duration d, double part) => d * part;

void main() {
  setUpAll(loadFonts);

  for (final down in [true, false]) {
    testWidgets('a bar ${down ? 'sliding down' : 'rising'} shows its '
        '${down ? 'bottom' : 'top'} part way, clipped, hit only where it '
        'shows', (tester) async {
      Widget bar({required bool shown}) =>
          _column(BarSlide(down: down, child: shown ? _box() : null));
      await tester.pumpWidget(bar(shown: false));
      await tester.pumpWidget(bar(shown: true));
      var was = Duration.zero;
      for (final part in [0.2, 0.5, 0.8]) {
        await tester.pump(_at(Motion.standard, part) - was);
        was = _at(Motion.standard, part);
        final f = Motion.settle.transform(part);
        expect(_below(tester), moreOrLessEquals(30 * f, epsilon: 0.01));
        expect(_opacity(tester, find.byType(BarSlide)), closeTo(f, 0.01));
        _check(
          tester,
          find.byKey(_key),
          f,
          bottom: down,
          full: 30,
          hit: tester.renderObject(find.byKey(_key)),
        );
      }
      await tester.pumpAndSettle();
      expect(_below(tester), 30);

      // Going it's eased by Motion.leave, and takes no pointer.
      await tester.pumpWidget(bar(shown: false));
      was = Duration.zero;
      for (final part in [0.2, 0.5, 0.8]) {
        await tester.pump(_at(Motion.exit, part) - was);
        was = _at(Motion.exit, part);
        final f = Motion.leave.flipped.transform(1 - part);
        expect(_below(tester), moreOrLessEquals(30 * f, epsilon: 0.01));
        _check(tester, find.byKey(_key), f, bottom: down, full: 30);
      }
    });
  }

  testWidgets('a line grows in from its top over Motion.standard on '
      'Motion.size and folds away the same way', (tester) async {
    Widget line({required bool shown}) =>
        _column(GrowLine(child: shown ? _box() : null));
    await tester.pumpWidget(line(shown: false));
    await tester.pumpWidget(line(shown: true));
    var was = Duration.zero;
    for (final part in [0.2, 0.5, 0.8]) {
      await tester.pump(_at(Motion.standard, part) - was);
      was = _at(Motion.standard, part);
      final f = Motion.size.transform(part);
      expect(_below(tester), moreOrLessEquals(30 * f, epsilon: 0.01));
      expect(tester.getSize(find.byKey(_key)).width, 400);
      _check(
        tester,
        find.byKey(_key),
        f,
        full: 30,
        hit: tester.renderObject(find.byKey(_key)),
      );
    }
    await tester.pumpAndSettle();
    expect(_below(tester), 30);
    await tester.pumpWidget(line(shown: false));
    was = Duration.zero;
    for (final part in [0.2, 0.5, 0.8]) {
      await tester.pump(_at(Motion.exit, part) - was);
      was = _at(Motion.exit, part);
      final f = Motion.leave.flipped.transform(1 - part);
      expect(_below(tester), moreOrLessEquals(30 * f, epsilon: 0.01));
      _check(tester, find.byKey(_key), f, full: 30);
    }
  });

  testWidgets("the pinned plan's steps fold away from their top, its line "
      'staying put', (tester) async {
    final chat = ChatState('c', '/x')
      ..loaded = true
      ..busy = true
      ..started = clock().subtract(const Duration(minutes: 1))
      ..items.addAll(planItems());
    await tester.pumpWidget(_column(PinnedPlan(chat)));
    await frames(tester, 6, const Duration(milliseconds: 100));
    final step = find.descendant(
      of: find.byType(PinnedPlan),
      matching: find.textContaining('Page the feed', findRichText: true),
    );
    // The steps' column: the steps, scrolling, over a hairline.
    final steps = find.ancestor(
      of: step,
      matching: find.byWidgetPredicate(
        (w) => w is Column && w.children.first is ConstrainedBox,
      ),
    );
    final full = tester.getSize(steps).height;
    planCollapsed.value = true;
    await tester.pump();
    var was = Duration.zero;
    for (final part in [0.2, 0.5, 0.8]) {
      await tester.pump(_at(Motion.exit, part) - was);
      was = _at(Motion.exit, part);
      final f = Motion.leave.flipped.transform(1 - part);
      _check(tester, steps, f, bottom: true, full: full);
    }
  });

  testWidgets('a message sent folds away from its top, fading', (tester) async {
    Widget entry(int state) =>
        _column(SendingEntry(state: state, child: _box()));
    await tester.pumpWidget(entry(1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(entry(2));
    var was = Duration.zero;
    for (final part in [0.2, 0.5, 0.8]) {
      await tester.pump(_at(Motion.exit, part) - was);
      was = _at(Motion.exit, part);
      final f = 1 - Motion.leave.transform(part);
      expect(
        _opacity(tester, find.byType(SendingEntry)),
        closeTo(0.7 * f, 0.01),
      );
      expect(_below(tester), moreOrLessEquals(30 * f, epsilon: 0.01));
      _check(tester, find.byKey(_key), f, full: 30);
      // At its width at rest, not loosened as an Align would.
      expect(tester.getSize(find.byKey(_key)).width, 400);
    }
  });

  testWidgets("a thought's line folds away from its top as it ends", (
    tester,
  ) async {
    Widget thought({required bool live}) => _column(
      ThoughtView(
        Item(id: 't', kind: ItemKind.ITEM_KIND_THOUGHT, text: 'Splitting.'),
        live: live,
      ),
    );
    await tester.pumpWidget(thought(live: true));
    await tester.pump();
    final text = find.text('Splitting.');
    final at = tester.getRect(text);
    await tester.pumpWidget(thought(live: false));
    await tester.pump(const Duration(milliseconds: 16));
    for (final ms in [40, 60, 60]) {
      await tester.pump(Duration(milliseconds: ms));
      final f = _opacity(tester, find.byType(ThoughtView));
      _check(
        tester,
        _faded(find.byType(ThoughtView)),
        f,
        hit: tester.renderObject(text),
      );
      expect(tester.getRect(text), at, reason: 'it folds where it was');
    }
  });

  testWidgets('in a short window the turn line folds away from its top as '
      'a turn ends', (tester) async {
    viewport(tester, const Size(720, TurnStatus.roomFrom - 80));
    final chat = ChatState('c', '/x')
      ..loaded = true
      ..busy = true
      ..started = clock().subtract(const Duration(seconds: 4))
      ..items.add(
        Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Go'),
      );
    await tester.pumpWidget(_column(TurnStatus(chat)));
    final whole = tester.getSize(find.byType(TurnStatus)).height;
    chat
      ..busy = false
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    for (final ms in [40, 60, 60]) {
      await tester.pump(Duration(milliseconds: ms));
      final f = _opacity(tester, find.byType(TurnStatus));
      expect(
        tester.getSize(find.byType(TurnStatus)).height,
        moreOrLessEquals(whole * f, epsilon: 0.01),
      );
      final line = _faded(find.byType(TurnStatus));
      _check(tester, line, f, full: whole);
    }
  });
}
