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

  /// Whether ⏎ goes anywhere.
  bool get canStep => _hits.isNotEmpty;

  /// How far it's come, for the bar.
  String get count => (_query ?? '').isEmpty
      ? ''
      : _hits.isEmpty
      ? 'None'
      : '${_at + 1} of ${_hits.length}';

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

/// ⌘F in a chat's Changes view. The files with the text are listed and the
/// hits counted are those of the file shown (a diff isn't read for a file
/// that isn't); going past either end of them goes on to the next file with
/// [roll], which the view sets.
class ChangesFind extends TranscriptFind {
  /// Goes to the next file listed (given 1) or the one before (-1), round.
  ValueChanged<int>? roll;

  /// Which file of how many the view lists, for the bar.
  (int, int) files = (0, 0);
  int _arriving = 0; // the way a roll came, till the file's hits are in

  @override
  bool get canStep => files.$2 > 1 || super.canStep;

  @override
  String get count {
    final (at, of) = files;
    return of > 1 && (query ?? '').isNotEmpty
        ? '${super.count} · file $at of $of'
        : super.count;
  }

  @override
  void step(int by) {
    final next = _at + by;
    if (files.$2 > 1 && (next < 0 || next >= _hits.length)) {
      roll?.call(by);
    } else {
      super.step(by);
    }
  }

  /// Another file comes: its hits start at the end the step came to.
  void arrive(int by) {
    _arriving = by;
    _hits = const [];
    _at = 0;
  }

  @override
  void found(List<String> hits) {
    final from = _arriving;
    _arriving = 0;
    super.found(hits);
    if (from < 0 && hits.isNotEmpty) {
      _at = hits.length - 1;
      notifyListeners();
    }
  }
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
  const new(this.find, {super.key, this.hint = 'Find in the chat'});

  final TranscriptFind find;
  final String hint;

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
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              Text(f.count, style: theme.ui(t.textMuted, size: 12)),
              IconTap(
                Icons.keyboard_arrow_up,
                tooltip: 'Previous (⇧⏎)',
                onTap: f.canStep ? () => f.step(-1) : null,
              ),
              IconTap(
                Icons.keyboard_arrow_down,
                tooltip: 'Next (⏎)',
                onTap: f.canStep ? () => f.step(1) : null,
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
/// with 0. The mark stops [below] short of its bottom: a message's actions
/// aren't part of it.
class Hit extends StatelessWidget {
  const new({
    required this.mark,
    required this.child,
    super.key,
    this.below = 0,
  });

  final int mark;
  final Widget child;
  final double below;

  @override
  Widget build(BuildContext context) {
    if (mark == 0) return child;
    final t = NushiTheme.of(context).t;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          bottom: below,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: mark == 2
                    ? t.accentSoft.withValues(alpha: 0.35)
                    : t.needsSoft.withValues(alpha: 0.25),
                border: Border(
                  left: BorderSide(
                    color: mark == 2 ? t.accent : t.needs,
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
