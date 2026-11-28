import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/daemon.dart' show clearTerminalApi;
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' as pb;
import 'package:nushi/motion.dart';
import 'package:nushi/terminal_clear.dart';
import 'package:nushi/terminal_find.dart';
import 'package:nushi/terminals.dart' show noDaemonApi, terminalPlatform;
import 'package:xterm2/xterm.dart';

/// An emulator showing one of the daemon's terminals: it replays what the
/// terminal kept, then follows it; keys go back to it, in order.
///
/// A daemon of [clearTerminalApi] or newer places each message in all the
/// terminal printed: the session counts what it took in, tells the daemon
/// where ⌘K cleared ([clear]), and clears again at the place an attach's
/// replay gives, so what was cleared stays cleared (issue #122).
class TermSession extends ChangeNotifier {
  new(this.client, this.id, this.chatId, {this.api = noDaemonApi}) {
    _create();
  }

  final NushiServiceClient client;
  final String id;
  final String chatId;

  /// The daemon's API version, as it is now.
  final int Function() api;

  /// The place after the last byte of output the emulator took in, from
  /// the shell's start; null until a message of a daemon that counts.
  int? _place;
  final controller = TerminalController();
  final focus = FocusNode();
  final scroll = ScrollController();

  /// Its find (⌘F); the bar shows while it has a query.
  late final find = TerminalFind(this);

  /// The real target of the OSC 8 link under the pointer, if any.
  final hoveredLink = ValueNotifier<String?>(null);

  late Terminal terminal;
  StreamSubscription<pb.AttachTerminalResponse>? _sub;
  bool _replaying = false; // answers to queries in the replay aren't sent

  /// Whether no one has attached to the shell yet: then its queries in the
  /// replay still wait for answers (fish waits 10 seconds for one).
  bool fresh = false;
  bool _disposed = false;
  bool _exited = false; // the stream said so: it has ended for good
  final _input = BytesBuilder();
  bool _sending = false;

  /// Whether its stream said the shell exited (and it stopped following).
  bool get exited => _exited;

  /// Attaches (again) with a fresh emulator: the replay rebuilds it.
  void attach() {
    _create();
    notifyListeners();
  }

  // The emulator attaches once its view has given it a size, so the replay
  // fills a screen of the size it will be shown at.
  void _create() {
    unawaited(_sub?.cancel());
    _sub = null;
    _exited = false;
    _place = null;
    terminal = Terminal(
      maxLines: 10000,
      platform: terminalPlatform,
      inputHandler: const CascadeInputHandler([
        _OptionAsMeta(),
        defaultInputHandler,
      ]),
      // Output never reads the clipboard (OSC 52's query): an ssh host or
      // a remote log shown here would get what you last copied. Writes
      // stay, for tmux's and nvim's yank, and only while it's focused.
      onClipboardQuery: (_) => null,
      // Not a title report (CSI 20/21 t): output could set the title and
      // have it typed at the prompt.
      onOutput: (s) =>
          _replaying || s.startsWith('\x1b]l') || s.startsWith('\x1b]L')
          ? null
          : send(s),
    );
    // Never the view's size, so its first layout resizes it and attaches.
    terminal
      ..resize(1, 1)
      ..onResize = (cols, rows, _, _) {
        _resize((cols, rows));
        if (_sub == null) _attach();
      };
  }

  /// How often, at most, the shell is told its size while it changes (a
  /// pane's edge dragged beside the terminal): the emulator reflows at
  /// once, the PTY on the first change and then the last of each spell.
  static const Duration resizeEvery = Waits.coalesce;

  Timer? _resizing; // the spell's, while it lasts
  (int, int)? _wanted; // the size it ends at, not yet sent

  void _resize((int, int) size) {
    if (_resizing != null) {
      _wanted = size;
      return;
    }
    _sendSize(size);
    _resizing = Timer(resizeEvery, _resized);
  }

  void _resized() {
    _resizing = null;
    final size = _wanted;
    _wanted = null;
    if (size != null && !_disposed) _resize(size);
  }

  void _sendSize((int, int) size) => client
      .resizeTerminal(
        pb.ResizeTerminalRequest(terminalId: id, cols: size.$1, rows: size.$2),
      )
      .ignore();

  /// Clears the emulator as ⌘K does ([clearTerminal]) and tells the
  /// daemon the place, so a later attach clears there again. Not in a
  /// full-screen program's alternate screen, which ⌘K leaves alone. A
  /// failed call shows nothing: the screen stays cleared, and only the
  /// next attach could bring the output back.
  void clear() {
    if (terminal.isUsingAltBuffer) return;
    clearTerminal(terminal);
    final at = _place;
    if (at == null || api() < clearTerminalApi) return;
    client
        .clearTerminal(pb.ClearTerminalRequest(terminalId: id, at: Int64(at)))
        .ignore();
  }

  void _attach() {
    // The first message is the replay (maybe empty): what it decodes to,
    // not the first text decoded.
    var first = true;
    // Where the replay says the terminal was cleared, until the message
    // that reaches it: the bytes before it are fed, the clear runs, then
    // the rest, as a live ⌘K there had it. Before the first byte kept, it
    // runs before any.
    int? clearAt;
    final text = StringBuffer();
    // One decoder per attach, dropped with the stream it decodes.
    // ignore: close_sinks
    final utf8 = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(StringConversionSink.fromStringSink(text));
    void feed(List<int> data) {
      utf8.add(data);
      final s = text.toString();
      text.clear();
      if (s.isNotEmpty) terminal.write(s);
    }

    late final StreamSubscription<pb.AttachTerminalResponse> sub;
    _sub = sub = client
        .attachTerminal(pb.AttachTerminalRequest(terminalId: id))
        .listen(
          (m) {
            _exited = m.exited;
            // An older daemon's offset is always 0: nothing is counted.
            final counts = api() >= clearTerminalApi;
            if (first && counts && m.hasClearedAt()) {
              clearAt = m.clearedAt.toInt();
            }
            _replaying = first && !fresh;
            first = fresh = false;
            final data = m.data;
            final offset = m.offset.toInt();
            final at = clearAt;
            if (at != null && at <= offset + data.length) {
              clearAt = null;
              final cut = (at - offset).clamp(0, data.length);
              feed(data.sublist(0, cut));
              clearTerminal(terminal);
              feed(data.sublist(cut));
            } else {
              feed(data);
            }
            _replaying = false;
            if (counts) _place = offset + data.length;
          },
          onError: (_) => _retry(sub),
          onDone: () => _retry(sub),
        );
  }

  // The stream ends when the shell exits; otherwise (the daemon went away,
  // this client fell behind, the terminal restarted) attach again while
  // the terminal is listed, unless this session attached anew meanwhile
  // (a restart here): one more would replay the screen twice.
  void _retry(StreamSubscription<pb.AttachTerminalResponse> ended) {
    if (_disposed) return;
    // The place was that stream's: the terminal may be another shell by
    // the next attach (restarted elsewhere), where it would name nothing.
    // A clear made meanwhile clears the screen and sends none.
    if (_sub == ended) _place = null;
    Timer(const Duration(seconds: 1), () {
      if (!_disposed && !_exited && _sub == ended) attach();
    });
  }

  /// Sends keys or pasted text to the shell, one write at a time.
  void send(String s) {
    _input.add(utf8.encode(s));
    if (!_sending) unawaited(_flush());
  }

  Future<void> _flush() async {
    _sending = true;
    while (_input.isNotEmpty && !_disposed) {
      final data = _input.takeBytes();
      try {
        await client.writeTerminal(
          pb.WriteTerminalRequest(terminalId: id, data: data),
        );
      } on Object {
        break; // the shell is gone; the list says so soon
      }
    }
    _sending = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _resizing?.cancel();
    unawaited(_sub?.cancel());
    controller.dispose();
    focus.dispose();
    scroll.dispose();
    find.dispose();
    hoveredLink.dispose();
    super.dispose();
  }
}

/// Option as Meta: Option with a letter or digit sends Escape and the key,
/// and Option-←/→ move by word, as in Terminal.app with "Use Option as
/// Meta key".
class _OptionAsMeta implements TerminalInputHandler {
  const new();

  @override
  String? call(TerminalKeyboardEvent e) {
    if (e.type == TerminalKeyEventType.release ||
        !e.alt ||
        e.ctrl ||
        e.superKey) {
      return null;
    }
    final k = e.key.index;
    if (k >= TerminalKey.keyA.index && k <= TerminalKey.keyZ.index) {
      final c = String.fromCharCode(0x61 + k - TerminalKey.keyA.index);
      return '\x1b${e.shift ? c.toUpperCase() : c}';
    }
    if (k >= TerminalKey.digit1.index && k <= TerminalKey.digit9.index) {
      return '\x1b${k - TerminalKey.digit1.index + 1}';
    }
    return switch (e.key) {
      TerminalKey.digit0 => '\x1b0',
      TerminalKey.arrowLeft => '\x1bb',
      TerminalKey.arrowRight => '\x1bf',
      TerminalKey.backspace => '\x1b\x7f',
      _ => null,
    };
  }
}
