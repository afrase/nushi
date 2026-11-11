import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/transcript_pages.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The chat's transcript glides as a pane beside it, or the sidebar, comes
// and goes (slides.dart's Glide): it's laid out at its new width and drawn
// from where its text was. The composer at its foot, with its backdrop the
// pane's full width (OverBottom), is drawn with it, and nothing of it may
// show left of the transcript's own slot: closing the details on a wide
// window drew the composer's foot over the sidebar for the glide's length.
// Drawn right of its slot it slides under the panes, drawn over it, and
// isn't cut: a pane opening at the right on a wide window has barely come
// in on its first frames, and a cut at the slot's edge chopped the
// composer, its border and its corner, in plain sight. The chat's pane
// cuts what's in it to its own corners, at the window's margin, and never
// moves: its details slide inside it (ADR 0111).

final _items = [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Where is the login redirect handled?',
  ),
  Item(
    id: 'm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'It is handled in the redirect module.',
  ),
];

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Future<Daemon> _app(WidgetTester tester, double width) async {
  viewport(tester, Size(width, 800));
  showDetails.value = false;
  sidebarHidden.value = false;
  filesChats.value = {};
  paneWidths.value = {};
  final c = chat('c', 'claude', 'Fix the login redirect');
  final fake = FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: c, items: _items),
      ListFilesRequest() => ListFilesResponse(paths: ['README.md']),
      _ => null,
    })
    // The Files pane's folder, watched until the test ends, so it never
    // lists again on a timer.
    ..streams = (input) {
      if (input is! WatchChatFolderRequest) return null;
      final s = StreamController<WatchChatFolderResponse>();
      addTearDown(s.close);
      return s.stream;
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

/// The part of [box] that shows, in the window: its bounds as drawn,
/// through every transform above it, cut by every clip above it unless
/// [clips] is false.
Rect _shown(RenderBox box, {bool clips = true}) {
  var rect = Offset.zero & box.size;
  RenderObject child = box;
  for (var parent = box.parent; parent != null; parent = parent.parent) {
    if (parent is RenderView) break;
    final m = Matrix4.identity();
    parent.applyPaintTransform(child, m);
    rect = MatrixUtils.transformRect(m, rect);
    if (parent.describeApproximatePaintClip(child) case final clip?
        when clips) {
      rect = rect.intersect(clip);
    }
    child = parent;
  }
  return rect;
}

/// The chat's own transcript's Glide (a side chat has one too, under
/// its own glide): the one that follows the text's column.
Finder get _main =>
    find.byWidgetPredicate((w) => w is Glide && w.sides != null);

/// The transcript's slot as laid out: its Glide's box, which a glide
/// doesn't move (only what it draws).
Rect _slot(WidgetTester tester) => tester.getRect(_main);

/// Every box of the chat's composer and its backdrop, the foot of
/// OverBottom the pane's full width.
Iterable<RenderBox> _composer(WidgetTester tester) sync* {
  final composer = find.descendant(of: _main, matching: find.byType(Composer));
  final foot = find.descendant(
    of: find.descendant(of: _main, matching: find.byType(OverBottom)),
    matching: find.ancestor(of: composer, matching: find.byType(ColoredBox)),
  );
  for (final f in [foot.first, composer]) {
    yield tester.renderObject<RenderBox>(f);
    for (final e
        in find
            .descendant(of: f, matching: find.byWidgetPredicate((_) => true))
            .evaluate()) {
      if (e.renderObject case final RenderBox b when b.hasSize) yield b;
    }
  }
}

/// Runs [change] and, frame by frame through the glide, notes in [spills]
/// what of the composer shows left of the transcript's slot or the
/// sidebar's edge, and what of the composer's own box is cut at its right,
/// rendering a few of the frames as [name].
Future<void> _glide(
  WidgetTester tester,
  List<String> spills,
  String name,
  VoidCallback change,
) async {
  change();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final slot = _slot(tester);
    final sidebar = find.byType(Sidebar);
    final edge = sidebar.evaluate().isEmpty || sidebarHidden.value
        ? 0.0
        : tester.getRect(sidebar).right;
    final left = slot.left > edge ? slot.left : edge;
    final out = _composer(tester)
        .map(_shown)
        .where((r) => !r.isEmpty)
        .where((r) => r.left < left - 0.5);
    if (out.isNotEmpty) {
      final r = out.reduce((a, b) => a.expandToInclude(b));
      spills.add(
        '$name frame $i: drawn ${r.left}..${r.right}, '
        'the transcript ${slot.left}..${slot.right}, sidebar to $edge',
      );
    }
    final box = tester.renderObject<RenderBox>(
      find.descendant(of: _main, matching: find.byType(Composer)),
    );
    final drawn = _shown(box, clips: false);
    final shown = _shown(box);
    // The chat's pane cuts what's in it at its own edge (ADR 0111), the
    // window's margin: past that edge there's nothing to show, so only a
    // cut short of it is one to see.
    final end = tester.getRect(find.byType(Pane)).right;
    if (shown.right < min(drawn.right, end) - 0.5) {
      spills.add(
        '$name frame $i: the composer drawn to ${drawn.right}, '
        'cut at ${shown.right}',
      );
    }
    if (i == 0 || i == 2 || i == 5 || i == 9) {
      await render(tester, find.byType(NushiApp), '${name}_f$i');
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  for (final width in [1700.0, 1400.0, 1100.0]) {
    final w = width.toInt();
    testWidgets('$w wide with the sidebar: the composer stays off the '
        'sidebar, uncut, as the details slide in and out', (tester) async {
      final d = await _app(tester, width);
      final spills = <String>[];
      await _glide(tester, spills, 'glide_${w}_details_in', () {
        showDetails.value = true;
      });
      await _glide(tester, spills, 'glide_${w}_details_out', () {
        showDetails.value = false;
      });
      await closeView(tester, d);
      expect(spills, isEmpty);
    }, variant: _mac);

    testWidgets('$w wide: the composer stays off the sidebar, uncut, as '
        'the sidebar, the Files pane and a side chat come and go', (
      tester,
    ) async {
      final d = await _app(tester, width);
      final spills = <String>[];
      await _glide(tester, spills, 'glide_${w}_sidebar_out', () {
        sidebarHidden.value = true;
      });
      await _glide(tester, spills, 'glide_${w}_sidebar_in', () {
        sidebarHidden.value = false;
      });
      await _glide(tester, spills, 'glide_${w}_files_in', () {
        filesChats.value = {'c'};
      });
      await _glide(tester, spills, 'glide_${w}_files_out', () {
        filesChats.value = {};
      });
      await _glide(tester, spills, 'glide_${w}_side_in', () {
        d.chats['c']!.side.value = ChatState('s', '/Users/me')..title = 'Side';
      });
      await _glide(tester, spills, 'glide_${w}_side_out', () {
        d.chats['c']!.side.value = null;
      });
      await closeView(tester, d);
      expect(spills, isEmpty);
    }, variant: _mac);
  }
}
