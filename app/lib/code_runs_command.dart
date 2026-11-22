part of 'code_runs.dart';

/// A command typed after `!` in the box: it runs in a terminal of its own
/// that ends with it (the daemon's command terminal), so its end and exit
/// are known in every shell, without the marks ▷ needs. Its card is in
/// [CodeRuns.outputs] from the start: running, then done with its exit and
/// output, sent with the next message; stopped, it's gone and sends
/// nothing (ADR 0084's rule).
extension CommandRuns on CodeRuns {
  /// Runs [command] in a new terminal of the chat's, in its folder, not
  /// shown, its card over the box at once; the run, once its terminal is
  /// open. Throws, the card gone, when the terminal can't be opened (a
  /// daemon older than `commandTerminalApi` has no such terminal: the
  /// caller checks first).
  Future<CodeRun> command(Terminals terms, String command) async {
    final run = CodeRun('!${_nextCommand++}')
      ..script = command
      .._started = true
      .._set(RunState.starting);
    outputs.value = [...outputs.value, _card(run)];
    try {
      final t = await terms.open(chatId, command: command, show: false);
      run.terminalId = t.id;
    } on Object {
      _dropOutput(run.key);
      run._set(RunState.left);
      rethrow;
    }
    _followCommand(terms, run);
    if (run.stopAsked) {
      await _interrupt(terms, run);
    } else {
      run._set(RunState.running);
    }
    return run;
  }

  /// Stops [run], a command: its card goes at once, and ⌃C goes to its
  /// terminal (once it's open); what it printed is never sent.
  Future<void> stopCommand(Terminals terms, CodeRun run) async {
    if (run.state != RunState.starting && run.state != RunState.running) {
      return;
    }
    run.stopAsked = true;
    _dropOutput(run.key);
    run._changed();
    if (run.terminalId.isNotEmpty) await _interrupt(terms, run);
  }

  Future<void> _interrupt(Terminals terms, CodeRun run) =>
      terms.client.writeTerminal(
        pb.WriteTerminalRequest(terminalId: run.terminalId, data: [3]),
      );

  /// [run]'s card: running until it ends, when [_commandEnded] fills it.
  RunOutput _card(CodeRun run, {int exit = 0, List<String> lines = const []}) =>
      (
        key: run.key,
        command: run.script,
        exit: exit,
        lines: lines.length,
        text: keptOutput(lines),
        run: run,
      );

  /// Follows [run]'s terminal from its start (what the daemon kept of it
  /// comes first) to the last message, its exit's.
  void _followCommand(Terminals terms, CodeRun run) {
    final text = StringBuffer();
    // One decoder per stream, dropped with it.
    // ignore: close_sinks
    final decode = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(StringConversionSink.fromStringSink(text));
    _commands[run] = terms.client
        .attachTerminal(pb.AttachTerminalRequest(terminalId: run.terminalId))
        .listen(
          (m) {
            if (m.data.isNotEmpty) {
              decode.add(m.data);
              run._output(text.toString());
              text.clear();
            }
            if (m.exited) _commandEnded(terms, run, m.exitCode);
          },
          onError: (Object _) => _commandLeft(run),
          onDone: () => _commandLeft(run),
        );
  }

  /// [run] ended with [exit]: on its own, its card is filled with its
  /// output; stopped (its ✕, or ⌃C in its terminal: 130), it sends
  /// nothing. Its terminal closes unless the user opened it.
  void _commandEnded(Terminals terms, CodeRun run, int exit) {
    unawaited(_commands.remove(run)?.cancel());
    final stopped = run.stopAsked || exit == 130;
    run._set(stopped ? RunState.stopped : RunState.ended, exit: exit);
    if (stopped) {
      _dropOutput(run.key);
    } else {
      final done = _card(run, exit: exit, lines: run.lines());
      outputs.value = [
        for (final o in outputs.value)
          if (o.key == run.key) done else o,
      ];
    }
    if (!run.shown) {
      // Gone already is as good as closed.
      unawaited(terms.close(run.terminalId).then((_) {}, onError: (_) {}));
    }
  }

  /// [run]'s terminal went before it was seen to end (closed, the daemon
  /// gone): nothing to send.
  void _commandLeft(CodeRun run) {
    _commands.remove(run);
    if (run.state == RunState.running || run.state == RunState.starting) {
      _dropOutput(run.key);
      run._set(RunState.left);
    }
  }
}
