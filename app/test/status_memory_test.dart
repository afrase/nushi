import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_app_install.dart';
import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the memory: each chat, then the app and the daemon apart '
        '($name)', (tester) async {
      final d = await _openMenu(tester, tokens);
      expect(find.text('Wire the ledger', findRichText: true), findsOne);
      expect(find.text('Nushi app', findRichText: true), findsOne);
      expect(find.text('410 MB'), findsOne);
      expect(find.text('Nushi daemon', findRichText: true), findsOne);
      expect(find.text('24 MB'), findsOne);
      expect(find.text('2 asleep'), findsOne);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/status_memory_$name.png'),
      );
      await closeView(tester, d);
    });
  }

  testWidgets("the menu's buttons match: one size, in one column clear of "
      "the numbers, every row one height, and Restarting… in Restart's "
      'place', (tester) async {
    final d = await _openMenu(tester, Tokens.dark);
    final buttons = [
      for (final b in find.byType(Button).evaluate())
        if ((b.widget as Button).label case 'Sleep' || 'Restart')
          tester.getRect(find.byWidget(b.widget)),
    ];
    expect(buttons, hasLength(3));
    for (final b in buttons) {
      expect(b.size, buttons.first.size);
      expect(b.left, buttons.first.left);
    }
    // Each row's number, right-aligned in its own column, 8 or more
    // left of the buttons' column.
    const numbers = ['230 MB', '96 MB', '410 MB', '24 MB', '1.2 GB'];
    final rights = {
      for (final n in numbers) tester.getRect(find.text(n)).right,
    };
    expect(rights, hasLength(1));
    expect(buttons.first.left - rights.single, greaterThanOrEqualTo(8));
    // Every row one height, with a button or without.
    final heights = {
      for (final n in numbers)
        tester
            .getSize(
              find.ancestor(of: find.text(n), matching: find.byType(Row)).first,
            )
            .height,
    };
    // A menu row's height (docs/design.md's Fixed heights).
    expect(heights.single, 30);

    // Restarting: the same button, where it was, as wide.
    final restart = buttons.last;
    final run = _restarting(tester, d);
    await tester.pump();
    final restarting = find.byWidgetPredicate(
      (w) => w is Button && w.label == 'Restarting…',
    );
    expect(restarting, findsOne);
    expect(tester.getRect(restarting), restart);
    // The fake daemon never stops: the restart gives up.
    await run.end();
    await closeView(tester, d);
  });

  testWidgets("with no button in any row (a daemon the app can't restart, "
      "no chat awake) the numbers end at the menu's edge", (tester) async {
    fakeInstall.daemon = null;
    const mb = 1 << 20;
    final fake =
        FakeDaemon([
            chat('x', 'claude', 'Old notes', status: ChatStatus(asleep: true)),
          ])
          ..answer = (input) => switch (input) {
            GetMemoryRequest() => GetMemoryResponse(
              daemon: Int64(24 * mb),
              app: Int64(410 * mb),
              other: Int64(1230 * mb),
            ),
            _ => null,
          };
    final d = await _openMenu(tester, Tokens.dark, fake: fake);
    expect(find.text('Nushi daemon', findRichText: true), findsOne);
    expect(find.byType(Button), findsNothing);
    for (final n in ['410 MB', '24 MB', '1.2 GB']) {
      final row = tester.getRect(
        find.ancestor(of: find.text(n), matching: find.byType(Row)).first,
      );
      expect(tester.getRect(find.text(n)).right, row.right);
      expect(row.height, 30);
    }
    await closeView(tester, d);
  });

  for (final size in const [Size(1700, 900), Size(720, 760)]) {
    renderTest('the memory menu, in the window, at ${size.width.round()} '
        'wide', (tester) async {
      for (final b in Brightness.values) {
        final d = await openApp(tester, _fake(), size: size, brightness: b);
        await _open(tester);
        final name = 'memory_menu_${size.width.round()}_${b.name}';
        await render(tester, find.byType(NushiApp), name);
        final run = _restarting(tester, d);
        await tester.pump();
        await render(tester, find.byType(NushiApp), '${name}_restarting');
        await run.end();
        await closeView(tester, d);
      }
    }, variant: onMac);
  }

  renderTest('the memory menu alone, at 2x, for a phone', (tester) async {
    for (final b in Brightness.values) {
      viewport(tester, const Size(720, 760), ratio: 2, brightness: b);
      final d = await _fake().connect(tester);
      d.select('c');
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      await _open(tester);
      final name = 'memory_menu_2x_${b.name}';
      await render(tester, find.byType(NushiApp), name);
      // The menu's box, for a crop: the panel the daemon's row is in.
      final panel = tester.getRect(
        find
            .ancestor(
              of: find.text('Nushi daemon', findRichText: true),
              matching: find.byType(Material),
            )
            .first,
      );
      File('${rendersDir!}/$name.rect').writeAsStringSync(
        [panel.left, panel.top, panel.width, panel.height].join(' '),
      );
      await closeView(tester, d);
    }
  }, variant: onMac);

  testWidgets('read every 5 s while the window shows, never while hidden, '
      'at once as it shows again; a reading that shows the same draws '
      'nothing', (tester) async {
    const mb = 1 << 20;
    var daemonBytes = 24 * mb;
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        GetMemoryRequest() => GetMemoryResponse(daemon: Int64(daemonBytes)),
        _ => null,
      };
    final d = await fake.connect(tester);
    await tester.pumpWidget(themed(StatusBar(d)));
    await tester.pump();
    int reads() => fake.calls.whereType<GetMemoryRequest>().length;
    expect(reads(), 1);
    expect(find.text('24 MB'), findsOne);

    // A few bytes more: the same "24 MB", no frame.
    var frames = 0;
    var counting = true;
    tester.binding.addPersistentFrameCallback((_) {
      if (counting) frames++;
    });
    daemonBytes += 1000;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    counting = false;
    expect(reads(), 2);
    expect(frames, 0);

    daemonBytes = 30 * mb;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(reads(), 3);
    expect(find.text('30 MB'), findsOne);

    // The app's state, one step at a time as the engine changes it.
    void become(List<AppLifecycleState> states) =>
        states.forEach(tester.binding.handleAppLifecycleStateChanged);

    // Hidden (main.dart says so to macView as the app's state changes).
    become([.inactive, .hidden]);
    d.macView.window = false;
    await tester.pump(const Duration(seconds: 15));
    expect(reads(), 3);
    // Shown again, it reads at once, then every 5 s.
    daemonBytes = 40 * mb;
    d.macView.window = true;
    become([.inactive, .resumed]);
    await tester.pump();
    expect(reads(), 4);
    expect(find.text('40 MB'), findsOne);
    await tester.pump(const Duration(seconds: 5));
    expect(reads(), 5);

    await closeView(tester, d);
  });

  testWidgets("a daemon that can't read memory is asked once, the window "
      'shown again or not, and the card shows none', (tester) async {
    final fake = FakeDaemon([])..memory = null;
    int reads() => fake.calls.whereType<GetMemoryRequest>().length;
    final d = await fake.connect(tester);
    await tester.pumpWidget(themed(StatusBar(d)));
    await tester.pump();
    expect(reads(), 1);
    expect(find.textContaining('MB'), findsNothing);
    await tester.pump(const Duration(seconds: 15));
    const <AppLifecycleState>[
      .inactive,
      .hidden,
      .inactive,
      .resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();
    expect(reads(), 1);
    await closeView(tester, d);
  });
}

/// Two awake chats (each with Sleep; `c` is the one the app opens on),
/// two asleep, and memory for them, the app, the daemon and terminals.
FakeDaemon _fake() {
  fakeInstall.daemon = '/opt/nushi/lib/nushid';
  const mb = 1 << 20;
  final awake = ChatStatus(canSleep: true);
  return FakeDaemon([
      chat('c', 'claude', 'Wire the ledger', status: awake),
      chat('b', 'codex', 'Tidy the parser', status: awake),
      chat('x', 'claude', 'Old notes', status: ChatStatus(asleep: true)),
      chat('y', 'pi', 'Spare idea', status: ChatStatus(asleep: true)),
    ])
    ..answer = (input) => switch (input) {
      GetMemoryRequest() => GetMemoryResponse(
        daemon: Int64(24 * mb),
        app: Int64(410 * mb),
        other: Int64(1230 * mb),
        chats: {'c': Int64(230 * mb), 'b': Int64(96 * mb)}.entries,
      ),
      _ => null,
    };
}

/// Opens the memory menu.
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.memory));
  await tester.pumpAndSettle();
}

/// The status bar's memory menu opened on [fake]'s chats ([_fake]'s
/// when none).
Future<Daemon> _openMenu(
  WidgetTester tester,
  Tokens tokens, {
  FakeDaemon? fake,
}) async {
  viewport(tester, const Size(720, 360));
  final d = await (fake ?? _fake()).connect(tester);
  await tester.pumpWidget(
    themed(
      Align(alignment: Alignment.bottomCenter, child: StatusBar(d)),
      tokens: tokens,
      banner: false,
    ),
  );
  await tester.pumpAndSettle();
  await _open(tester);
  return d;
}

/// Starts a restart the fake daemon never answers; its `end` lets it give
/// up.
({Future<void> Function() end}) _restarting(WidgetTester tester, Daemon d) {
  Object? failed;
  unawaited(d.restartDaemon().then((_) {}, onError: (Object e) => failed = e));
  return (
    end: () async {
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(failed, isA<StateError>());
    },
  );
}
