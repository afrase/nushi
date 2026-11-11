import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/phase_pill.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/status.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _model = 'claude-opus-5-5';

/// What the headers asked of `nushi/window`: a press on a drag area arms
/// the window ('arm'), and the Mac moves it if the press moves.
List<String> _windowCalls() {
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(const MethodChannel('nushi/window'), (
          c,
        ) async {
          calls.add(c.method);
          return null;
        });
  addTearDown(
    () => messenger.setMockMethodCallHandler(
      const MethodChannel('nushi/window'),
      null,
    ),
  );
  return calls;
}

/// What the headers asked besides arming.
List<String> _besides(List<String> calls) =>
    calls.where((c) => c != 'arm').toList();

/// Two clicks at [at], as close together as a double click.
Future<void> _double(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(at);
  await tester.pumpAndSettle();
}

/// A drag from [at], held long enough to be one.
Future<void> _drag(WidgetTester tester, Offset at) async {
  await tester.timedDragFrom(
    at,
    const Offset(60, 30),
    const Duration(milliseconds: 200),
  );
  await tester.pumpAndSettle();
}

/// The chat header, 1400 wide, of a Claude chat naming its model; [onPanel]
/// counts the details button's clicks.
Future<(Daemon, ChatState)> _header(
  WidgetTester tester, {
  VoidCallback? onPanel,
}) async {
  final d = await FakeDaemon([]).connect(tester);
  final chat = ChatState('c', '/Users/me/repo')
    ..agent = 'claude'
    ..title = 'Fix the login'
    ..config = [
      ConfigOption(
        id: 'model',
        category: 'model',
        current: _model,
        values: [ConfigValue(value: _model, name: _model)],
      ),
    ];
  await tester.pumpWidget(
    themed(
      SizedBox(
        width: 1400,
        child: ChatHeader(
          chat,
          d,
          tab: ChatTab.chat,
          onTab: (_) {},
          panel: true,
          onPanel: onPanel ?? () {},
        ),
      ),
    ),
  );
  return (d, chat);
}

void main() {
  setUpAll(loadFonts);

  group('the chat header', () {
    testWidgets('a double click in its empty space zooms the window, high '
        'or low in the bar', (tester) async {
      final calls = _windowCalls();
      final (d, _) = await _header(tester);
      final word = tester.getRect(find.byType(PhasePill));
      final tabs = tester.getRect(find.byType(Segmented<ChatTab>));
      final x = (word.right + tabs.left) / 2;
      expect(tabs.left - word.right, greaterThan(100));

      await _double(tester, Offset(x, word.center.dy));
      expect(calls, ['arm', 'arm', 'zoom']);
      // A click on the status word between: the test's clicks come faster
      // than a double click's time, and a third would count as a second
      // here (macOS counts it a third, and the window does nothing).
      await tester.tapAt(word.center);
      await tester.pumpAndSettle();
      await _double(tester, Offset(x, 3));
      expect(_besides(calls), ['zoom', 'zoom']);
      d.dispose();
    });

    // A press that moves two points is a pan in Flutter, which beat the tap:
    // a click on a trackpad often moves that much.
    testWidgets('a double click in its empty space zooms even when a press '
        'moves a point or two', (tester) async {
      final calls = _windowCalls();
      final (d, _) = await _header(tester);
      final word = tester.getRect(find.byType(PhasePill));
      final tabs = tester.getRect(find.byType(Segmented<ChatTab>));
      final at = Offset((word.right + tabs.left) / 2, word.center.dy);

      Future<void> click({required bool moves}) async {
        final g = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
        if (moves) await g.moveBy(const Offset(3, 1));
        await g.up();
        await tester.pump(const Duration(milliseconds: 50));
      }

      for (final (first, second) in [(false, true), (true, false)]) {
        calls.clear();
        await click(moves: first);
        await click(moves: second);
        await tester.pumpAndSettle();
        expect(calls.where((c) => c == 'zoom'), hasLength(1));
        // A click on the status word, so the next pair starts afresh (the
        // clicks come faster than a double click's time).
        await tester.tapAt(word.center);
        await tester.pumpAndSettle();
      }
      d.dispose();
    });

    testWidgets('a double click on what isn’t a control, or just beside it, '
        'zooms nothing; a drag from it moves the window', (tester) async {
      final calls = _windowCalls();
      final (d, _) = await _header(tester);
      final mark = tester.getRect(find.byType(AgentMark));
      final model = tester.getRect(find.text(_model));
      final spots = {
        'the agent’s mark': mark.center,
        'the agent’s name': tester.getCenter(find.text('Claude')),
        'the model': model.center,
        'the status dot': tester.getCenter(find.byType(ChatDot)),
        'the status pill': tester.getCenter(find.byType(PhasePill)),
        'above the model': Offset(model.center.dx, 3),
        'between the mark and the name': mark.centerRight + const Offset(4, 0),
      };
      for (final MapEntry(key: name, value: at) in spots.entries) {
        await _double(tester, at);
        expect(_besides(calls), isEmpty, reason: name);
      }
      for (final MapEntry(key: name, value: at) in spots.entries) {
        calls.clear();
        await _drag(tester, at);
        expect(calls, ['arm'], reason: name);
      }
      d.dispose();
    });

    // The Mac moves the window from its own events, as the press's dragged
    // event comes, while its button is held: a drag started from a call,
    // which comes late, could reach the window server after the release,
    // and the window followed the pointer. The header only arms the press
    // as it goes down, once, with when it went down in the engine's
    // microseconds, so the Mac moves the window only with that press
    // (HeaderDrag in TitleBar.swift).
    testWidgets('a press arms the window as it goes down, with when, once', (
      tester,
    ) async {
      final sent = <(String, Object?)>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(const MethodChannel('nushi/window'), (
              c,
            ) async {
              sent.add((c.method, c.arguments));
              return null;
            });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('nushi/window'),
          null,
        ),
      );
      final (d, _) = await _header(tester);
      final at = tester.getCenter(find.text('Fix the login'));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      const down = Duration(seconds: 500, microseconds: 123);
      await tester.sendEventToBinding(pointer.down(at, timeStamp: down));
      await tester.pump();
      expect(sent, [('arm', down.inMicroseconds)]);
      for (var i = 1; i <= 5; i++) {
        await tester.sendEventToBinding(
          pointer.move(
            at + Offset(i * 10.0, 0),
            timeStamp: down + Duration(milliseconds: i * 16),
          ),
        );
      }
      await tester.sendEventToBinding(
        pointer.up(timeStamp: down + const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(sent, [('arm', down.inMicroseconds)]);
      d.dispose();
    });

    testWidgets('a button keeps its clicks: no zoom, no drag', (tester) async {
      final calls = _windowCalls();
      var clicks = 0;
      final (d, _) = await _header(tester, onPanel: () => clicks++);
      final details = tester.getCenter(find.byTooltip('Hide details'));

      await _double(tester, details);
      expect(clicks, 2);
      await _drag(tester, details);
      expect(calls, isEmpty);
      d.dispose();
    });

    testWidgets('a double click on the title renames the chat; a drag from it '
        'moves the window', (tester) async {
      final calls = _windowCalls();
      final (d, chat) = await _header(tester);
      final title = tester.getCenter(find.text('Fix the login'));

      await _drag(tester, title);
      expect(calls, ['arm']);
      expect(chat.renaming.value, isFalse);
      await _double(tester, title);
      expect(chat.renaming.value, isTrue);
      expect(find.byType(RenameField), findsOne);
      expect(calls, ['arm', 'arm', 'arm']);
      d.dispose();
    });
  });

  testWidgets('a pane’s header: its title, its file’s icon, an icon with a '
      'tooltip and a disabled button zoom nothing and drag the window; its '
      'empty space zooms', (tester) async {
    final calls = _windowCalls();
    var closed = 0;
    await tester.pumpWidget(
      themed(
        SizedBox(
          width: 600,
          child: PaneHeader(
            child: Row(
              children: [
                const Icon(Icons.description, size: 14),
                const SizedBox(width: 6),
                const Text('notes.md'),
                const SizedBox(width: 8),
                const Tooltip(
                  message: 'Live',
                  child: Icon(Icons.circle, key: Key('live'), size: 8),
                ),
                const Spacer(),
                const IconTap(
                  Icons.refresh,
                  key: Key('refresh'),
                  tooltip: 'Refresh',
                  onTap: null,
                ),
                IconTap(Icons.close, tooltip: 'Close', onTap: () => closed++),
              ],
            ),
          ),
        ),
      ),
    );
    final spots = {
      'the file’s icon': tester.getCenter(find.byIcon(Icons.description)),
      'the title': tester.getCenter(find.text('notes.md')),
      'the tooltip’s icon': tester.getCenter(find.byKey(const Key('live'))),
      'the disabled button': tester.getCenter(find.byKey(const Key('refresh'))),
    };
    for (final MapEntry(key: name, value: at) in spots.entries) {
      await _double(tester, at);
      expect(_besides(calls), isEmpty, reason: name);
    }
    for (final MapEntry(key: name, value: at) in spots.entries) {
      calls.clear();
      await _drag(tester, at);
      expect(calls, ['arm'], reason: name);
    }

    calls.clear();
    await _double(tester, tester.getCenter(find.byTooltip('Close')));
    expect(closed, 2);
    expect(calls, isEmpty);
    final header = tester.getRect(find.byType(PaneHeader));
    await _double(tester, header.center);
    expect(calls, ['arm', 'arm', 'zoom']);
  });

  testWidgets('a name given the room up to the buttons (the Files pane’s '
      'folder) zooms nothing on its words, but the room past them zooms; a '
      'name cut short zooms nothing to its end', (tester) async {
    final calls = _windowCalls();
    Future<void> pane(String name) => tester.pumpWidget(
      themed(
        SizedBox(
          width: 600,
          child: PaneHeader(
            child: Row(
              spacing: 6,
              children: [
                const Icon(Icons.folder_outlined, size: 14),
                const Text('Files'),
                Expanded(
                  child: Text(
                    name,
                    key: const Key('name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconTap(Icons.close, tooltip: 'Close', onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );

    await pane('repo');
    final box = tester.getRect(find.byKey(const Key('name')));
    expect(box.width, greaterThan(400)); // the Expanded's whole room
    await _double(tester, box.centerLeft + const Offset(12, 0)); // its words
    expect(_besides(calls), isEmpty);
    await _double(tester, Offset(box.center.dx + 100, box.center.dy));
    expect(_besides(calls), ['zoom']);

    calls.clear();
    await pane('a-folder-name-far-too-long-for-the-room-it-is-given-' * 4);
    await _double(tester, box.centerRight - const Offset(10, 0));
    expect(_besides(calls), isEmpty);
  });

  testWidgets('the preview pane’s tabs zoom nothing; the room past the last '
      'one zooms', (tester) async {
    final calls = _windowCalls();
    final chat = ChatState('c', '/Users/me/repo');
    await tester.pumpWidget(
      themed(
        SizedBox(
          width: 600,
          child: PaneHeader(
            child: Row(
              children: [
                Expanded(
                  child: PreviewTabs(
                    chat: chat,
                    tabs: const [
                      PreviewFile('docs/a.md'),
                      PreviewFile('docs/b.md'),
                    ],
                    current: const PreviewFile('docs/a.md'),
                  ),
                ),
                IconTap(Icons.close, tooltip: 'Close', onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    final last = tester.getRect(find.byKey(const ValueKey('docs/b.md')));
    final close = tester.getRect(find.byTooltip('Close'));
    expect(close.left - last.right, greaterThan(200));

    await _double(
      tester,
      Offset((last.right + close.left) / 2, last.center.dy),
    );
    expect(calls, ['arm', 'arm', 'zoom']);
  });
}
