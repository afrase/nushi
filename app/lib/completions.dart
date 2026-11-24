import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/copy_command.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_filter.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/spell_check.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What [chat]'s prompt box offers while typing in its draft's text: at
/// its start after `/` the agent's commands, anywhere after `@` the chat
/// folder's files. The files picked go in the draft's mentions.
class Completions extends ChangeNotifier {
  new(this.chat, this.daemon) : _commands = chat.commands {
    text.addListener(_update);
    chat.addListener(_chatChanged);
  }

  final ChatState chat;
  final Daemon daemon;

  /// The draft's text, and the files its @ picked.
  ComposerText get text => chat.draft.text;
  Set<String> get mentions => chat.draft.mentions;
  List<Choice> choices = [];
  int picked = 0;
  GitFiles? _git; // the folder's files, followed from the first @
  (int, int)? _token; // where the text being completed starts and ends
  String _dismissed = ''; // the text Escape closed the choices for
  List<Command> _commands; // the chat's commands, as last offered

  /// The agent's commands came: `/` typed before them offers them now.
  void _chatChanged() {
    if (identical(_commands, chat.commands)) return;
    _commands = chat.commands;
    if (text.text.startsWith('/')) _update();
  }

  void _update() {
    final caret = text.selection.baseOffset;
    final before = caret < 0 ? '' : text.text.substring(0, caret);
    var found = <Choice>[];
    _token = null;
    if (RegExp(r'^/(\S*)$').firstMatch(before) case final m?) {
      final names = {
        for (final c in chat.commands) c.name: c,
        copyCommand.name: copyCommand,
      };
      found = [
        for (final n in rankChoices(names.keys, m[1]!))
          (label: '/$n', detail: names[n]!.description, insert: '/$n '),
      ];
      _token = (0, caret);
    } else if (RegExp(r'(^|\s)@(\S*)$').firstMatch(before) case final m?) {
      final git = gitFilesOf(chat.folder);
      if (!identical(git, _git)) {
        _git?.removeListener(_update);
        _git = git..addListener(_update);
      }
      // Asked again for each mention, after a few seconds: the agent adds
      // files. The list it had shows meanwhile.
      if (!git.listed || m[2]!.isEmpty) git.ask(daemon);
      found = [
        for (final f in rankChoices(git.paths, m[2]!))
          (label: f, detail: '', insert: '@$f '),
      ];
      _token = (caret - m[2]!.length - 1, caret);
    }
    // A command's text is the shell's: nothing to complete (ADR 0148).
    if (text.text == _dismissed || text.commandMode) found = [];
    choices = found.take(8).toList();
    picked = 0;
    notifyListeners();
  }

  /// Starts an @ mention at the cursor, which offers the folder's files.
  void mention() {
    final sel = text.selection;
    final at = sel.isValid ? sel.start : text.text.length;
    final before = text.text.substring(0, at);
    final insert =
        before.isEmpty || before.endsWith(' ') || before.endsWith('\n')
        ? '@'
        : ' @';
    _dismissed = '';
    text.value = TextEditingValue(
      text: text.text.replaceRange(at, sel.isValid ? sel.end : at, insert),
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
  }

  /// Offers the chat's commands, as `/` typed at the start would: a `/`
  /// before what's written (none when there is one), the cursor after it.
  void slash() {
    final has = text.text.startsWith('/');
    _dismissed = '';
    text.value = TextEditingValue(
      text: has ? text.text : '/${text.text}',
      selection: TextSelection.collapsed(
        offset: has ? text.text.indexOf(RegExp(r'\s|$')) : 1,
      ),
    );
  }

  void accept(Choice c) {
    final (start, end) = _token!;
    final next = text.text.replaceRange(start, end, c.insert);
    if (c.insert.startsWith('@')) mentions.add(c.label);
    text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + c.insert.length),
    );
  }

  /// An Enter that picked, while it's held: its repeats are used too, or
  /// they'd go on to the box and send or start lines once the list closed.
  /// The next press clears it, so a lost key-up can't keep it.
  bool _enterHeld = false;

  /// Takes a key (down or repeat) while choices show: arrows move, Enter
  /// (the keypad's too) or Tab picks, Escape closes. True if it was taken.
  bool onKey(KeyEvent e, {required bool shift}) {
    final key = e.logicalKey;
    final enter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (e is KeyDownEvent) _enterHeld = false;
    if (_enterHeld && enter && e is KeyRepeatEvent) return true;
    if (choices.isEmpty) return false;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      picked = (picked + step) % choices.length;
      notifyListeners();
      return true;
    }
    // ⌃Tab and ⌃⇧Tab are the chat's tabs (`chat_keys.dart`), not a pick.
    if ((enter && !shift) ||
        (key == LogicalKeyboardKey.tab &&
            !HardwareKeyboard.instance.isControlPressed)) {
      _enterHeld = enter;
      accept(choices[picked]);
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      _dismissed = text.text;
      choices = [];
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    text.removeListener(_update);
    chat.removeListener(_chatChanged);
    _git?.removeListener(_update);
    super.dispose();
  }
}

/// A completion offered while typing: a slash command or a file.
typedef Choice = ({String label, String detail, String insert});

/// The first 8 names holding [q]: those whose last part (after the last
/// `/` or `:`) starts with it first, then the shortest, then in [names]'
/// order. Each name is scored once: a bare `@` ranks every file listed
/// (20,000 at most) at every key.
List<String> rankChoices(Iterable<String> names, String q) {
  final lower = q.toLowerCase();
  final hits = <(int, int, String)>[];
  var i = 0;
  for (final n in names) {
    final l = n.toLowerCase();
    if (l.contains(lower)) {
      final last = max(l.lastIndexOf('/'), l.lastIndexOf(':')) + 1;
      hits.add(((l.startsWith(lower, last) ? 0 : 1000) + n.length, i, n));
    }
    i++;
  }
  hits.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return [for (final (_, _, n) in hits.take(8)) n];
}

/// The completions over the prompt box, the picked one highlighted.
class ChoiceList extends StatelessWidget {
  const new(this.choices, this.picked, {required this.onPick, super.key});

  final List<Choice> choices;
  final int picked;
  final void Function(Choice) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(4),
      decoration: cardBox(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in choices.indexed)
            Tap(
              onTap: () => onPick(c),
              selected: i == picked,
              radius: NushiTheme.inner(NushiTheme.card, 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: c.label,
                      style: theme.code(t.text, size: 12),
                    ),
                    if (c.detail.isNotEmpty)
                      TextSpan(
                        text: '   ${c.detail}',
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
