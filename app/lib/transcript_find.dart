import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// ⌘F in a chat's transcript: what's looked for (null: the bar is closed),
/// the entries that have it (by their keys, as the transcript last built
/// them: the loaded items only) and which one is current.
class TranscriptFind extends ChangeNotifier {
  String? _query;
  List<String> _hits = const [];
  int _at = 0;

  /// The field takes the focus when the bar opens, or ⌘F again.
  final focus = FocusNode(debugLabel: 'find');

  String? get query => _query;
  List<String> get hits => _hits;
  int get at => _at;

  /// The current hit's key, if any.
  String? get current =>
      _hits.isEmpty ? null : _hits[_at.clamp(0, _hits.length - 1)];

  /// Opens the bar (or takes the focus back to it).
  void open() {
    _query ??= '';
    notifyListeners();
    focus.requestFocus();
  }

  void close() {
    _query = null;
    _hits = const [];
    _at = 0;
    notifyListeners();
  }

  set query(String? q) {
    if (q == _query) return;
    _query = q;
    _at = 0;
    notifyListeners();
  }

  /// The transcript found [hits]: the current one stays if it's still a hit.
  void found(List<String> hits) {
    if (_listEq(hits, _hits)) return;
    final was = current;
    _hits = hits;
    final i = was == null ? -1 : hits.indexOf(was);
    _at = i >= 0 ? i : 0;
    notifyListeners();
  }

  /// The next hit ([by] 1) or the one before (-1), round.
  void step(int by) {
    if (_hits.isEmpty) return;
    _at = (_at + by) % _hits.length;
    notifyListeners();
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  static bool _listEq(List<String> a, List<String> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);
}

/// Each item's text and title lowered, once: the find runs over the whole
/// transcript on every build while it's open, a build per streamed chunk
/// (a chunk makes a new item, so what's kept is never stale).
final _lowered = Expando<(String, String)>();

/// Whether an entry of the transcript (an item, a run of tool calls or a
/// subagent with its steps) has [query] in what it shows: its text, its
/// title (a command, a path); case aside.
bool entryHas(Object entry, String query) {
  final q = query.toLowerCase();
  bool item(Item it) {
    final (text, title) = _lowered[it] ??= (
      it.text.toLowerCase(),
      it.title.toLowerCase(),
    );
    return text.contains(q) || title.contains(q);
  }

  return switch (entry) {
    final List<Item> run => run.any(item),
    final SubagentRun s => item(s.call) || s.items.any(item),
    final Item it => item(it),
    _ => false,
  };
}

/// The find bar over the transcript: the field, "2 of 7", ↑ and ↓ (or ⏎
/// and ⇧⏎), and × (or Esc) to close.
class FindBar extends StatefulWidget {
  const new(this.find, {super.key});

  final TranscriptFind find;

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  late final _text = TextEditingController(text: widget.find.query);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final f = widget.find;
    return ListenableBuilder(
      listenable: f,
      builder: (context, _) {
        final n = f.hits.length;
        final count = (f.query ?? '').isEmpty
            ? ''
            : n == 0
            ? 'None'
            : '${f.at + 1} of $n';
        return Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          decoration: box(t.borderStrong, fill: t.raised, radius: 8),
          child: Row(
            children: [
              Icon(Icons.search, size: 14, color: t.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): f.close,
                    const SingleActivator(LogicalKeyboardKey.enter): () =>
                        f.step(1),
                    const SingleActivator(
                      LogicalKeyboardKey.enter,
                      shift: true,
                    ): () =>
                        f.step(-1),
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                        f.step(1),
                    const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                        f.step(-1),
                  },
                  child: TextField(
                    controller: _text,
                    focusNode: f.focus,
                    autofocus: true,
                    style: theme.ui(t.text),
                    onChanged: (q) => f.query = q,
                    decoration: const InputDecoration(
                      hintText: 'Find in the chat',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              Text(count, style: theme.ui(t.textMuted, size: 12)),
              IconTap(
                Icons.keyboard_arrow_up,
                tooltip: 'Previous (⇧⏎)',
                onTap: n == 0 ? null : () => f.step(-1),
              ),
              IconTap(
                Icons.keyboard_arrow_down,
                tooltip: 'Next (⏎)',
                onTap: n == 0 ? null : () => f.step(1),
              ),
              IconTap(Icons.close, tooltip: 'Close (esc)', onTap: f.close),
            ],
          ),
        );
      },
    );
  }
}

/// A transcript entry as a find marks it ([mark] 1: a hit, tinted amber
/// with a bar on its left; 2: the current one, in the accent); as it is
/// with 0.
class Hit extends StatelessWidget {
  const new({required this.mark, required this.child, super.key});

  final int mark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (mark == 0) return child;
    final t = NushiTheme.of(context).t;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        color: mark == 2
            ? t.accentSoft.withValues(alpha: 0.35)
            : t.needsSoft.withValues(alpha: 0.25),
        border: Border(
          left: BorderSide(color: mark == 2 ? t.accent : t.needs, width: 3),
        ),
      ),
      child: child,
    );
  }
}

/// Whether a changed file has [query] in its path or its text, either
/// side; case aside.
bool fileHas(FileChange f, String query) {
  final q = query.toLowerCase();
  return f.path.toLowerCase().contains(q) ||
      f.newText.toLowerCase().contains(q) ||
      f.oldText.toLowerCase().contains(q);
}

/// ⌘F in the Changes view, over its files: a field that keeps the files
/// with the text in their path or either side, and how many; Esc or ×
/// closes it, every file back.
class FilesFilterField extends StatefulWidget {
  const new(this.filter, {required this.shown, required this.total, super.key});

  final ValueNotifier<String?> filter;
  final int shown;
  final int total;

  @override
  State<FilesFilterField> createState() => _FilesFilterFieldState();
}

class _FilesFilterFieldState extends State<FilesFilterField> {
  late final _text = TextEditingController(text: widget.filter.value);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final q = widget.filter.value ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 2),
      child: Row(
        children: [
          Icon(Icons.search, size: 13, color: t.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    widget.filter.value = null,
              },
              child: TextField(
                controller: _text,
                autofocus: true,
                style: theme.ui(t.text, size: 12.5),
                onChanged: (v) => widget.filter.value = v,
                decoration: const InputDecoration(
                  hintText: 'Files with…',
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          if (q.isNotEmpty)
            Text(
              '${widget.shown} of ${widget.total}',
              style: theme.ui(t.textMuted, size: 11.5),
            ),
          IconTap(
            Icons.close,
            size: 13,
            tooltip: 'Close (esc)',
            onTap: () => widget.filter.value = null,
          ),
        ],
      ),
    );
  }
}
