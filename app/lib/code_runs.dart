import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' as pb;
import 'package:nushi/run_text.dart';
import 'package:nushi/shell_marks.dart';
import 'package:nushi/terminals.dart';

/// Where a run stands.
enum RunState {
  /// Never run, in this app's run.
  idle,

  /// Finding its terminal, or waiting there for a prompt.
  starting,

  /// Typed into its terminal: its output shows as it comes.
  running,

  /// It ended on its own (the shell's D mark), with [CodeRun.exit].
  ended,

  /// Stopped: by its ✕, or ⌃C in the terminal (exit 130).
  stopped,

  /// Followed no longer (the terminal closed, another run took it, the
  /// daemon went away) before it was seen to end.
  left,
}

/// A shell block's run in one of its chat's terminals, typed there as the
/// user would.
class CodeRun extends ChangeNotifier {
  new(this.key);

  /// The block's code, which names the run.
  final String key;

  RunState state = RunState.idle;

  /// The terminal it runs (or ran) in.
  String terminalId = '';

  /// What was typed.
  String script = '';

  /// The exit code, once [RunState.ended] or [RunState.stopped] by the
  /// shell's mark.
  int? exit;

  /// The newest non-empty line of its output, plain.
  String lastLine = '';

  /// Whether its terminal's shell marks its commands (OSC 133): without,
  /// its end isn't known, and it runs while the terminal does.
  bool marked = false;

  /// Whether the user stopped it.
  bool stopAsked = false;

  /// Just typed, in a shell without marks: the daemon lists a terminal's
  /// program only twice a second, so it runs until that can show.
  bool justTyped = false;

  bool _started = false; // its output has started (after C, or the echo)
  final _raw = StringBuffer();
  static const int _rawMost = 256 << 10;

  /// Whether ▷ shows as running (a spinner) with [term] its terminal now.
  bool busy(pb.Terminal? term) => switch (state) {
    RunState.starting => true,
    RunState.running when marked => true,
    RunState.running =>
      !stopAsked && (justTyped || (term?.program.isNotEmpty ?? false)),
    _ => false,
  };

  void _leave() {
    if (state == RunState.running || state == RunState.starting) {
      _set(RunState.left);
    }
  }

  void _output(String text) {
    _raw.write(text);
    if (_raw.length > _rawMost) {
      final s = _raw.toString();
      var cut = s.length - _rawMost ~/ 2;
      final nl = s.indexOf('\n', cut);
      if (nl >= 0) cut = nl + 1;
      _raw
        ..clear()
        ..write(s.substring(cut));
    }
    final tail = _raw.length > 8192
        ? _raw.toString().substring(_raw.length - 8192)
        : _raw.toString();
    final line = plainLines(tail)
        .lastWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    if (line.isNotEmpty && line != lastLine) {
      lastLine = line;
      notifyListeners();
    }
  }

  /// Its output as plain lines, empty ones at either end left out.
  List<String> lines() {
    final all = plainLines(_raw.toString());
    var a = 0;
    var b = all.length;
    while (a < b && all[a].trim().isEmpty) {
      a++;
    }
    while (b > a && all[b - 1].trim().isEmpty) {
      b--;
    }
    return all.sublist(a, b);
  }

  void _set(RunState s, {int? exit}) {
    state = s;
    this.exit = exit;
    notifyListeners();
  }
}

/// A terminal's output followed for runs: whether its shell runs a command
/// now (by its marks), and the run typed there last.
class _Follow {
  new(this.id);

  final String id;
  final marks = ShellMarks();
  // Cancelled by CodeRuns.dispose, or ended with the terminal.
  // ignore: cancel_subscriptions
  StreamSubscription<pb.AttachTerminalResponse>? sub;
  final replayed = Completer<void>();
  bool atPrompt = false; // after B, until C
  bool inCommand = false; // between C and D
  int chunks = 0; // output read so far, in chunks
  CodeRun? run;
  bool gone = false;
}

/// A chat's code block runs, by block, for as long as the app runs (not
/// saved); their output goes to [outputs], the composer's cards.
class CodeRuns extends ChangeNotifier {
  new(this.chatId, this.outputs);

  final String chatId;

  /// The outputs waiting to go with the next message.
  final ValueNotifier<List<RunOutput>> outputs;

  final _runs = <String, CodeRun>{};
  final _follows = <String, _Follow>{};

  /// The run of the block of [code], idle until run.
  CodeRun of(String code) => _runs[code] ??= CodeRun(code);

  void _dropOutput(String key) {
    if (outputs.value.any((o) => o.key == key)) {
      outputs.value = [...outputs.value.where((o) => o.key != key)];
    }
  }

  /// Types [script], [run]'s block, into a terminal of the chat: the one
  /// it ran in last or the panel's tab when its shell is at a prompt,
  /// else a new one in the chat's folder, not shown.
  Future<void> start(Terminals terms, CodeRun run, String script) async {
    if (run.busy(null)) return;
    _dropOutput(run.key);
    run
      ..script = script
      ..stopAsked = false
      ..exit = null
      ..lastLine = ''
      .._started = false
      .._raw.clear()
      .._set(RunState.starting);
    try {
      final f = await _terminal(terms, run);
      if (f.run != run) f.run?._leave();
      f.run = run;
      run
        ..terminalId = f.id
        ..marked = f.marks.seen
        ..justTyped = !f.marks.seen
        .._set(RunState.running);
      await terms.client.writeTerminal(
        pb.WriteTerminalRequest(
          terminalId: f.id,
          data: utf8.encode(_typed(script, _shellOf(terms, f.id))),
        ),
      );
      // A shell without marks: ▷ comes back once its program is done.
      if (run.justTyped) {
        // design: the shell's own pace, not motion
        Timer(const Duration(milliseconds: 1500), () {
          run
            ..justTyped = false
            ..notifyListeners();
        });
      }
    } on Object {
      run._set(RunState.left);
      rethrow;
    }
  }

  /// Stops [run]: ⌃C to its terminal, once it's typed there.
  Future<void> stop(Terminals terms, CodeRun run) async {
    if (run.state != RunState.running) return;
    run.stopAsked = true;
    if (!run.marked) run._set(RunState.stopped);
    run.notifyListeners();
    await terms.client.writeTerminal(
      pb.WriteTerminalRequest(terminalId: run.terminalId, data: [3]),
    );
  }

  String _shellOf(Terminals terms, String id) =>
      terms.of(chatId)?.where((t) => t.id == id).firstOrNull?.shell ?? '';

  /// [script] as typed: a line and Enter; lines, or a tab (a completion
  /// key when typed), as one paste (bracketed, so the shell runs the lines
  /// as one command line), except into bash, whose macOS version doesn't
  /// know a bracketed paste: there its lines one by one.
  static String _typed(String script, String shell) =>
      !script.contains('\n') && !script.contains('\t')
      ? '$script\r'
      : shell == 'bash'
      ? '${script.replaceAll('\n', '\r')}\r'
      : '\x1b[200~$script\x1b[201~\r';

  Future<_Follow> _terminal(Terminals terms, CodeRun run) async {
    if (terms.of(chatId) == null) await terms.load(chatId);
    final list = terms.of(chatId) ?? const <pb.Terminal>[];
    for (final id in {run.terminalId, ?terms.active[chatId]}) {
      final t = list.where((t) => t.id == id && !t.exited).firstOrNull;
      if (t == null) continue;
      final f = await _follow(terms, t.id);
      if (!f.gone && !f.inCommand && t.program.isEmpty) return f;
    }
    final t = await terms.open(chatId, show: false);
    final f = await _follow(terms, t.id);
    // Its first prompt (the B mark), else its output gone quiet a moment;
    // 5 seconds at most.
    var quiet = 0;
    var seen = f.chunks;
    for (var i = 0; i < 50 && !f.atPrompt && !f.gone; i++) {
      quiet = f.chunks == seen ? quiet + 1 : 0;
      seen = f.chunks;
      if (!f.marks.seen && f.chunks > 0 && quiet >= 4) break;
      // design: a poll of the shell, not motion
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return f;
  }

  /// The terminal [id] followed, once what it kept has been read.
  Future<_Follow> _follow(Terminals terms, String id) async {
    if (_follows[id] case final f? when !f.gone) {
      await f.replayed.future;
      return f;
    }
    final f = _follows[id] = _Follow(id);
    var first = true;
    final text = StringBuffer();
    // One decoder per stream, dropped with it.
    // ignore: close_sinks
    final decode = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(StringConversionSink.fromStringSink(text));
    void end() {
      f.gone = true;
      if (!f.replayed.isCompleted) f.replayed.complete();
      f.run?._leave();
      if (_follows[id] == f) _follows.remove(id);
    }

    f.sub = terms.client
        .attachTerminal(pb.AttachTerminalRequest(terminalId: id))
        .listen(
          (m) {
            decode.add(m.data);
            final s = text.toString();
            text.clear();
            _read(f, s, replay: first);
            if (first) {
              first = false;
              f.replayed.complete();
            }
          },
          onError: (Object _) => end(),
          onDone: end,
        );
    await f.replayed.future;
    return f;
  }

  /// Takes a terminal's output: marks say where a command runs; a run's
  /// output starts after its C mark (without marks, after the line it
  /// typed) and ends at its D.
  void _read(_Follow f, String s, {required bool replay}) {
    if (s.isNotEmpty) f.chunks++;
    for (final p in f.marks.feed(s)) {
      final run = replay ? null : f.run;
      final mark = p.mark;
      if (mark == null) {
        if (run == null) continue;
        if (run._started) {
          run._output(p.text);
        } else if (!f.marks.seen) {
          final nl = p.text.indexOf('\n');
          if (nl >= 0) {
            run
              .._started = true
              .._output(p.text.substring(nl + 1));
          }
        }
        continue;
      }
      f
        ..atPrompt = mark.kind == 'B'
        ..inCommand = mark.kind == 'C';
      if (run == null) continue;
      if (mark.kind == 'C') {
        run
          ..marked = true
          ..justTyped = false
          .._started = true;
      } else if (mark.kind == 'D' && run._started) {
        f.run = null;
        _ended(run, mark.exit ?? 0);
      }
    }
  }

  /// [run] ended at its D mark: on its own, its output goes in the box;
  /// stopped (its ✕, or ⌃C: 130), nothing does.
  void _ended(CodeRun run, int exit) {
    final stopped = run.stopAsked || exit == 130;
    run._set(stopped ? RunState.stopped : RunState.ended, exit: exit);
    _dropOutput(run.key);
    if (stopped) return;
    final lines = run.lines();
    outputs.value = [
      ...outputs.value,
      (
        key: run.key,
        command: run.script.split('\n').first,
        exit: exit,
        lines: lines.length,
        text: keptOutput(lines),
      ),
    ];
  }

  /// Stops following every terminal (the chat is gone).
  @override
  void dispose() {
    for (final f in _follows.values) {
      unawaited(f.sub?.cancel());
    }
    _follows.clear();
    super.dispose();
  }
}
