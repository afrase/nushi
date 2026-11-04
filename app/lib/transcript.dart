import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/bottom_follower.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_column.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_update.dart';
import 'package:nushi/fork_chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/jump_chip.dart';
import 'package:nushi/message_actions.dart';
import 'package:nushi/message_pins.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/paced.dart';
import 'package:nushi/pins_rail.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/selection_lines.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/widgets.dart';

/// Whether [e] is a tool call that shows as a row, and can join a run of
/// them (a review's findings show as a card of their own).
bool _row(Object? e) =>
    e is Item && e.kind == ItemKind.ITEM_KIND_TOOL_CALL && !e.hasFindings();

/// The items, with each run of tool calls as one list, and each subagent
/// as one [SubagentRun] with what it did.
List<Object> _entries(List<Item> items) {
  final subs = {for (final s in subagentsOf(items)) s.call.id: s};
  final out = <Object>[];
  for (final it in items) {
    final last = out.lastOrNull;
    if (subs.containsKey(it.parent)) continue;
    if (subs[it.id] case final sub?) {
      out.add(sub);
    } else if (_row(it) && last is List<Item>) {
      last.add(it);
    } else if (_row(it) && _row(last)) {
      out.last = [last! as Item, it];
    } else {
      out.add(it);
    }
  }
  return out;
}

/// A chat's items, built as they scroll into view. It opens at the bottom
/// and follows it while the agent writes; scrolled up, it stays put and
/// offers a way back to the latest. Selected text gets a toolbar above it
/// to ask a side chat about it, or to reply to it; selected by touch, the
/// selection's own menu has those beside Copy. Given [items] (a
/// subagent's steps) it shows those instead, between [header] and
/// [footer], [live] while more come.
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
    this.onTop,
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

  /// Called as the user scrolls near the top (the phone takes an older
  /// page then); what shows stays put as items come in above it.
  final VoidCallback? onTop;

  /// The entries a transcript's first frame builds, and how many more
  /// each frame after it adds, while it fills in.
  static const firstEntries = 12;
  static const moreEntries = 24;

  @override
  State<Transcript> createState() => _TranscriptState();
}

/// How wide the scrollbar's strip is, at the transcript's right edge.
const _scrollbarEdge = 16.0;

/// What the find bar covers of the transcript's top right.
const double _findBarWidth = 340.0 + NushiTheme.gutter;
const double _findBarHeight = 48.0;

/// How far under the transcript's top a message gone to from the pins'
/// menu lands.
const _pinGap = 16.0;

/// How long a message gone to from the pins' menu stays tinted.
const _flashFor = Duration(milliseconds: 1400);

class _TranscriptState extends State<Transcript> {
  final _follower = BottomFollower();
  final _area = GlobalKey<SelectionAreaState>();
  // A click outside (the composer) takes the focus and clears the
  // selection without reporting it: the toolbar goes with it. An open reply
  // box stays, its quote kept.
  late final FocusNode _areaFocus =
      FocusNode(debugLabel: 'transcript', onKeyEvent: _copy)..addListener(() {
        if (!_areaFocus.hasFocus && _at != null && _replyTo == null) {
          _closeToolbar();
        }
      });
  String _selected = '';
  bool _down = false; // a pointer is down on the transcript
  // Pacing holds while a pointer is down or text is selected.
  final _hold = ValueNotifier<bool>(false);
  bool _touch = false; // the last pointer down was a finger (or a pen)
  Rect? _at; // the selection's top and bottom middle, where the toolbar shows
  String? _replyTo; // the selection a reply is being written to
  _Anchor _anchor = _Anchor(); // where the reply box opened

  // The widget built for each entry, by key, and what it was built from.
  var _built = <String, (List<Object>, Widget)>{};

  // The first entry's key at the last build: when items come in above it,
  // the list moves down by their height, so what shows stays put.
  String? _first;

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
        // Filling in to a kept place, unseen (see build): more a frame.
        final more = Transcript.moreEntries * (_restore == null ? 1 : 4);
        setState(() => _tail = _tail! + more);
      }
    });
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
    if (widget.onTop case final top?
        when n is ScrollUpdateNotification &&
            n.depth == 0 &&
            (n.scrollDelta ?? 0) < 0 &&
            n.metrics.pixels < 800) {
      top();
    }
    // A code block's sideways scroll tells nobody where its text went: what
    // shows of a selection there would sit where it was.
    if (n is ScrollUpdateNotification &&
        n.depth > 0 &&
        n.metrics.axis == Axis.horizontal &&
        _selected.isNotEmpty &&
        _replyTo == null) {
      _clearSelection();
      if (_at != null) setState(() => _at = null);
    }
    // The list's height changed with no scroll and no build of all of it
    // (a call opened above a pin): the pins may have moved past the line.
    if (n is ScrollMetricsNotification && n.depth == 0) _findPinAt();
    return _follower.onNotification(n);
  }

  void _keepPlace(List<Object> entries, {required bool filling}) {
    if (widget.onTop == null && !filling || entries.isEmpty) return;
    final was = _first;
    final first = _first = _key(entries.first);
    if (was == null || was == first || !_follower.scroll.hasClients) return;
    // A glide to the bottom keeps its own place, from the bottom.
    if (_follower.following ||
        _follower.gliding ||
        !entries.any((e) => _key(e) == was)) {
      return;
    }
    final max = _follower.scroll.position.maxScrollExtent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_follower.scroll.hasClients) return;
      final q = _follower.scroll.position;
      q.jumpTo(
        (q.pixels + q.maxScrollExtent - max).clamp(0, q.maxScrollExtent),
      );
    });
  }

  /// An entry's key; a message's echo keeps the key of the message shown
  /// as it was on its way (ChatState.echoes).
  String _key(Object e) =>
      e is Item ? widget.chat.echoes[e.id] ?? e.id : _keyOf(e);

  /// Where a message this app sent is: 0 shown by the daemon (or not a
  /// message on its way), 1 on its way, 2 failed and going.
  int _sendState(Object e) {
    if (e is! Item || !widget.chat.sending.contains(e)) return 0;
    return widget.chat.unsent.contains(e.id) ? 2 : 1;
  }

  /// An entry's widget, the one built before if its items are the same.
  Widget _entry(
    Map<String, (List<Object>, Widget)> before,
    Object e, {
    required bool live,
    required bool still,
    required double top,
    required double width,
    bool rise = false,
  }) {
    final key = _key(e);
    final items = switch (e) {
      final List<Item> run => run,
      final SubagentRun s => [s.call, ...s.items],
      _ => [e],
    };
    final rewindable = e is Item && canRewindTo(widget.chat, e);
    final forkable =
        widget.items == null &&
        e is Item &&
        e.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE &&
        canForkAt(widget.daemon, widget.chat, e, live: live);
    // A failed turn's button goes by the items before its notice, not by
    // the notice: Continue, Try again, or none ('').
    final again = e is Item ? failedTurnRetry(widget.chat, e)?.label ?? '' : '';
    final sides = chatSides(context, width);
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
      top,
      sides.left,
      sides.right,
      ...items,
    ];
    final was = before[key];
    final same =
        was != null &&
        was.$1.length == from.length &&
        Iterable<int>.generate(from.length)
            .every((i) => identical(was.$1[i], from[i]));
    return (_built[key] = same
            ? was
            : (
                from,
                // Keyed, the item's state follows it as items arrive.
                Padding(
                  key: ValueKey(key),
                  // On the phone a user message's band goes edge to edge.
                  padding: _isBand(e) && TouchTargets.of(context)
                      ? EdgeInsets.only(top: top)
                      : EdgeInsets.fromLTRB(sides.left, top, sides.right, 0),
                  // New while the chat is open, it rises in, once.
                  child: Enter.rise(
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
                            child: _isBand(e)
                                ? _Sending(
                                    state: sending,
                                    child: _view(
                                      e,
                                      live: live,
                                      still: still,
                                      rewindable: rewindable,
                                      pinned: pinned,
                                      pinnable: pinnable,
                                    ),
                                  )
                                : _view(
                                    e,
                                    live: live,
                                    still: still,
                                    rewindable: rewindable,
                                    forkable: forkable,
                                    pinned: pinned,
                                    pinnable: pinnable,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ))
        .$2;
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
    final List<Item> run => RunView(run, still: still),
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

  /// Keeps where the chat is left (see [ChatState.kept]).
  void _keep(ChatState chat) {
    if (widget.items != null || _restore != null) return; // not there yet
    final s = _follower.scroll;
    chat.kept = _follower.following || _follower.gliding || !s.hasClients
        ? null
        : s.position.extentAfter;
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
      widget.chat.find.found([for (final m in marks) m.key]);
      _showCurrent();
    };
  }

  void _findChanged() {
    final q = (widget.chat.find.query ?? '').toLowerCase();
    if (q == _marks.query) {
      _showCurrent();
    } else {
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
      _keep(old.chat);
      _restore = null;
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
    _hold.dispose();
    _follower.dispose();
    _areaFocus.dispose();
    super.dispose();
  }

  // The selection is reported a frame after the pointer goes up: offer the
  // toolbar once both have happened.
  // On touch the selection's own menu offers the actions instead (_menu).
  void _offer() {
    if (_touch || _down || _at != null || _selected.trim().isEmpty) return;
    if (_anchors() case final at?) setState(() => _at = at);
  }

  /// The selection's top and bottom middle, in the transcript's box.
  Rect? _anchors() {
    final a = _area.currentState?.selectableRegion.contextMenuAnchors;
    final box = context.findRenderObject() as RenderBox?;
    if (a == null || box == null) return null;
    return Rect.fromPoints(
      box.globalToLocal(a.primaryAnchor),
      box.globalToLocal(a.secondaryAnchor ?? a.primaryAnchor),
    );
  }

  void _openReply() => setState(() {
    _at ??= _anchors();
    _replyTo = _selectedText();
    _anchor = _Anchor();
  });

  /// The selection's menu: as the platform's on a mouse; on touch, one menu
  /// of Copy, Side chat and Reply where the platform draws its own, so
  /// nothing of Nushi's sits under it (iOS's Copy | Select All hid the
  /// toolbar on the phone).
  Widget _menu(
    SelectableRegionState region, {
    required VoidCallback? onSide,
    required VoidCallback? onReply,
  }) {
    if (!_touch || (onSide == null && onReply == null)) {
      return AdaptiveTextSelectionToolbar.selectableRegion(
        selectableRegionState: region,
      );
    }
    VoidCallback then(VoidCallback run) => () {
      region.hideToolbar();
      run();
    };
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: region.contextMenuAnchors,
      buttonItems: [
        ...region.contextMenuButtonItems.where(
          (b) => b.type == ContextMenuButtonType.copy,
        ),
        if (onSide != null)
          ContextMenuButtonItem(label: 'Side chat', onPressed: then(onSide)),
        if (onReply != null)
          ContextMenuButtonItem(label: 'Reply', onPressed: then(onReply)),
      ],
    );
  }

  void _closeToolbar() => setState(() => _at = _replyTo = null);

  /// A press of the mouse starts a new selection, so the last one goes
  /// first: its edges otherwise carry into the new one. Shift extends it,
  /// and one on the scrollbar, at the edge of [width], starts none.
  void _startSelection(PointerDownEvent e, double width) {
    if (e.kind == PointerDeviceKind.mouse &&
        e.buttons == kPrimaryButton &&
        e.localPosition.dx < width - _scrollbarEdge &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _clearSelection();
    }
  }

  /// The selection's text with its lines (selectionLines).
  String _selectedText() {
    final box = _area.currentContext?.findRenderObject();
    final lines = box == null ? '' : selectionLines(box);
    return lines.isEmpty ? _selected : lines;
  }

  /// ⌘C: the selection with its lines, not the run-together text the
  /// selection area itself copies.
  KeyEventResult _copy(FocusNode _, KeyEvent e) {
    final keys = HardwareKeyboard.instance;
    if (e is KeyUpEvent ||
        e.logicalKey != LogicalKeyboardKey.keyC ||
        !(keys.isMetaPressed || keys.isControlPressed) ||
        _selected.isEmpty) {
      return KeyEventResult.ignored;
    }
    unawaited(Clipboard.setData(ClipboardData(text: _selectedText())));
    return KeyEventResult.handled;
  }

  void _clearSelection() =>
      _area.currentState?.selectableRegion.clearSelection();

  void _pointerGone() {
    _down = false;
    _hold.value = _selected.isNotEmpty;
    _offer();
    if (_tail != null) setState(() {}); // it goes on filling in
  }

  // A find's matches in the text as it's laid out (ChatState.find has their
  // keys), and the last time the find asked for its current one to show.
  final _marks = TextMarks();
  int _shownAsk = -1;
  bool _roomAbove = false; // the list starts below the find bar

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
  static double _pinLine(ScrollPosition p) {
    final third = p.viewportDimension / 3;
    final low = p.viewportDimension - 24; // at the bottom, what shows counts
    final top = (p.pixels - p.minScrollExtent).clamp(0, third).toDouble();
    final toBottom = max(0, p.maxScrollExtent - p.pixels);
    final bottom = low - toBottom * (low - third) / (2 * third);
    return max(top, bottom);
  }

  /// Goes to the message of [id] from the pins' menu, or to the chat's
  /// start for '': the phone first takes the pages it's on.
  Future<void> _pick(String id) async {
    if (widget.onTop != null) {
      await loadPinned(widget.daemon, widget.chat, all: id.isEmpty);
    }
    if (!mounted) return;
    setState(() {
      _tail = null; // all of it, to know where it is
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
    final at = i + (widget.header == null ? 0 : 1);
    if (i < 0 || boxes == null || at >= boxes.length) {
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
    final entries = _entries(widget.items ?? [...chat.items, ...chat.sending]);
    final query = widget.items == null ? chat.find.query ?? '' : '';
    // A find looks in all of it, and needs its place to go to it: what's
    // still to come in comes now. Not under a press (_grow).
    if (query.isNotEmpty && !_down) _tail = null;
    if (chat.find.query == null) _roomAbove = false;
    // While it fills in, the entries above what's built wait.
    final tail = _tail;
    final from = tail == null ? 0 : max(0, entries.length - tail);
    if (from > 0) {
      _grow();
    } else if (widget.items != null || chat.loaded) {
      _tail = null;
    }
    _keepPlace(entries.sublist(from), filling: tail != null);
    _laidOut = entries.sublist(from);
    if (_goTo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _go());
    }
    final rail = widget.items == null ? pinEntries(chat) : const <PinEntry>[];
    _railIds = [for (final e in rail) e.id];
    final pinned = _railIds.toSet();
    _railAt = {
      if (pinned.isNotEmpty)
        for (final (i, e) in _laidOut.indexed)
          if (e is Item && pinned.contains(e.id))
            e.id: i + (widget.header == null ? 0 : 1),
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
    _marks.look(
      tail == null ? query : '',
      query.isEmpty ? const [] : [for (final e in entries) _key(e)],
      hit: t.needs.withValues(alpha: 0.3),
      now: t.accent.withValues(alpha: 0.4),
      edge: t.accent,
    );
    final before = _built;
    _built = {};
    final onReply = widget.onReply;
    final onSide = chat.canFork ? widget.onSide : null;
    final side = onSide == null
        ? null
        : () {
            final selected = _selectedText();
            _closeToolbar();
            onSide(selected);
          };
    final reply = onReply == null ? null : _openReply;
    final view = LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          NotificationListener(
            onNotification: _onScroll,
            // One selection across the transcript, messages included whole;
            // when a drag or double-click leaves text selected, the popover
            // shows where the pointer went up.
            child: Listener(
              onPointerDown: (e) {
                _startSelection(e, box.maxWidth);
                setState(() {
                  _down = _hold.value = true;
                  _touch = e.kind != PointerDeviceKind.mouse;
                  _at = _replyTo = null;
                });
              },
              onPointerUp: (_) => _pointerGone(),
              onPointerCancel: (_) => _pointerGone(),
              child: SelectionArea(
                key: _area,
                focusNode: _areaFocus,
                contextMenuBuilder: (context, region) =>
                    _menu(region, onSide: side, onReply: reply),
                onSelectionChanged: (c) {
                  _selected = c?.plainText ?? '';
                  _hold.value = _down || _selected.isNotEmpty;
                  _offer();
                },
                // Every item is laid out, so the list knows its exact
                // height: the scrollbar keeps its size and nothing shifts
                // as items come into view. Unchanged items keep their
                // widget, so a streamed chunk rebuilds only its message.
                child: PacingHold(
                  notifier: _hold,
                  // Unseen while it fills in up to a kept place, rather
                  // than showing each frame what came in above.
                  child: Opacity(
                    opacity: _restore == null ? 1 : 0,
                    child: SingleChildScrollView(
                      controller: _follower.scroll,
                      padding: EdgeInsets.only(
                        top: _padTop = _roomAbove ? _findBarHeight + 8 : 2,
                        bottom: 14,
                      ),
                      child: Column(
                        key: _column,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.header case final h?)
                            Padding(
                              padding: chatSides(context, box.maxWidth),
                              child: h,
                            ),
                          for (final (i, e) in entries.indexed.skip(from))
                            _entry(
                              before,
                              e,
                              live: live && i == entries.length - 1,
                              still: chat.waiting,
                              top: _gap(
                                entries,
                                i,
                                header: widget.header != null,
                                phone: TouchTargets.of(context),
                              ),
                              width: box.maxWidth,
                              rise: arrived.contains(_key(e)),
                            ),
                          if (widget.footer case final f?)
                            Padding(
                              padding: chatSides(context, box.maxWidth),
                              child: f,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_at case final at? when onReply != null || onSide != null)
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _Above(at, _replyTo == null ? null : _anchor),
                child: switch (_replyTo) {
                  // Its own layer: typing repaints only the box.
                  final quote? => RepaintBoundary(
                    child: ReplyBox(
                      quote: quote,
                      onReply: onReply!,
                      onClose: _closeToolbar,
                    ),
                  ),
                  null => SelectionToolbar(onSide: side, onReply: reply),
                },
              ),
            ),
          // In the margin at the top left, where it stays as the text scrolls.
          if (rail.isNotEmpty)
            Positioned(
              left: 0,
              top: 6,
              child: PinsRail(
                entries: [PinEntry.start, ...rail],
                current: _pinAt,
                inset: railInset(
                  context,
                  chatSides(context, box.maxWidth).left,
                ),
                onPick: (id) => unawaited(_pick(id)),
                before: widget.onTop == null
                    ? null
                    : () => loadPinned(widget.daemon, chat),
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
                  onTap: () => _follower.follow(glide: !reduceMotion(context)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return TextMarksScope(marks: _marks, child: view);
  }
}

/// An entry's key: a call and the group it becomes keep their place (and
/// state).
String _keyOf(Object e) => switch (e) {
  final List<Item> run => run.first.id,
  final SubagentRun s => 'agent ${s.call.id}',
  _ => (e as Item).id,
};

/// A message of yours: faint while on its way ([state] 1), then whole over
/// [Motion.quick] as the daemon shows it; one whose send failed (2) fades
/// out and folds away over [Motion.exit] (the transcript then drops it).
/// With Reduce Motion it's faint, then whole, and goes at once.
class _Sending extends StatelessWidget {
  const new({required this.state, required this.child});

  final int state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final shown = AnimatedOpacity(
      opacity: state == 1 ? 0.7 : 1,
      duration: still ? Duration.zero : Motion.quick,
      child: child,
    );
    if (state != 2 || still) return shown;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: Motion.exit,
      curve: Motion.leave,
      builder: (context, v, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: v,
          child: Opacity(opacity: 0.7 * v, child: child),
        ),
      ),
      child: IgnorePointer(child: shown),
    );
  }
}

bool _isBand(Object e) =>
    e is Item && e.kind == ItemKind.ITEM_KIND_USER_MESSAGE;

/// A user message's band, the agent starting on its own, or where a
/// reopened chat's history comes from changes.
bool _opens(Object e) =>
    _isBand(e) ||
    e is Item &&
        e.kind == ItemKind.ITEM_KIND_NOTICE &&
        const {'own_turn', 'compacted', 'history_differs'}.contains(e.status);

/// The room above entry [i]: more around what opens a chapter than between
/// the agent's steps, so each exchange reads as one.
double _gap(
  List<Object> entries,
  int i, {
  required bool header,
  required bool phone,
}) {
  final gap = _opens(entries[i])
      ? (i == 0 && !header
            ? 8.0
            : phone
            ? 28.0
            : 32.0)
      : (!phone
            ? 16.0
            : i > 0 && _opens(entries[i - 1])
            ? 18.0
            : 12.0);
  // A message's actions keep their room under it.
  final after = !phone && i > 0 && _hasActions(entries[i - 1]);
  return after ? max(0, gap - messageActionsHeight) : gap;
}

bool _hasActions(Object e) =>
    e is Item &&
    (e.kind == ItemKind.ITEM_KIND_USER_MESSAGE ||
        e.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE);

/// Where a reply box's bottom edge went when it opened: it stays there as
/// the box grows a line at a time, so the box grows upward, as Claude's.
class _Anchor {
  double? bottom;
}

/// Places its child centered just above [at] (a selection's top and bottom
/// middle), or below it when there is no room above, inside the box. With
/// an [anchor] (the reply box) the child keeps the bottom edge it first
/// had, kept inside too.
class _Above extends SingleChildLayoutDelegate {
  new(this.at, [this.anchor]);

  final Rect at;
  final _Anchor? anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(
    maxWidth: max(0, c.maxWidth - 16),
    maxHeight: max(0, c.maxHeight - 8),
  );

  @override
  Offset getPositionForChild(Size size, Size child) {
    double inside(double y) =>
        y.clamp(4, max(4, size.height - child.height - 4));
    final double y;
    if (anchor?.bottom case final bottom?) {
      y = inside(bottom - child.height);
    } else {
      final above = at.top - child.height - 6;
      y = inside(above < 4 ? at.bottom + 6 : above);
      anchor?.bottom = y + child.height;
    }
    return Offset(
      (at.center.dx - child.width / 2).clamp(
        8,
        max(8, size.width - child.width - 8),
      ),
      y,
    );
  }

  @override
  bool shouldRelayout(_Above old) => old.at != at || old.anchor != anchor;
}
