import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:xterm2/xterm.dart';

import 'gen/nushi/v1/nushi.connect.client.dart';
import 'gen/nushi/v1/nushi.pb.dart' as pb;

/// The chats' terminals as the daemon lists them, and an emulator for each
/// one the app has shown. The daemon runs the shells; the emulators replay
/// their output when the app attaches.
class Terminals extends ChangeNotifier {
  Terminals(this.client);

  final NushiServiceClient client;
  final _lists = <String, List<pb.Terminal>>{}; // by chat, once known
  final _sessions = <String, TermSession>{}; // by terminal id
  final _opened = <String>{}; // opened here, not attached to yet

  /// The tab shown in each chat's panel, by chat.
  final active = <String, String>{};

  /// A terminal just opened or picked, which takes the keyboard focus.
  String? focusNext;

  /// A chat's terminals in order, or null until they are listed.
  List<pb.Terminal>? of(String chatId) => _lists[chatId];

  /// Lists a chat's terminals (again, after reconnecting).
  Future<void> load(String chatId) async {
    final resp = await client.listTerminals(
      pb.ListTerminalsRequest(chatId: chatId),
    );
    apply(chatId, resp.terminals);
  }

  /// Takes a chat's whole list of terminals (an event or a listing).
  void apply(String chatId, List<pb.Terminal> list) {
    _lists[chatId] = list;
    final ids = {for (final t in list) t.id};
    _sessions.removeWhere((id, s) {
      final gone = s.chatId == chatId && !ids.contains(id);
      if (gone) s.dispose();
      return gone;
    });
    if (!ids.contains(active[chatId])) {
      final id = list.lastOrNull?.id;
      id == null ? active.remove(chatId) : active[chatId] = id;
    }
    notifyListeners();
  }

  /// Forgets the lists, which may have changed while disconnected; open
  /// panels list them again.
  void stale() {
    _lists.clear();
    notifyListeners();
  }

  /// The emulator of a terminal, attached to it.
  TermSession session(pb.Terminal t) =>
      _sessions[t.id] ??= TermSession(client, t.id, t.chatId)
        ..fresh = _opened.remove(t.id);

  /// Opens a terminal for a chat (in [folder], or the chat's) and shows it.
  Future<void> open(String chatId, {String folder = ''}) async {
    final resp = await client.openTerminal(
      pb.OpenTerminalRequest(
        chatId: chatId,
        folder: folder,
        cols: 80,
        rows: 24,
      ),
    );
    final list = _lists[chatId] ?? [];
    if (!list.any((t) => t.id == resp.terminal.id)) {
      _lists[chatId] = [...list, resp.terminal];
    }
    _opened.add(resp.terminal.id);
    // Its session may be made already, from the list's event.
    _sessions[resp.terminal.id]?.fresh = true;
    active[chatId] = focusNext = resp.terminal.id;
    notifyListeners();
  }

  void show(String chatId, String id) {
    active[chatId] = focusNext = id;
    notifyListeners();
  }

  Future<void> close(String id) =>
      client.closeTerminal(pb.CloseTerminalRequest(terminalId: id));

  Future<void> rename(String id, String name) => client.renameTerminal(
    pb.RenameTerminalRequest(terminalId: id, name: name),
  );

  /// Moves a chat's terminal from [from] to [to] in its list.
  Future<void> move(String chatId, int from, int to) {
    final list = [...?_lists[chatId]];
    list.insert(to, list.removeAt(from));
    _lists[chatId] = list;
    notifyListeners();
    return client.arrangeTerminals(
      pb.ArrangeTerminalsRequest(
        chatId: chatId,
        terminalIds: [for (final t in list) t.id],
      ),
    );
  }

  Future<void> restart(String id) async {
    final s = _sessions[id];
    await client.restartTerminal(
      pb.RestartTerminalRequest(
        terminalId: id,
        cols: s?.terminal.viewWidth ?? 80,
        rows: s?.terminal.viewHeight ?? 24,
      ),
    );
    s
      ?..fresh = true
      ..attach();
  }
}

/// What a terminal tab shows: the name given to it, the program in front,
/// or the shell and its folder.
String terminalName(pb.Terminal t) => t.name.isNotEmpty
    ? t.name
    : t.program.isNotEmpty
    ? t.program
    : '${t.shell} — ${t.folder.split('/').last}';

/// An emulator showing one of the daemon's terminals: it replays what the
/// terminal kept, then follows it; keys go back to it, in order.
class TermSession extends ChangeNotifier {
  TermSession(this.client, this.id, this.chatId) {
    _create();
  }

  final NushiServiceClient client;
  final String id, chatId;
  final controller = TerminalController();
  final focus = FocusNode();
  final scroll = ScrollController();

  /// Whether its find bar shows (⌘F).
  final finding = ValueNotifier<bool>(false);

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
    terminal = Terminal(
      maxLines: 10000,
      platform: TerminalTargetPlatform.macos,
      inputHandler: const CascadeInputHandler([
        _OptionAsMeta(),
        defaultInputHandler,
      ]),
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
        unawaited(
          client
              .resizeTerminal(
                pb.ResizeTerminalRequest(
                  terminalId: id,
                  cols: cols,
                  rows: rows,
                ),
              )
              .then((_) {}, onError: (_) {}),
        );
        if (_sub == null) _attach();
      };
  }

  void _attach() {
    // The first message is the replay (maybe empty): what it decodes to,
    // not the first text decoded.
    var first = true;
    final text = StringBuffer();
    // One decoder per attach, dropped with the stream it decodes.
    // ignore: close_sinks
    final utf8 = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(StringConversionSink.fromStringSink(text));
    _sub = client
        .attachTerminal(pb.AttachTerminalRequest(terminalId: id))
        .listen(
          (m) {
            _exited = m.exited;
            utf8.add(m.data);
            final s = text.toString();
            text.clear();
            _replaying = first && !fresh;
            first = fresh = false;
            if (s.isNotEmpty) terminal.write(s);
            _replaying = false;
          },
          onError: (_) => _retry(),
          onDone: _retry,
        );
  }

  // The stream ends when the shell exits; otherwise (the daemon went away,
  // or this client fell behind) attach again while the terminal is listed.
  void _retry() {
    if (_disposed) return;
    Timer(const Duration(seconds: 1), () {
      if (!_disposed && !_exited) attach();
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
    unawaited(_sub?.cancel());
    controller.dispose();
    focus.dispose();
    scroll.dispose();
    finding.dispose();
    hoveredLink.dispose();
    super.dispose();
  }
}

/// Option as Meta: Option with a letter or digit sends Escape and the key,
/// and Option-←/→ move by word, as in Terminal.app with "Use Option as
/// Meta key".
class _OptionAsMeta implements TerminalInputHandler {
  const _OptionAsMeta();

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
