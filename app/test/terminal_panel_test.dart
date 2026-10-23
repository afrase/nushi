import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/theme/theme.dart';

/// A daemon with two terminals that records what the app asks of it.
class _Daemon implements Transport {
  final calls = <String>[];
  final written = <String>[];
  var opened = 0;

  @override
  Future<UnaryResponse<I, O>> unary<I extends Object, O extends Object>(
    Spec<I, O> spec,
    I input, [
    CallOptions? options,
  ]) async {
    final name = spec.procedure.split('/').last;
    calls.add(name);
    Object out = spec.outputFactory();
    switch (input) {
      case ListTerminalsRequest():
        out = ListTerminalsResponse(terminals: [_term('a'), _term('b')]);
      case OpenTerminalRequest():
        out = OpenTerminalResponse(terminal: _term('new${opened++}'));
      case WriteTerminalRequest(:final data):
        written.add(utf8.decode(data));
    }
    return UnaryResponse(spec, Headers(), out as O, Headers());
  }

  @override
  Future<StreamResponse<I, O>> stream<I extends Object, O extends Object>(
    Spec<I, O> spec,
    Stream<I> input, [
    CallOptions? options,
  ]) async {
    final out = StreamController<O>()
      ..add(AttachTerminalResponse(data: utf8.encode('\$ ')) as O);
    return StreamResponse(spec, Headers(), out.stream, Headers());
  }

  static Terminal _term(String id) =>
      Terminal(id: id, chatId: 'chat', folder: '/tmp/veg', shell: 'zsh');
}

Future<void> _meta(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

void main() {
  testWidgets('tabs, and the keys the panel keeps from the shell', (
    tester,
  ) async {
    final daemon = _Daemon();
    final terms = Terminals(NushiServiceClient(daemon));
    var hidden = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: TerminalPanel(
            chatId: 'chat',
            terms: terms,
            onHide: () => hidden = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('zsh — veg'), findsNWidgets(2));
    expect(terms.active['chat'], 'b'); // the last one shows

    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB); // Option as Meta
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(daemon.written.join(), 'l\x1bb');

    await _meta(tester, LogicalKeyboardKey.digit1);
    expect(terms.active['chat'], 'a');
    await _meta(tester, LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();
    expect(daemon.calls, contains('OpenTerminal'));
    expect(terms.active['chat'], 'new0');
    await _meta(tester, LogicalKeyboardKey.keyW);
    expect(daemon.calls.last, 'CloseTerminal');
    expect(daemon.written.join(), 'l\x1bb'); // none of those reached the shell

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(hidden, isTrue);
  });
}
