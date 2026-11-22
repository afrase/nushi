import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'harness.dart';

/// A pane's edge driven by the pointer events the Mac's engine sends,
/// including the ones it sends when a release or a gesture's end never
/// reached it (ADR 0080, amended 2026-11-19): a drag runs only while its
/// press is held, and a trackpad's two-finger scroll never drags.
void main() {
  late List<double?> told;
  final locked = ValueNotifier(false);
  final shown = ValueNotifier(true);

  Future<void> pane(WidgetTester tester) async {
    viewport(tester, const Size(1200, 600));
    told = [];
    locked.value = false;
    shown.value = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Align(
          alignment: Alignment.centerRight,
          child: ListenableBuilder(
            listenable: Listenable.merge([locked, shown]),
            builder: (context, _) => shown.value
                ? Resizable(
                    name: 'preview',
                    initial: 400,
                    min: 300,
                    max: 700,
                    left: true,
                    locked: locked.value,
                    onDrag: told.add,
                    child: const SizedBox.expand(key: Key('pane')),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  double width(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('pane'))).width;

  /// The middle of the pane's edge, at its left.
  Offset edge(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const Key('pane'))) +
      const Offset(Resizable.edgeWidth / 2, 100);

  // The engine gives each press a pointer of its own, on the one mouse.
  var pointers = 10;
  TestPointer mouse() => TestPointer(pointers++, PointerDeviceKind.mouse, 0);

  Future<void> send(WidgetTester tester, PointerEvent e) async {
    await tester.sendEventToBinding(e);
    await tester.pump();
  }

  /// The mouse pressed on the edge and dragged left by [by], in steps of
  /// 10: past a mouse's slop at the first.
  Future<TestPointer> grab(WidgetTester tester, {double by = 40}) async {
    final press = mouse();
    final at = edge(tester);
    await send(tester, press.hover(at));
    await send(tester, press.down(at));
    for (var x = 10.0; x <= by; x += 10) {
      await send(tester, press.move(at - Offset(x, 0)));
    }
    return press;
  }

  /// A click at [at]: a press and its release, a pointer of its own.
  Future<void> click(WidgetTester tester, Offset at) async {
    final press = mouse();
    await send(tester, press.hover(at));
    await send(tester, press.down(at));
    await send(tester, press.up());
  }

  String log() {
    final f = File('$dataDir/app.log');
    return f.existsSync() ? f.readAsStringSync() : '';
  }

  /// The pane's width after the save's pause, and what was saved.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 2));

  testWidgets('a mouse drag resizes, and its release ends it', (tester) async {
    await pane(tester);
    final mouse = await grab(tester);
    expect(width(tester), 430); // the first 10 is the slop
    await send(tester, mouse.up());
    expect(told, [410, 420, 430, null]);
    expect(paneWidths.value['preview'], 430);
    await settle(tester);
  });

  testWidgets('a two-finger scroll over the edge resizes nothing', (
    tester,
  ) async {
    await pane(tester);
    final pad = TestPointer(1, PointerDeviceKind.trackpad);
    final at = edge(tester);
    await send(tester, pad.panZoomStart(at));
    for (var i = 1; i <= 5; i++) {
      await send(tester, pad.panZoomUpdate(at, pan: Offset(-20.0 * i, 0)));
    }
    await send(tester, pad.panZoomEnd());
    expect(width(tester), 400);
    expect(told, isEmpty);
    expect(paneWidths.value, isEmpty);
  });

  testWidgets('fingers resting on the trackpad, then a click-drag: the '
      'release ends it, and the fingers moving after resize nothing', (
    tester,
  ) async {
    // Before, the resting fingers' pan/zoom (the engine starts one on
    // NSEventPhaseMayBegin) won the edge at once, the click joined it, and
    // its release ended nothing: the fingers then dragged the edge with no
    // button held, until their gesture's end came, if it did.
    await pane(tester);
    final pad = TestPointer(1, PointerDeviceKind.trackpad);
    final at = edge(tester);
    await send(tester, pad.panZoomStart(at));
    final mouse = await grab(tester);
    await send(tester, mouse.up());
    expect(told, [410, 420, 430, null]);
    for (var i = 1; i <= 5; i++) {
      await send(tester, pad.panZoomUpdate(at, pan: Offset(-20.0 * i, 0)));
    }
    expect(width(tester), 430);
    expect(told, [410, 420, 430, null]);
    await send(tester, pad.panZoomEnd());
    await settle(tester);
  });

  testWidgets("a scroll's end that never comes leaves nothing held: each "
      'press drags and ends, and a double click resets', (tester) async {
    await pane(tester);
    final pad = TestPointer(1, PointerDeviceKind.trackpad);
    await send(tester, pad.panZoomStart(edge(tester)));
    var mouse = await grab(tester);
    await send(tester, mouse.up());
    expect(paneWidths.value['preview'], 430);
    mouse = await grab(tester);
    await send(tester, mouse.up());
    expect(paneWidths.value['preview'], 460);
    expect(told, [410, 420, 430, null, 440, 450, 460, null]);
    final at = edge(tester);
    await click(tester, at);
    await tester.pump(const Duration(milliseconds: 100));
    await click(tester, at);
    expect(width(tester), 400);
    expect(paneWidths.value, isEmpty);
    await settle(tester);
  });

  testWidgets('a right button press and drag resizes nothing', (tester) async {
    await pane(tester);
    final right = mouse();
    final at = edge(tester);
    await send(tester, right.hover(at));
    await send(tester, right.down(at, buttons: kSecondaryButton));
    for (var x = 10.0; x <= 40; x += 10) {
      await send(
        tester,
        right.move(at - Offset(x, 0), buttons: kSecondaryButton),
      );
    }
    await send(tester, right.up());
    expect(width(tester), 400);
    expect(told, isEmpty);
  });

  group('a press let go unseen ends the drag there', () {
    testWidgets('a move without the primary button (another stuck)', (
      tester,
    ) async {
      await pane(tester);
      final mouse = await grab(tester);
      final at = edge(tester);
      // The engine still holding the right button sends the left's
      // release as a move with the right alone.
      await send(tester, mouse.move(at - const Offset(10, 0), buttons: 2));
      expect(told, [410, 420, 430, null]);
      expect(paneWidths.value['preview'], 430);
      // More of that pointer moves nothing now, whatever it says.
      for (var x = 20.0; x <= 60; x += 10) {
        await send(tester, mouse.move(at - Offset(x, 0)));
      }
      expect(width(tester), 430);
      expect(told, [410, 420, 430, null]);
      expect(log(), contains('check="move without its button" pane=preview'));
      await send(tester, mouse.up());
      expect(told, [410, 420, 430, null]);
      await settle(tester);
    });

    testWidgets('a hover of its pointer', (tester) async {
      await pane(tester);
      final mouse = await grab(tester);
      final at = edge(tester);
      // The engine let go of the press (its state reset) without telling
      // Flutter: the pointer hovers.
      await tester.sendEventToBinding(
        PointerHoverEvent(
          device: mouse.device,
          position: at - const Offset(50, 0),
        ),
      );
      await tester.pump();
      expect(told, [410, 420, 430, null]);
      expect(width(tester), 430);
      // The old press's moves, if more come, move nothing.
      for (var x = 40.0; x <= 80; x += 10) {
        await send(tester, mouse.move(at - Offset(x, 0)));
      }
      expect(width(tester), 430);
      expect(told, [410, 420, 430, null]);
      expect(log(), contains('check=hover pane=preview'));
      await send(tester, mouse.up());
      await settle(tester);
    });

    testWidgets('the app losing the focus', (tester) async {
      await pane(tester);
      final mouse = await grab(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(told, [410, 420, 430, null]);
      await send(tester, mouse.move(edge(tester) - const Offset(50, 0)));
      expect(width(tester), 430);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await send(tester, mouse.up());
      expect(told, [410, 420, 430, null]);
      expect(paneWidths.value['preview'], 430);
      await settle(tester);
    });
  });

  testWidgets('a cancel ends the drag, its width kept, told once', (
    tester,
  ) async {
    await pane(tester);
    final mouse = await grab(tester);
    await send(tester, mouse.cancel());
    expect(told, [410, 420, 430, null]);
    expect(width(tester), 430);
    await settle(tester);
  });

  testWidgets('locked mid-drag: dropped, told once, the press moves nothing', (
    tester,
  ) async {
    await pane(tester);
    final mouse = await grab(tester);
    locked.value = true;
    await tester.pump();
    expect(told, [410, 420, 430, null]);
    expect(paneWidths.value, isEmpty);
    locked.value = false;
    await tester.pump();
    for (var x = 50.0; x <= 90; x += 10) {
      await send(tester, mouse.move(edge(tester) - Offset(x, 0)));
    }
    expect(width(tester), 400);
    await send(tester, mouse.up());
    expect(told, [410, 420, 430, null]);
    expect(paneWidths.value, isEmpty);
    await settle(tester);
  });

  testWidgets('gone mid-drag: told once, after the frame', (tester) async {
    await pane(tester);
    final mouse = await grab(tester);
    shown.value = false;
    await tester.pump();
    expect(told, [410, 420, 430, null]);
    await send(tester, mouse.up());
    expect(told, [410, 420, 430, null]);
    expect(paneWidths.value, isEmpty);
    await settle(tester);
  });

  group('a press that moves drags at once past the slop', () {
    Future<void> dragFrom(WidgetTester tester) async {
      final press = mouse();
      final at = edge(tester);
      await send(tester, press.down(at));
      final from = width(tester);
      await send(tester, press.move(at - const Offset(2, 0)));
      await send(tester, press.move(at - const Offset(12, 0)));
      expect(width(tester), from + 10, reason: 'it moved with the press');
      await send(tester, press.up());
    }

    testWidgets('right after a click', (tester) async {
      await pane(tester);
      await click(tester, edge(tester));
      await tester.pump(const Duration(milliseconds: 60));
      await dragFrom(tester);
      expect(paneWidths.value['preview'], 410);
      await settle(tester);
    });

    testWidgets('as a slow double click', (tester) async {
      await pane(tester);
      await click(tester, edge(tester));
      await tester.pump(const Duration(milliseconds: 500));
      await dragFrom(tester);
      expect(paneWidths.value['preview'], 410);
      await settle(tester);
    });

    testWidgets('pressed again at once, inside the double click', (
      tester,
    ) async {
      await pane(tester);
      await click(tester, edge(tester));
      // Within the double click's own least time, then within its time.
      await dragFrom(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await dragFrom(tester);
      expect(paneWidths.value['preview'], 420);
      await settle(tester);
    });
  });

  testWidgets('a double click still resets it', (tester) async {
    await pane(tester);
    paneWidths.value = {'preview': 500};
    await tester.pump();
    final at = edge(tester);
    await click(tester, at);
    await tester.pump(const Duration(milliseconds: 100));
    await click(tester, at);
    expect(width(tester), 400);
    expect(paneWidths.value, isEmpty);
    await settle(tester);
  });
}
