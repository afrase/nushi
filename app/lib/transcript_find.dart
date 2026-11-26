import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What every find marks its matches in, from the theme: each match in
/// `hit`, the current one in `now` with an `edge` around it. The
/// transcript, the editor and each preview's find draw in these.
typedef FindColors = ({Color hit, Color now, Color edge});

/// [t]'s find colours ([FindColors]).
FindColors findColors(Tokens t) => (
  hit: t.needs.withValues(alpha: 0.3),
  now: t.accent.withValues(alpha: 0.4),
  edge: t.accent,
);

/// Which way a find reads its matches: where ⏎ goes and what its count
/// counts from. Its hits are in the text's order, top to bottom, either
/// way, and its bar's ↑ and ↓ go up and down the text.
enum FindOrder {
  /// From the top down, as a file, a diff, a page and Changes are read: ⏎
  /// the next match below, the first one counted 1.
  topDown,

  /// From the newest up, as a chat is read from its end (ADR 0144): ⏎ the
  /// next older match, above, the last one counted 1, since what is looked
  /// for was most often just said.
  newestFirst;

  /// The step ⏎ takes through the hits: 1 down the text, -1 up it.
  int get onward => this == topDown ? 1 : -1;

  /// Hit [at]'s number among [of], counted from where it reads from.
  int number(int at, int of) => this == topDown ? at + 1 : of - at;

  /// Where it starts among [of] hits: the first, or the newest (the last).
  int start(int of) => this == topDown ? 0 : max(0, of - 1);
}

/// ⌘F in a chat's transcript: what's looked for (null: the bar is closed),
/// its matches as the transcript last laid them out ([TextMark.key]: each
/// match in a text, each in what a row folds away) and which one is current.
class Find extends ChangeNotifier {
  /// A find reading in [order]; top down unless its maker says.
  new({this.order = FindOrder.topDown});

  /// Which way it reads: ⏎'s way through the hits and the count's start.
  final FindOrder order;

  String? _query;
  List<String> _hits = const [];
  int _at = 0;
  int _asked = 0;

  /// The field takes the focus when the bar opens, or ⌘F again.
  final focus = FocusNode(debugLabel: 'find');

  String? get query => _query;
  List<String> get hits => _hits;
  int get at => _at;

  /// The current hit's key, if any.
  String? get current =>
      _hits.isEmpty ? null : _hits[_at.clamp(0, _hits.length - 1)];

  /// Counts the times the current match was asked to come into view: a
  /// step, or the text typed. A match the agent's text brings doesn't.
  int get asked => _asked;

  /// Whether ⏎ goes anywhere.
  bool get canStep => _hits.isNotEmpty;

  /// How far it's come, for the bar.
  String get count => (_query ?? '').isEmpty
      ? ''
      : _hits.isEmpty
      ? 'None'
      : '${order.number(_at, _hits.length)} of ${_hits.length}';

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
    // Where it reads from, before anyone hears: a chat's find told with
    // its oldest hit current would take the view up the chat.
    _at = order.start(_hits.length);
    _asked++;
    notifyListeners();
  }

  /// The transcript found [hits]: the current one stays if it's still a hit.
  void found(List<String> hits) {
    if (listEquals(hits, _hits)) return;
    final was = current;
    _hits = hits;
    final i = was == null ? -1 : hits.indexOf(was);
    _at = i >= 0 ? i : order.start(hits.length);
    notifyListeners();
  }

  /// Takes [hits], the one at [at] current, for a find that picks its
  /// own: a terminal's starts from its latest output, an editor's from its
  /// caret, a chat's whole find (ChatFind) the match a step loaded, which
  /// it [ask]s to show.
  @protected
  void foundAt(List<String> hits, int at, {bool ask = false}) {
    _hits = hits;
    _at = hits.isEmpty ? 0 : at.clamp(0, hits.length - 1);
    if (ask) _asked++;
    notifyListeners();
  }

  /// The next hit down the text ([by] 1) or the one above it (-1), round;
  /// ⏎ goes [FindOrder.onward].
  void step(int by) {
    if (_hits.isEmpty) return;
    _at = (_at + by) % _hits.length;
    _asked++;
    notifyListeners();
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }
}

/// ⌘F in a chat's Changes view. The files with the text are listed and the
/// hits counted are those of the file shown (a diff isn't read for a file
/// that isn't); going past either end of them goes on to the next file with
/// [roll], which the view sets.
class ChangesFind extends Find {
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

/// How many matches a row folds away, beside its title; nothing with none.
/// It's no part of the text: neither selected nor looked in.
class FoundCount extends StatelessWidget {
  const new(this.found, {super.key});

  final ValueListenable<int> found;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return ValueListenableBuilder(
      valueListenable: found,
      builder: (context, n, _) => n == 0
          ? const SizedBox.shrink()
          : Unmarked(
              child: SelectionContainer.disabled(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: Text(
                    n == 1 ? '1 match' : '$n matches',
                    style: theme.ui(
                      theme.t.textSecondary,
                      size: 11.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// ⇧⏎: the match the other way from ⏎'s.
const _backKey = SingleActivator(LogicalKeyboardKey.enter, shift: true);

/// The find bar over the transcript: the field, "2 of 7", ↑ and ↓ (up and
/// down the text, whichever way the find reads), ⏎ onward in its order
/// ([FindOrder.onward]) and ⇧⏎ back, and × (or Esc) to close. Given
/// [loadAll] (a chat with more before what it has loaded), a line under
/// them says the find looks in what's loaded, and Load all takes the rest
/// ([loading] while it comes).
class FindBar extends StatefulWidget {
  const new(
    this.find, {
    super.key,
    this.hint = 'Find in the chat',
    this.loadAll,
    this.loading = false,
  });

  final Find find;
  final String hint;
  final VoidCallback? loadAll;
  final bool loading;

  /// What the bar covers of the transcript's top, the room above it
  /// included: without its line under it, and with it.
  static const height = 48.0;
  static const withNote = 66.0;

  /// How wide the bar is.
  static const width = 340.0;

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
        final all = widget.loadAll;
        final on = f.order.onward;
        final (enter, back) = (enterLabel, keyLabel(_backKey));
        final (up, down) = switch (f.order) {
          FindOrder.topDown => (
            withKey('Previous', back),
            withKey('Next', enter),
          ),
          FindOrder.newestFirst => (
            withKey('Older match', enter),
            withKey('Newer match', back),
          ),
        };
        final row = Row(
          children: [
            Icon(Icons.search, size: 14, color: t.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): f.close,
                  const SingleActivator(LogicalKeyboardKey.enter): () =>
                      f.step(on),
                  _backKey: () => f.step(-on),
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
                  // A line of the bar, no box: its own padding and hint,
                  // not a field's, so the bar stays [FindBar.height].
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: theme.ui(t.textMuted),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Text(f.count, style: theme.ui(t.textMuted, size: 12)),
            IconTap(
              Icons.keyboard_arrow_up,
              tooltip: up,
              onTap: f.canStep ? () => f.step(-1) : null,
            ),
            IconTap(
              Icons.keyboard_arrow_down,
              tooltip: down,
              onTap: f.canStep ? () => f.step(1) : null,
            ),
            IconTap(
              Icons.close,
              tooltip: withKey('Close', 'Esc'),
              onTap: f.close,
            ),
          ],
        );
        return Container(
          width: FindBar.width,
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          decoration: floatBox(t, radius: NushiTheme.card),
          // The row is the column's first child with or without the line
          // under it: in another place in the tree its field would be built
          // anew, with the focus and no keyboard, and typing would stop as
          // the line came (earlier messages loading as a match shows).
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row,
              if (all != null || widget.loading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 6, 4),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.loading
                              ? 'Loading earlier messages…'
                              : 'Searching loaded messages · ',
                          overflow: TextOverflow.ellipsis,
                          style: theme.ui(t.textMuted, size: 12),
                        ),
                      ),
                      if (all != null && !widget.loading)
                        LinkText('Load all', size: 12, onTap: all),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
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
