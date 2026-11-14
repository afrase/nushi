import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/bottom_follower.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_column.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/fork_chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_link_chip.dart' show GitHubLinks;
import 'package:nushi/items.dart';
import 'package:nushi/jump_chip.dart';
import 'package:nushi/message_pins.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_live_card.dart';
import 'package:nushi/rail.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/transcript_entries.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/transcript_pages.dart';
import 'package:nushi/transcript_selection.dart';
import 'package:nushi/turn_retry.dart';
import 'package:nushi/widgets.dart';

/// A chat's items, built as they scroll into view. It opens at the bottom
/// and follows it while the agent writes; scrolled up, it stays put and
/// offers a way back to the latest. Selected text gets a toolbar above it
/// to ask a side chat about it, or to reply to it; selected by touch, the
/// selection's own menu has those beside Copy. Given [items] (a
/// subagent's steps) it shows those instead, between [header] and
/// [footer], [live] while more come. A chat's transcript takes its older
/// pages as it scrolls near the top: on the Mac with [EarlierMessages] at
/// its top, on the phone ([Daemon.remote]) with its own [header], trying
/// again on every scroll there after a failed page.
class Transcript extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onReply,
    super.key,
    this.onSide,
    this.items,
    this.live = false,
    this.header,
    this.footer,
    this.bottom,
  });

  final ChatState chat;
  final Daemon daemon;

  /// Takes a reply to the selection (for the composer); null hides the
  /// action.
  final void Function(Reply reply)? onReply;

  /// Opens a side chat about the selection; null hides the action.
  final void Function(String selection)? onSide;

  final List<Item>? items;
  final bool live;
  final Widget? header;
  final Widget? footer;

  /// Under the list (the chat's turn status and composer), the list's
  /// scrollbar running down beside it to the pane's bottom (OverBottom).
  final Widget? bottom;

  /// The entries a transcript's first frame builds, and how many more
  /// each frame after it adds, while it fills in.
  static const firstEntries = 12;
  static const moreEntries = 24;

  @override
  State<Transcript> createState() => _TranscriptState();
}

/// What the find bar covers of the transcript's top right.
const double _findBarWidth = 340.0 + NushiTheme.gutter;

/// How far under the transcript's top a message gone to from the pins'
/// menu lands.
const _pinGap = 16.0;

/// How long a message gone to from the pins' menu stays tinted.
const _flashFor = Duration(milliseconds: 1400);

class _TranscriptState extends State<Transcript> {
  final _follower = BottomFollower();
  bool _down = false; // a pointer is down on the transcript

  // The widget built for each entry, by key, and what it was built from.
  var _built = <String, (List<Object>, Widget)>{};

  // The keys of the entries laid out at the last build, and whether a
  // header was above them: when entries come in above them, the list moves
  // down by their height in the same layout, so what shows stays put.
  List<String> _laidKeys = const [];
  bool _hadHeader = false;

  // The first item of the first entry at the last build: a page that comes
  // in above it fills in a few frames, as the chat does when it opens. An
  // item, not an entry's key: a call that joins a run the page brings
  // changes the run's key.
  String? _firstItem;

  /// How many of the last entries are built, while the transcript fills
  /// in; null once all of it is. A chat opens at its bottom, so its first
  /// frame builds only what shows there and the rest comes in above it
  /// over the next frames: a click on a long chat shows at once
  /// (ADR 0026). One opening at the top (a finished subagent's) builds
  /// all of it.
  int? _tail;
  bool _growing = false;

  /// Builds [Transcript.moreEntries] more after this frame.
  void _grow() {
    if (_growing) return;
    _growing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _growing = false;
      // Not under a press: a selection's edges are kept by the scroll
      // offset, which each entry coming in above would move.
      if (mounted && _tail != null && !_down) {
        // Filling in to a kept place (unseen, see build), a message gone
        // to or a find, which wait for it: more a frame.
        final waits =
            _restore != null ||
            _goTo != null ||
            (widget.chat.find.query ?? '').isNotEmpty;
        final more = Transcript.moreEntries * (waits ? 4 : 1);
        setState(() => _tail = _tail! + more);
      }
    });
  }

  /// A pointer went down on the transcript, or up: it doesn't fill in
  /// under a press, and goes on once it's up.
  void _pressed(bool down) {
    _down = down;
    if (!down && _tail != null) setState(() {}); // it goes on filling in
  }

  // The entries' keys at the last build, once the chat had loaded: what
  // comes in after them rises in. Not what a load or an older page brings.
  List<String>? _shown;
  ChatState? _shownChat;

  /// The keys of [entries] that are new since the last build, after the
  /// last of what was there; none on the first build or a load.
  Set<String> _arrived(List<Object> entries) {
    final keys = [for (final e in entries) _key(e)];
    final was = _shownChat == widget.chat ? _shown : null;
    final loaded = widget.items != null || widget.chat.loaded;
    _shown = loaded ? keys : null;
    _shownChat = widget.chat;
    if (was == null || was.isEmpty) return const {};
    final known = was.toSet();
    final last = keys.lastIndexWhere(known.contains);
    if (last < 0) return const {}; // all of it anew: a reload
    return {for (final k in keys.skip(last + 1)) k};
  }

  bool _onScroll(Notification n) {
    // Within a screen of the top, scrolling up, or as the list's height
    // changes there (a short recent part, a page that left it near).
    final near = switch (n) {
      ScrollUpdateNotification(depth: 0, :final metrics, :final scrollDelta)
          when (scrollDelta ?? 0) < 0 =>
        metrics,
      ScrollMetricsNotification(depth: 0, :final metrics)
          when !widget.chat.olderFailed =>
        metrics,
      _ => null,
    };
    if (near != null && near.extentBefore < near.viewportDimension) {
      _nearTop();
    }
    // The list's height changed with no scroll and no build of all of it
    // (a call opened above a pin): the pins may have moved past the line.
    if (n is ScrollMetricsNotification && n.depth == 0) _findPinAt();
    return _follower.onNotification(n);
  }

  /// Keeps what shows where it is as [laidOut] comes in with entries
  /// above those laid out at the last build (a page, or the chat filling
  /// in): the first of those still there ends as far down the screen as it
  /// did (its bottom, which its gap above doesn't move), in the layout
  /// that adds them (BottomFollower.shift), not a frame after it.
  void _keepPlace(List<Object> laidOut, {required bool header}) {
    final was = _laidKeys;
    final wasHeader = _hadHeader;
    final keys = [for (final e in laidOut) _key(e)];
    _laidKeys = keys;
    _hadHeader = header;
    if (was.isEmpty || keys.isEmpty) return;
    if (keys.first == was.first && header == wasHeader) return;
    // A glide to the bottom keeps its own place, from the bottom.
    if (_follower.following ||
        _follower.gliding ||
        !_follower.scroll.hasClients) {
      return;
    }
    final column = _column.currentContext?.findRenderObject();
    if (column is! RenderFlex) return;
    final index = {for (final (i, k) in keys.indexed) k: i};
    for (final (i, k) in was.indexed) {
      final at = index[k];
      if (at == null) continue; // joined the run above it
      // Its bottom: the top of the entry after it (the same one after it
      // still), or its own top if it was the last.
      final row = i + (wasHeader ? 1 : 0);
      final next = topOfChild(column, row + 1) != null ? 1 : 0;
      final top = topOfChild(column, row + next);
      if (top == null) return;
      final to = at + (header ? 1 : 0) + next;
      _follower.shift = () {
        final by = switch (topOfChild(column, to)) {
          final now? => now - top,
          null => 0.0,
        };
        _pickedAt += by; // a pick's place moves with what it shows
        return by;
      };
      return;
    }
  }

  /// A page that came in above what's built builds over the next frames,
  /// as the chat fills in when it opens: the first frame only what it was
  /// and [Transcript.moreEntries] more. A find or a pin gone to waits for
  /// what it needs to be built, faster ([_grow]).
  void _pageFills(List<Object> entries) {
    final was = _firstItem;
    _firstItem = entries.isEmpty ? null : entryItems(entries.first).first.id;
    if (_tail != null || was == null || was == _firstItem) return;
    final at = entries.indexWhere(
      (e) => entryItems(e).any((it) => it.id == was),
    );
    if (at > Transcript.moreEntries) {
      _tail = entries.length - at + Transcript.moreEntries;
    }
  }

  /// The user scrolled to within a screen of the top: the page before.
  /// Not while the list fills in (its top isn't built yet).
  /// What shows stays put as items come in above it.
  void _nearTop() {
    if (_tail != null || widget.items != null) return;
    if (widget.daemon.remote || !widget.chat.olderFailed) {
      unawaited(widget.daemon.loadOlder(widget.chat));
    }
  }

  /// Whether this is the Mac's transcript of a chat, with [EarlierMessages]
  /// at its top.
  bool get _pages => widget.items == null && !widget.daemon.remote;

  /// An entry's key; a message's echo keeps the key of the message shown
  /// as it was on its way (Outbox.echoes).
  String _key(Object e) =>
      e is Item ? widget.chat.outbox.echoes[e.id] ?? e.id : entryKey(e);

  /// Where a message this app sent is: 0 shown by the daemon (or not a
  /// message on its way), 1 on its way, 2 failed and going.
  int _sendState(Object e) {
    if (e is! Item || !widget.chat.outbox.sending.contains(e)) return 0;
    return widget.chat.outbox.unsent.contains(e.id) ? 2 : 1;
  }

  /// An entry's widget, the one built before if its items are the same:
  /// only its place (its insets, which follow the window's width, and the
  /// gap above it) is new, so a sidebar's slide moves the rows and
  /// rebuilds none of them.
  Widget _entry(
    Map<String, (List<Object>, Widget)> before,
    Object e, {
    required bool live,
    required bool still,
    required double top,
    required EdgeInsets sides,
    bool rise = false,
  }) {
    final key = _key(e);
    final items = entryItems(e);
    final rewindable = e is Item && canRewindTo(widget.chat, e);
    final forkable =
        widget.items == null &&
        e is Item &&
        e.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE &&
        canForkAt(widget.daemon, widget.chat, e, live: live);
    // A failed turn's button goes by the items before its notice, not by
    // the notice: Continue, Try again, or none ('').
    final again = e is Item ? failedTurnRetry(widget.chat, e)?.label ?? '' : '';
    final sending = _sendState(e);
    final pinned =
        widget.items == null &&
        e is Item &&
        widget.chat.pinnedMessages.contains(e.id);
    final pinnable =
        widget.items == null &&
        e is Item &&
        canPinMessage(widget.daemon, widget.chat, e, live: live);
    final flash = e is Item && e.id == _flash;
    final from = [
      sending,
      live,
      still,
      rewindable,
      forkable,
      again,
      pinned,
      pinnable,
      flash,
      ...items,
    ];
    final was = before[key];
    final same =
        was != null &&
        was.$1.length == from.length &&
        Iterable<int>.generate(from.length)
            .every((i) => identical(was.$1[i], from[i]));
    Widget item() => _view(
      e,
      live: live,
      still: still,
      rewindable: rewindable,
      forkable: forkable,
      pinned: pinned,
      pinnable: pinnable,
    );
    final view = same
        ? was.$2
        // New while the chat is open, it rises in, once.
        : Enter.rise(
            play: rise,
            child: RepaintBoundary(
              // Always there, as Marks is: a pick in the pins'
              // list tints the message for a moment.
              child: PinFlash(
                on: flash,
                // Always there, so that a find coming and going
                // leaves the entry's state alone.
                child: Marks(
                  entry: key,
                  // A call's title types out as it comes, or as it
                  // joins a run; not what the chat opened with.
                  child: Arriving(
                    play: rise || was != null,
                    child: isBand(e)
                        ? SendingEntry(state: sending, child: item())
                        : item(),
                  ),
                ),
              ),
            ),
          );
    _built[key] = (from, view);
    // Keyed, the item's state follows it as items arrive.
    return Padding(
      key: ValueKey(key),
      // On the phone a user message's band goes edge to edge.
      padding: isBand(e) && TouchTargets.of(context)
          ? EdgeInsets.only(top: top)
          : EdgeInsets.fromLTRB(sides.left, top, sides.right, 0),
      child: view,
    );
  }

  /// [entry], and after it the live cards of what [e]'s tool calls did to
  /// pull requests (ADR 0117 section 4): the Mac's own transcript only.
  Widget _withLiveCards(
    BuildContext context,
    Object e,
    EdgeInsets sides,
    Widget entry,
  ) {
    final cards = _liveCards(context, e, sides);
    if (cards == null) return entry;
    return Column(
      key: ValueKey('cards ${_key(e)}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [entry, cards],
    );
  }

  Widget? _liveCards(BuildContext context, Object e, EdgeInsets sides) {
    if (widget.items != null || widget.daemon.remote) return null;
    final calls = [
      for (final it in entryItems(e))
        if (it.kind == ItemKind.ITEM_KIND_TOOL_CALL) it.id,
    ];
    if (calls.isEmpty) return null;
    final cp = ChatPull.of(widget.daemon, widget.chat);
    final onPull = GitHubLinks.of(context)?.onPull ?? () {};
    return ListenableBuilder(
      listenable: cp,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final id in calls)
            if (cp.live[id] case final p?)
              Padding(
                padding: sides.copyWith(top: 10),
                child: LivePullCard(cp, p, onShow: onPull),
              ),
        ],
      ),
    );
  }

  /// An entry's view: an item, a run of tool calls or a subagent.
  Widget _view(
    Object e, {
    required bool live,
    required bool still,
    bool rewindable = false,
    bool forkable = false,
    bool pinned = false,
    bool pinnable = false,
  }) => switch (e) {
    final List<Item> run => RunView(
      run,
      still: still,
      refs: (images: widget.daemon.images, chatId: widget.chat.id),
    ),
    final SubagentRun s => SubagentLine(
      s,
      widget.chat,
      still: still,
      daemon: widget.daemon,
    ),
    _ => ItemView(
      e as Item,
      widget.chat,
      widget.daemon,
      live: live,
      still: still,
      onRewind: rewindable
          ? () => rewind(context, widget.daemon, widget.chat, e)
          : null,
      onFork: forkable
          ? () => forkChat(context, widget.daemon, widget.chat, at: e)
          : null,
      pinned: pinned,
      onPin: pinnable
          ? () => tryOrShow(
              context,
              () => toggleMessagePin(widget.daemon, widget.chat, e),
            )
          : null,
    ),
  };

  /// How far from the bottom the list is to be put back, while it fills in
  /// to there (the place the chat was left at, [ChatState.kept]).
  double? _restore;

  /// Opens the chat where it was left, scrolled up, unless it needs you.
  void _openAtKept() {
    final chat = widget.chat;
    if (widget.items != null) return;
    if (chat.kept case final kept? when !chat.waiting) {
      _follower.hold();
      _restore = kept;
    } else {
      chat.kept = null;
    }
  }

  /// Keeps where the chat is left (see [ChatState.kept]); left at its
  /// bottom, a long one goes back to its recent part.
  void _keep(ChatState chat) {
    if (widget.items != null || _restore != null) return; // not there yet
    final s = _follower.scroll;
    chat.kept = _follower.following || _follower.gliding || !s.hasClients
        ? null
        : s.position.extentAfter;
    if (chat.kept == null) widget.daemon.leftAtBottom(chat);
  }

  /// Puts the list back [_restore] from its bottom once that much is
  /// built; until then as far up as it goes.
  void _restoreAfterLayout() {
    if (_restore == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kept = _restore;
      if (!mounted || kept == null || !_follower.scroll.hasClients) return;
      final p = _follower.scroll.position;
      final at = p.maxScrollExtent - kept;
      final done = _tail == null && widget.chat.loaded;
      if (at < 0 && !done) return;
      setState(() => _restore = null);
      _follower.hold(at.clamp(0, p.maxScrollExtent));
    });
  }

  @override
  void initState() {
    super.initState();
    // A finished subagent's steps open at the top, at its prompt.
    if (widget.items != null && !widget.live) _follower.following = false;
    _openAtKept();
    if (_follower.following || _restore != null) {
      _tail = Transcript.firstEntries;
    }
    if (widget.items == null) widget.chat.find.addListener(_findChanged);
    _follower.scroll.addListener(_findPinAt);
    _marks.onFound = (marks) {
      final find = widget.chat.find;
      // Found only once more came in above (Load all): brought into view.
      if (find.hits.isEmpty &&
          marks.isNotEmpty &&
          widget.chat.older < _findOlder) {
        _shownAsk = -1;
      }
      find.found([for (final m in marks) m.key]);
      _showCurrent();
    };
  }

  void _findChanged() {
    final q = (widget.chat.find.query ?? '').toLowerCase();
    if (q == _marks.query) {
      _showCurrent();
    } else {
      _findOlder = widget.chat.older;
      setState(() {}); // the build looks for it
    }
  }

  @override
  void didUpdateWidget(Transcript old) {
    super.didUpdateWidget(old);
    if (old.chat == widget.chat &&
        (old.items == null) == (widget.items == null)) {
      return;
    }
    if (old.chat != widget.chat) {
      _findOlder = widget.chat.older;
      _keep(old.chat);
      _restore = null;
      _laidKeys = const [];
      _firstItem = null;
      if (widget.items == null) _follower.follow();
      _openAtKept();
      if (_follower.following || _restore != null) {
        _tail = Transcript.firstEntries;
      }
    }
    _shownAsk = -1;
    old.chat.find.removeListener(_findChanged);
    if (widget.items == null) widget.chat.find.addListener(_findChanged);
  }

  // Not in dispose: by then the list has let go of its scroll.
  @override
  void deactivate() {
    _keep(widget.chat);
    super.deactivate();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _follower.scroll.removeListener(_findPinAt);
    _pinAt.dispose();
    widget.chat.find.removeListener(_findChanged);
    _marks.dispose();
    _follower.dispose();
    super.dispose();
  }

  // A find's matches in the text as it's laid out (ChatState.find has their
  // keys), and the last time the find asked for its current one to show.
  final _marks = TextMarks();
  int _shownAsk = -1;
  // What was above what's loaded as the find's query was asked.
  late int _findOlder = widget.chat.older;
  bool _roomAbove = false; // the list starts below the find bar

  /// What the find bar covers of the transcript's top: more with its line
  /// saying it looks in what's loaded (FindBar.loadAll).
  double get _findBarHeight => widget.chat.older > 0 || widget.chat.loadingOlder
      ? FindBar.withNote
      : FindBar.height;

  /// Draws the find's current match as such and, if it was asked for,
  /// brings it into view.
  void _showCurrent() {
    final find = widget.chat.find;
    final marks = _marks.marks;
    final mark = marks.isEmpty
        ? null
        : marks[find.at.clamp(0, marks.length - 1)];
    _marks.pick(mark);
    if (find.asked == _shownAsk) return;
    _shownAsk = find.asked;
    if (mark != null) _reveal(mark);
  }

  /// Takes the list to [mark], a third of the way down, unless it shows
  /// already; either way the list stays there, whatever comes in, until the
  /// user goes back to the bottom. A jump, not a glide: whatever is in
  /// between isn't worth showing, and a glide is cut short by what moves
  /// the list as it fills in.
  void _reveal(TextMark mark) {
    final scroll = _follower.scroll;
    if (!scroll.hasClients) return;
    final p = scroll.position;
    final (box, rect) = mark.place;
    if (!box.attached) return;
    final list = RenderAbstractViewport.of(mark.entry);
    final top = list.getOffsetToReveal(box, 0, rect: rect).offset;
    final transcript = context.findRenderObject()! as RenderBox;
    final right = MatrixUtils.transformRect(
      box.getTransformTo(transcript),
      rect,
    ).right;
    final covered = right > transcript.size.width - _findBarWidth
        ? _findBarHeight
        : 0;
    // At the very top no scroll takes it out from under the bar (a chat's
    // first message sits right there): room above it, while the bar's open.
    if (top - p.minScrollExtent < covered && !_roomAbove) {
      setState(() => _roomAbove = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal(mark);
      });
      return;
    }
    if (p.maxScrollExtent <= 0) return; // all of it shows
    final shows =
        top >= p.pixels + covered &&
        top + rect.height <= p.pixels + p.viewportDimension;
    _follower.hold(
      shows
          ? null
          : list
                .getOffsetToReveal(box, 0.3, rect: rect)
                .offset
                .clamp(p.minScrollExtent, p.maxScrollExtent),
    );
    // In a code block, its own sideways scroll too.
    if (!identical(RenderAbstractViewport.of(box), list)) {
      box.showOnScreen(rect: rect);
    }
  }

  // A pick in the pins' menu: the message to go to ('' for the chat's
  // start) once all of it is laid out, and the one tinted for a moment.
  String? _goTo;
  int _goTries = 0;
  String? _flash;
  Timer? _flashTimer;
  final GlobalKey _column = GlobalKey();
  List<Object> _laidOut = const [];

  // The pins' rail: its entries' ids after the start's, and which entry is
  // current (0, the start): the last whose message's top is above a line a
  // third down the transcript, so it changes as one scrolls up near a pin.
  // One picked from the menu is current until the list scrolls from where
  // the pick took it ('' for the start).
  List<String> _railIds = const [];
  String? _picked;
  double _pickedAt = 0;
  // Where each pinned message's entry is among the column's children, as
  // last laid out: found once a build, not on each scroll.
  Map<String, int> _railAt = const {};
  List<RenderBox> _railBoxes = const [];
  final _pinAt = ValueNotifier<int>(0);
  double _padTop = 0;

  /// Finds the current entry from where the pinned messages are laid out:
  /// a few offsets read, on each scroll, after each build and when the
  /// list's height changes, nothing
  /// rebuilt but the rail, and only when it changes. A pin not laid out
  /// (above what's built while the transcript fills in, or on a page the
  /// phone hasn't taken) is above all that is.
  void _findPinAt() {
    final ids = _railIds;
    final column = _column.currentContext?.findRenderObject();
    if (ids.isEmpty ||
        !_follower.scroll.hasClients ||
        column is! RenderFlex ||
        !column.hasSize) {
      _pinAt.value = 0;
      return;
    }
    final p = _follower.scroll.position;
    if (_picked case final id?) {
      final at = id.isEmpty ? 0 : _railIds.indexOf(id) + 1;
      if ((id.isEmpty || at > 0) && (p.pixels - _pickedAt).abs() < 1) {
        _pinAt.value = at;
        return;
      }
      _picked = null; // scrolled since, or unpinned
    }
    final line = p.pixels + _pinLine(p);
    final boxes = _railBoxes;
    var current = 0;
    for (final (n, id) in ids.indexed) {
      final i = _railAt[id];
      final box = i == null || i >= boxes.length ? null : boxes[i];
      // One not laid out, or gone since (the frame that rebuilt the column
      // hasn't found its children yet), counts as above.
      final top = box != null && box.parent == column
          ? _padTop + (box.parentData! as FlexParentData).offset.dy
          : double.negativeInfinity;
      if (top > line) break;
      current = n + 1;
    }
    _pinAt.value = current;
  }

  /// Where the rail's line stands in the transcript at [p], from its top:
  /// a third down, but sliding up to the top over the first third of a
  /// screen's scroll and down to the bottom over the last two thirds, so
  /// the start is current at the top, and every pin in the first and last
  /// screens (a short last answer, two) is current somewhere.
  double _pinLine(ScrollPosition p) {
    final shows = p.viewportDimension;
    final third = shows / 3;
    final low = shows - 24; // at the bottom, what shows counts
    final top = (p.pixels - p.minScrollExtent).clamp(0, third).toDouble();
    final toBottom = max(0, p.maxScrollExtent - p.pixels);
    final bottom = low - toBottom * (low - third) / (2 * third);
    return max(top, bottom);
  }

  /// Goes to the message of [id] from the pins' menu, or to the chat's
  /// start for '': first the pages up to it, if it isn't loaded.
  Future<void> _pick(String id) async {
    if (widget.items == null) {
      await widget.daemon.loadOlder(
        widget.chat,
        through: [if (id.isNotEmpty) id],
        all: id.isEmpty,
      );
    }
    if (!mounted) return;
    // What's above what's built builds over a few frames up to it ([_go]
    // waits), not at once: a pin near a long chat's start is most of it.
    setState(() {
      _goTo = id;
      _goTries = 0;
    });
  }

  /// Takes the list to [_goTo], its top just under the transcript's, as a
  /// find's jump does ([_reveal]), and tints it for a moment.
  void _go() {
    final id = _goTo;
    if (id == null || !mounted || !_follower.scroll.hasClients) return;
    final p = _follower.scroll.position;
    if (id.isEmpty) {
      if (_tail != null) return; // the start isn't built yet
      _goTo = null;
      _pickedAt = p.minScrollExtent;
      _picked = id;
      _follower.hold(p.minScrollExtent);
      _findPinAt();
      return;
    }
    final i = _laidOut.indexWhere((e) => e is Item && e.id == id);
    final column = _column.currentContext?.findRenderObject();
    final boxes = column is RenderFlex ? column.getChildrenAsList() : null;
    final at = i + (_hadHeader ? 1 : 0);
    if (i < 0 || boxes == null || at >= boxes.length) {
      // Above what's built while it fills in: the next frames build it.
      if (_tail != null && widget.chat.items.any((it) => it.id == id)) return;
      // Not laid out yet (an older page coming in): a frame or two more.
      if (++_goTries < 4) {
        setState(() {});
      } else {
        _goTo = null;
      }
      return;
    }
    _goTo = null;
    final box = boxes[at];
    final to = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
    _pickedAt = (to - _pinGap).clamp(p.minScrollExtent, p.maxScrollExtent);
    _picked = id;
    _follower.hold(_pickedAt);
    _findPinAt();
    _flashTimer?.cancel();
    setState(() => _flash = id);
    _flashTimer = Timer(_flashFor, () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    // What this app sent shows at once, after the items, until its echo.
    final entries = transcriptEntries(
      widget.items ?? [...chat.items, ...chat.outbox.sending],
    );
    final query = widget.items == null ? chat.find.query ?? '' : '';
    final header =
        widget.header ??
        (_pages && chat.older > 0
            ? EarlierMessages(
                chat,
                onRetry: () => unawaited(widget.daemon.loadOlder(chat)),
              )
            : null);
    _pageFills(entries);
    if (chat.find.query == null) _roomAbove = false;
    // While it fills in, the entries above what's built wait.
    final tail = _tail;
    final from = tail == null ? 0 : max(0, entries.length - tail);
    if (from > 0) {
      _grow();
    } else if (widget.items != null || chat.loaded) {
      _tail = null;
    }
    _laidOut = entries.sublist(from);
    _keepPlace(_laidOut, header: header != null);
    if (_goTo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _go());
    }
    final rail = widget.items == null ? pinEntries(chat) : const <RailEntry>[];
    _railIds = [for (final e in rail) e.id];
    final pinned = _railIds.toSet();
    _railAt = {
      if (pinned.isNotEmpty)
        for (final (i, e) in _laidOut.indexed)
          if (e is Item && pinned.contains(e.id))
            e.id: i + (header == null ? 0 : 1),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final column = _column.currentContext?.findRenderObject();
      _railBoxes = _railIds.isNotEmpty && column is RenderFlex
          ? column.getChildrenAsList()
          : const [];
      _findPinAt();
    });
    final arrived = _arrived(entries);
    final live = widget.items == null ? chat.busy : widget.live;
    _follower.stick();
    _restoreAfterLayout();
    final t = NushiTheme.of(context).t;
    // A find looks in all of it, once it's built: while it fills in, what
    // it found stays as it was.
    if (_tail == null || query.isEmpty) {
      _marks.look(
        query,
        query.isEmpty ? const [] : [for (final e in entries) _key(e)],
        hit: t.needs.withValues(alpha: 0.3),
        now: t.accent.withValues(alpha: 0.4),
        edge: t.accent,
      );
    }
    final before = _built;
    _built = {};
    final behavior = ScrollConfiguration.of(context);
    final view = LayoutBuilder(
      builder: (context, box) {
        final sides = chatSides(context, box.maxWidth);
        // The selection gets the transcript's own box, as tall as the window
        // on a short chat, to place its toolbar and reply box in.
        return Stack(
          fit: StackFit.passthrough,
          children: [
            TranscriptSelection(
              width: box.maxWidth,
              onReply: widget.onReply,
              onSide: chat.canFork ? widget.onSide : null,
              onPress: _pressed,
              // Every item is laid out, so the list knows its exact height:
              // the scrollbar keeps its size and nothing shifts as items come
              // into view. Unchanged items keep their widget, so a streamed
              // chunk rebuilds only its message.
              child: NotificationListener(
                onNotification: _onScroll,
                // Unseen while it fills in up to a kept place, rather than
                // showing each frame what came in above.
                child: Opacity(
                  opacity: _restore == null ? 1 : 0,
                  child: _ownBar(
                    context,
                    SingleChildScrollView(
                      controller: _follower.scroll,
                      padding: EdgeInsets.only(
                        top: _padTop = _roomAbove ? _findBarHeight + 8 : 2,
                        bottom: 14,
                      ),
                      child: _codeBars(
                        behavior,
                        Column(
                          key: _column,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (header case final h?)
                              Padding(padding: sides, child: h),
                            // A live card goes with its entry: the column's
                            // children stay one an entry.
                            for (final (i, e) in entries.indexed.skip(from))
                              _withLiveCards(
                                context,
                                e,
                                sides,
                                _entry(
                                  before,
                                  e,
                                  live: live && i == entries.length - 1,
                                  still: chat.waiting,
                                  top: entryGap(
                                    entries,
                                    i,
                                    header: header != null,
                                    phone: TouchTargets.of(context),
                                  ),
                                  sides: sides,
                                  rise: arrived.contains(_key(e)),
                                ),
                              ),
                            if (widget.footer case final f?)
                              Padding(padding: sides, child: f),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // In the margin at the top left, where it stays as the text
            // scrolls.
            if (rail.isNotEmpty)
              Positioned(
                left: 0,
                top: 6,
                child: Rail(
                  label: 'Pinned messages',
                  entries: [sessionStart, ...rail],
                  current: _pinAt,
                  fit: RailFit.of(sides.left),
                  onPick: (id) => unawaited(_pick(id)),
                  before:
                      widget.daemon.remote &&
                          widget.daemon.daemonApi < pinTitlesApi
                      ? () => loadPinned(widget.daemon, chat)
                      : null,
                ),
              ),
            Positioned(
              right: TouchTargets.of(context) ? 20 : NushiTheme.gutter,
              bottom: 12,
              child: ListenableBuilder(
                listenable: _follower,
                builder: (context, _) => ChipFade(
                  // It goes as Jump to latest glides down.
                  show: !_follower.following && !_follower.gliding,
                  builder: (context) => JumpChip(
                    // A prompt waits below: the chip says so.
                    needs: widget.items == null && chat.waiting,
                    onTap: () =>
                        _follower.follow(glide: !reduceMotion(context)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    final under = widget.bottom;
    final list = TextMarksScope(marks: _marks, child: view);
    return under == null
        ? list
        : OverBottom(scroll: _follower.scroll, list: list, bottom: under);
  }

  /// The list, without its own scrollbar under a [Transcript.bottom]:
  /// OverBottom draws it.
  Widget _ownBar(BuildContext context, Widget list) =>
      widget.bottom == null ? list : withoutOwnScrollbar(context, list);

  /// What's in the list (a code block's sideways scroll) with the app's
  /// scrollbars, as [behavior] had them above the list.
  Widget _codeBars(ScrollBehavior behavior, Widget child) =>
      widget.bottom == null ? child : ownScrollbars(behavior, child);
}
