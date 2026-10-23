import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// What the prompt box offers while typing in [text]: at its start after
/// `/` the agent's commands, anywhere after `@` the chat folder's files.
/// The files picked go in [mentions].
class Completions extends ChangeNotifier {
  Completions(this.text, this.chat, this.daemon) {
    text.addListener(_update);
  }

  final TextEditingController text;
  final ChatState Function() chat;
  final Daemon daemon;
  final mentions = <String>{};
  List<Choice> choices = [];
  int picked = 0;
  List<String>? _files; // the folder's, fetched at the first @
  String _filesOf = ''; // the folder they are of
  (int, int)? _token; // where the text being completed starts and ends
  String _dismissed = ''; // the text Escape closed the choices for
  bool _disposed = false;

  void _update() {
    final caret = text.selection.baseOffset;
    final before = caret < 0 ? '' : text.text.substring(0, caret);
    var found = <Choice>[];
    _token = null;
    if (RegExp(r'^/(\S*)$').firstMatch(before) case final m?) {
      final names = {for (final c in chat().commands) c.name: c};
      found = [
        for (final n in rankChoices(names.keys, m[1]!))
          (label: '/$n', detail: names[n]!.description, insert: '/$n '),
      ];
      _token = (0, caret);
    } else if (RegExp(r'(^|\s)@(\S*)$').firstMatch(before) case final m?) {
      final folder = chat().folder;
      final files = _filesOf == folder ? _files : null;
      if (files == null) {
        _files = const [];
        _filesOf = folder;
        daemon.client.listFiles(ListFilesRequest(folder: folder)).then((r) {
          _files = r.paths;
          if (!_disposed) _update();
        }, onError: (_) => _files = null);
      }
      found = [
        for (final f in rankChoices(files ?? const [], m[2]!))
          (label: f, detail: '', insert: '@$f '),
      ];
      _token = (caret - m[2]!.length - 1, caret);
    }
    if (text.text == _dismissed) found = [];
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

  void accept(Choice c) {
    final (start, end) = _token!;
    final next = text.text.replaceRange(start, end, c.insert);
    if (c.insert.startsWith('@')) mentions.add(c.label);
    text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + c.insert.length),
    );
  }

  /// Takes a key while choices show: arrows move, Enter or Tab picks,
  /// Escape closes. True if it was taken.
  bool onKey(LogicalKeyboardKey key, {required bool shift}) {
    if (choices.isEmpty) return false;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      picked = (picked + step) % choices.length;
      notifyListeners();
      return true;
    }
    if ((key == LogicalKeyboardKey.enter && !shift) ||
        key == LogicalKeyboardKey.tab) {
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
    _disposed = true;
    text.removeListener(_update);
    super.dispose();
  }
}

/// A completion offered while typing: a slash command or a file.
typedef Choice = ({String label, String detail, String insert});

/// The names holding [q], those whose last part starts with it first,
/// then the shortest.
List<String> rankChoices(Iterable<String> names, String q) {
  q = q.toLowerCase();
  final hits = [
    for (final n in names)
      if (n.toLowerCase().contains(q)) n,
  ];
  int score(String n) =>
      (n.split(RegExp('[/:]')).last.toLowerCase().startsWith(q) ? 0 : 1000) +
      n.length;
  hits.sort((a, b) => score(a) - score(b));
  return hits.take(8).toList();
}

/// The completions over the prompt box, the picked one highlighted.
class ChoiceList extends StatelessWidget {
  const ChoiceList(
    this.choices,
    this.picked, {
    super.key,
    required this.onPick,
  });

  final List<Choice> choices;
  final int picked;
  final void Function(Choice) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(4),
      decoration: box(t.borderStrong, fill: t.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in choices.indexed)
            Tap(
              onTap: () => onPick(c),
              selected: i == picked,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: c.label,
                      style: theme.code(t.text, size: 12.5),
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
