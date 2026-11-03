import 'dart:async';
import 'dart:convert';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';

/// A chat's terminals as the daemon keeps them, for code block runs: what
/// each one kept ([replay]), what its shell writes next ([write]), and
/// what the app typed into each ([typed]).
class FakeShells {
  new(this.fake, {List<Terminal>? terminals}) {
    list.addAll(terminals ?? const []);
    fake
      ..answer = _answer
      ..streams = _stream;
  }

  final FakeDaemon fake;
  final list = <Terminal>[];
  final replay = <String, String>{};
  final typed = <String, List<String>>{};
  final _live = <String, StreamController<AttachTerminalResponse>>{};

  /// Each new terminal's first output: fish's first prompt, marked.
  String newReplay = prompt;
  int _opened = 0;

  /// The shell in terminal [id] writes [s].
  void write(String id, String s) =>
      _live[id]?.add(AttachTerminalResponse(data: utf8.encode(s)));

  /// A command's run, as fish marks it: C, [output], D with [exit].
  void runs(String id, String output, {int exit = 0}) => write(
    id,
    '\r\n\x1b]133;C;cmdline_url=x\x1b\\$output\x1b]133;D;$exit\x1b\\$prompt',
  );

  /// fish's prompt, marked.
  static const prompt = '\x1b]133;A\x1b\\> \x1b]133;B\x1b\\';

  Object? _answer(Object input) => switch (input) {
    ListTerminalsRequest() => ListTerminalsResponse(terminals: list),
    OpenTerminalRequest(:final chatId) => _open(chatId),
    WriteTerminalRequest(:final terminalId, :final data) => _typed(
      terminalId,
      utf8.decode(data),
    ),
    _ => null,
  };

  OpenTerminalResponse _open(String chatId) {
    final t = Terminal(
      id: 'new${_opened++}',
      chatId: chatId,
      folder: '/Users/me/nushi',
      shell: 'fish',
    );
    list.add(t);
    replay[t.id] = newReplay;
    return OpenTerminalResponse(terminal: t);
  }

  WriteTerminalResponse _typed(String id, String s) {
    (typed[id] ??= []).add(s);
    return WriteTerminalResponse();
  }

  Stream<Object>? _stream(Object input) {
    if (input is! AttachTerminalRequest) return null;
    final id = input.terminalId;
    // Closed by close().
    // ignore: close_sinks
    final live = _live[id] ??=
        StreamController<AttachTerminalResponse>.broadcast();
    Stream<AttachTerminalResponse> attach() async* {
      yield AttachTerminalResponse(data: utf8.encode(replay[id] ?? ''));
      yield* live.stream;
    }

    return attach();
  }

  /// Ends every stream.
  Future<void> close() async {
    for (final c in _live.values) {
      await c.close();
    }
  }
}
