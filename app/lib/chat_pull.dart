import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/github_pull.dart' show openPullAt;
import 'package:nushi/motion.dart';
import 'package:nushi/pull_cache.dart';
import 'package:nushi/pull_lights.dart' show PullSection;
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_live_card.dart' show LivePull, livePullOf;
import 'package:nushi/pull_states.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/widgets.dart';

/// A chat's pull request, as its widget and the header's tab show it: what
/// the daemon found of its folder (repository, branch), the rows' items
/// and, while the Pull request tab shows it ([showTab]), the pull request
/// whole. It asks while the chat is open ([follow]), whether the details
/// panel shows or not: at once, 3 s after a tool call pushed or opened one
/// and after a turn ends, when the window comes to the front, and on its
/// timer (quietly; [every]). The timer's ask is only what nothing else
/// asks (ADR 0140): the branch's pull request while the chat has none
/// open, the rows the chats' states don't ask for, and the whole one only
/// while the tab shows. Each ask that finds one links it (the daemon's
/// FindChatPull; from API 119 only for a branch a tool call of the chat
/// pushed, and GitHub isn't asked for another); only Unlink keeps that one
/// off.
class ChatPull extends ChangeNotifier {
  /// The one of [chat].
  factory of(Daemon daemon, ChatState chat) =>
      (_all[chat] ??= ChatPull._(daemon, chat)).._seed();

  new _(this.daemon, this.chat);

  static final _all = Expando<ChatPull>();

  final Daemon daemon;
  final ChatState chat;

  /// What the daemon said of the chat's folder; null until it answered.
  FindChatPullResponse? found;

  /// The linked pull request whole; null until asked, or with none. Until
  /// the first ask answers, what was read last (`pull_cache.dart`), from
  /// [keptAt].
  GitHubPull? pull;

  /// When the pull request showing was read, while it's the one kept
  /// from before (null once asked).
  DateTime? keptAt;

  /// Whether it's being asked for now.
  bool get asking => _asking != null;

  /// Whether the tab's line says it's refreshing: while it's asked, and
  /// for [Waits.refreshShown] at least after a Refresh the user asked for
  /// ([refreshAsked]).
  bool get busy => asking || _shown != null;

  /// A Refresh the user asked for, while it's still shown working.
  Timer? _shown;

  /// The tab's Refresh and ⌘R: asked now (or the ask under way joined),
  /// its line busy for [Waits.refreshShown] at least. Another press in
  /// that time changes nothing.
  void refreshAsked() {
    if (_shown != null) return;
    _shown = Timer(Waits.refreshShown, () {
      _shown = null;
      notifyListeners();
    });
    notifyListeners();
    unawaited(refresh());
  }

  /// When the pull request showing was read: the copy kept from before
  /// ([keptAt]) or GitHub's last answer; null with none. The tab says it
  /// ("Updated 2m ago").
  DateTime? get readAt => keptAt ?? _wholeAt;

  /// The last ask for the tab's pull request failed: what shows is from
  /// [readAt] ("Couldn't refresh · as of 2m ago"), [error] says why.
  bool failed = false;

  /// What was read last of the linked pull request, until it's asked.
  void _seed() {
    final l = current;
    if (pull != null || l == null) return;
    if (cachedPull(l.asRef) case (final at, final p)) {
      pull = p;
      keptAt = at;
    }
  }

  /// Why the last ask failed (what shows stays).
  String? error;

  int _followers = 0;
  int _tabs = 0;
  DateTime? _wholeAt;
  Timer? _timer;
  Timer? _soon;
  AppLifecycleListener? _front;
  bool _busy = false;
  final _seen = <String>{};
  final _seenLive = <String>{};

  /// The transcript's live cards (ADR 0117 section 4): the pull requests a
  /// tool call opened or merged while the chat showed, by the call's id;
  /// dropped once it no longer shows, never saved.
  final Map<String, LivePull> live = {};
  Future<void>? _asking;
  DateTime? _asked;
  int _rechecks = 0;

  /// The chat's pull requests in the widget's order: as linked, a stack's
  /// base first (ADR 0117).
  List<GitHubLink> get links => orderPulls(chat.pulls, itemOf);

  /// The pull request the tab shows: the one picked there (remembered for
  /// the chat), else the primary.
  GitHubLink? get current {
    final picked = pickedPulls.value[chat.id];
    if (picked != null) {
      for (final l in chat.pulls) {
        if (pullKey(l) == picked) return l;
      }
    }
    return chat.pull;
  }

  /// Shows [link] in the tab from now on; with [files] or [checks], at
  /// that section.
  void pick(GitHubLink link, {bool files = false, bool checks = false}) {
    if (files || checks) {
      openPullAt(link.asRef, files ? PullSection.files : PullSection.checks);
    }
    final was = current;
    if (was != null && pullKey(was) == pullKey(link)) return;
    pickedPulls.value = {...pickedPulls.value, chat.id: pullKey(link)};
    _forgetWhole();
    _seed();
    notifyListeners();
    unawaited(refresh());
  }

  /// Another pull request shows: nothing of the one before (its read,
  /// its time, its failure) is its.
  void _forgetWhole() {
    pull = null;
    keptAt = null;
    _wholeAt = null;
    failed = false;
  }

  /// [link]'s pull request as a row shows it (GetGitHubItems').
  GitHubItem? itemOf(GitHubLink link) =>
      GitHubItems.of(daemon).look(addressOf(link)).item;

  /// [link]'s new comments: those its row's item counts past what was
  /// seen ([unreadCount]).
  int unreadOf(GitHubLink link) => switch (itemOf(link)) {
    final it? => unreadCount(chat.id, it),
    null => 0,
  };

  /// [link]'s pull request whole, for Fix checks, Merge…, Clean up…: the
  /// tab's when it shows that one read current (on its timer; never the
  /// copy kept from before, [keptAt], which may be days old), else asked
  /// of GitHub now; null, said under [context], when it can't be.
  Future<GitHubPull?> whole(BuildContext context, GitHubLink link) async {
    final l = current;
    if (pull case final p?
        when _readsWhole &&
            keptAt == null &&
            l != null &&
            pullKey(l) == pullKey(link)) {
      return p;
    }
    try {
      final r = await daemon.client.getGitHubPull(
        GetGitHubPullRequest(ref: link.asRef),
      );
      return r.pull;
    } on Object catch (e) {
      if (context.mounted) showError(context, e);
      return null;
    }
  }

  /// Unlinks [link] from the chat: never found or opened again for it.
  Future<void> unlink(GitHubLink link) async {
    await daemon.client.linkChatPull(
      LinkChatPullRequest(chatId: chat.id, unlink: link),
    );
    chat.linkPull(
      chat.pull != null && pullKey(chat.pull!) == pullKey(link)
          ? chat.pulls.where((l) => pullKey(l) != pullKey(link)).firstOrNull
          : chat.pull,
      all: [
        for (final l in chat.pulls)
          if (pullKey(l) != pullKey(link)) l,
      ],
    );
    notifyListeners();
    await again();
  }

  /// When it was last looked for and how often, as the widget's tooltip
  /// says it: "Checked 20 s ago · every minute". Its rows' items are the
  /// chats' states' when those ask for them.
  String get checkedText {
    final states = PullStates.of(daemon);
    final rows = _statesAsk ? states.asked : null;
    final asked = [
      ?_asked,
      ?rows,
    ].fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    return checkedWords(asked, _statesAsk ? states.every : every, clock());
  }

  /// How long until the next ask on the timer: a minute, or 15 once every
  /// pull request of the chat is merged or closed; 5 at least while the
  /// window isn't in front (ADR 0140).
  Duration get every {
    final items = [for (final l in chat.pulls) itemOf(l)];
    final done =
        items.isNotEmpty && items.every((it) => itemPoll(it) == pullDonePoll);
    return polledEvery(
      _readsWhole && pull != null
          ? pullPoll(pull)
          : done
          ? pullDonePoll
          : pullWidgetPoll,
    );
  }

  /// The pull request is read whole while the tab shows it.
  bool get _readsWhole => _tabs > 0;

  /// Whether the chats' states ask for the rows' items each minute (from
  /// the daemon whose items say their checks' commit; ADR 0140): the
  /// timer then leaves them be.
  bool get _statesAsk =>
      daemon.daemonApi >= statesFromItemsApi && PullStates.of(daemon).watching;

  /// The Pull request tab shows the pull request: it's read whole from now
  /// on, at once unless read a moment ago.
  void showTab() {
    _tabs++;
    unawaited(_showWhole());
  }

  bool get _wholeFresh {
    final at = _wholeAt;
    return pull != null &&
        keptAt == null &&
        at != null &&
        clock().difference(at) < const Duration(seconds: 10);
  }

  /// The tab's pull request whole, read now unless a moment ago: after the
  /// ask under way, or alone when the rest was asked a moment ago.
  Future<void> _showWhole() async {
    if (_asking case final a?) await a;
    if (_wholeFresh || _tabs == 0) return;
    final asked = _asked;
    if (asked == null ||
        clock().difference(asked) >= const Duration(seconds: 10)) {
      await refresh();
      return;
    }
    _asking = () async {
      _started();
      try {
        await _readWhole(false);
      } on Object catch (e) {
        error = errorText(e);
        failed = true;
        _back.failed(e);
      }
    }();
    await _asking!.whenComplete(() {
      _asking = null;
      notifyListeners();
    });
  }

  /// The tab no longer shows it.
  void hideTab() {
    if (_tabs > 0) _tabs--;
    if (_tabs == 0) _schedule(); // the whole one's pace no longer applies
  }

  /// Follows the chat (its pane shows): asks now, on [pullWidgetPoll], after
  /// a tool call that pushed or opened a pull request, when a turn ends
  /// and when the window comes to the front.
  void follow() {
    if (_followers++ == 0) {
      _busy = chat.busy;
      _seen.addAll(chat.items.map((i) => i.id));
      _seenLive.addAll([
        for (final i in chat.items)
          if (i.status == 'completed') i.id,
      ]);
      chat.addListener(_chatChanged);
      // Back in front: what the slower timer away would have asked, if
      // it's due by the minute's pace (ADR 0140).
      _front = AppLifecycleListener(onResume: _resumed);
    }
    unawaited(refresh(again: false));
    if (_asking == null) _schedule(); // asked within 10 s: none now
  }

  void unfollow() {
    if (--_followers > 0) return;
    live.clear(); // the chat no longer shows
    _seenLive.clear();
    chat.removeListener(_chatChanged);
    _front?.dispose();
    _front = null;
    _soon?.cancel();
    _timer?.cancel();
    _shown?.cancel();
    _shown = null;
    _back.cancel();
  }

  void _resumed() {
    final asked = _asked;
    if (asked == null || clock().difference(asked) >= pullWidgetPoll) {
      unawaited(refresh(quiet: true, polled: true));
    } else {
      _schedule();
    }
  }

  // An ask the daemon was gone for, made again once it is back rather than
  // on the timer (a quarter of an hour for a merged pull request).
  late final _back = LoadAgain(daemon, () {
    if (_followers > 0) unawaited(refresh(quiet: true));
  });

  /// A turn ended, or a tool call pushed or opened a pull request: ask
  /// again in a moment (GitHub takes a moment to list a new one).
  void _chatChanged() {
    final ended = _busy && !chat.busy;
    _busy = chat.busy;
    var pushed = false;
    for (final it in chat.items.reversed.take(8)) {
      if (pushedOrOpened(it) && _seen.add(it.id)) pushed = true;
      if (it.kind == ItemKind.ITEM_KIND_TOOL_CALL &&
          it.status == 'completed' &&
          _seenLive.add(it.id)) {
        final knows = GitHubItems.of(daemon).knows;
        if (livePullOf(it, chat, knows) case final p?) {
          live[it.id] = p;
          notifyListeners();
        }
      }
    }
    if (ended || pushed) {
      _soon?.cancel();
      _soon = Timer(const Duration(seconds: 3), () => unawaited(refresh()));
    }
  }

  /// The next ask on the timer: [every] after the last.
  void _schedule() {
    _timer?.cancel();
    if (_followers == 0) return;
    final at = clock();
    final due = (_asked ?? at).add(every).difference(at);
    _timer = Timer(
      due.isNegative ? Duration.zero : due,
      () => unawaited(refresh(quiet: true, polled: true)),
    );
  }

  /// Asks the daemon for the chat's pull request (it looks on GitHub and
  /// links what it finds), its rows' items, then for the one the tab shows
  /// whole while it does; one ask at a time, and with [again] false none
  /// within 10 s of the last. [polled] (the timer's) asks only what nothing
  /// else does (ADR 0140).
  Future<void> refresh({
    bool quiet = false,
    bool again = true,
    bool polled = false,
  }) {
    final asked = _asked;
    if (_asking case final a?) return a;
    if (!again &&
        asked != null &&
        clock().difference(asked) < const Duration(seconds: 10)) {
      return Future.value();
    }
    _started();
    return _asking = _ask(quiet, polled: polled).whenComplete(() {
      _asking = null;
      _asked = clock();
      _schedule();
      notifyListeners();
    });
  }

  /// An ask starts: the tab says so ("· refreshing") once [asking] is
  /// set, after the frame when one is being built (an ask starts in a
  /// pane's initState, [follow]).
  void _started() => scheduleMicrotask(notifyListeners);

  /// Asks again after a change made here: an ask under way may have started
  /// before it, so another follows that one.
  Future<void> again() async {
    if (asking) await refresh();
    await refresh();
  }

  Future<void> _ask(bool quiet, {bool polled = false}) async {
    _back.cancel();
    // What failed before says nothing once this ask answers: an ask that
    // skips FindChatPull (the timer's, below) would leave it.
    error = null;
    try {
      // An archived chat finds nothing new (ADR 0059's amendment): its
      // rows are asked all the same. The timer looks for the branch's
      // pull request only while the chat has none open: a push from the
      // chat, a turn's end and the window to the front still look.
      final open = chat.pulls.any((l) => itemOf(l)?.state == 'open');
      if (!chat.archived && !(polled && open)) {
        final f = await daemon.client.findChatPull(
          FindChatPullRequest(chatId: chat.id, quiet: quiet),
        );
        found = f;
        chat.linkPull(f.hasPull() ? f.pull : null, all: f.pulls);
        error = f.error.isEmpty ? null : f.error;
      }
      await _rows(quiet, polled: polled);
      final l = current;
      if (l == null) {
        pull = null;
        keptAt = null;
      } else if (_readsWhole) {
        await _readWhole(quiet);
      }
      _seenFirst();
    } on Object catch (e) {
      error = errorText(e);
      // What the tab shows wasn't read again.
      if (_readsWhole) failed = true;
      _back.failed(e);
    }
  }

  /// Reads the tab's pull request whole.
  Future<void> _readWhole(bool quiet) async {
    final l = current;
    if (l == null) return;
    final ref = l.asRef;
    final r = await daemon.client.getGitHubPull(
      GetGitHubPullRequest(ref: ref, quiet: quiet),
    );
    pull = r.pull;
    keptAt = null;
    _wholeAt = clock();
    failed = false;
    keepPull(ref, r.pull);
    PullStates.of(daemon).put(r.pull);
    _recheck(r.pull);
    // The comments there when the chat first saw it aren't new.
    seenComments(chat.id, r.pull.item);
  }

  /// The rows' items, all in one call a host (GetGitHubItems); on the
  /// timer ([polled]) only those the chats' states don't ask for.
  Future<void> _rows(bool quiet, {bool polled = false}) async {
    if (chat.pulls.isEmpty) return;
    final skip = polled && _statesAsk;
    final ask = [
      for (final l in chat.pulls)
        if (!skip || l.id.isEmpty) addressOf(l),
    ];
    if (ask.isEmpty) return;
    await GitHubItems.of(daemon).ask(ask, quiet: quiet, chat: chat.id);
  }

  /// The comments the chat's pull requests have when it first knows them
  /// aren't new.
  void _seenFirst() {
    for (final l in chat.pulls) {
      if (GitHubItems.of(daemon).look(addressOf(l)).item case final it?) {
        seenComments(chat.id, it);
      }
    }
  }

  /// GitHub works out whether a pull request merges when it's asked, so
  /// "unknown" usually lasts seconds, not until the next minute's ask: asked
  /// again soon, three times at most in a row.
  void _recheck(GitHubPull p) {
    if (!p.merge.blocks.contains('unknown') || p.item.state != 'open') {
      _rechecks = 0;
    } else if (_followers > 0 && _rechecks < 3) {
      _rechecks++;
      _soon?.cancel();
      _soon = Timer(
        const Duration(seconds: 5),
        () => unawaited(refresh(quiet: true)),
      );
    }
  }

  /// Marks the pull request's comments seen: its Pull request tab shows
  /// them.
  void markSeen() {
    if (pull case final p?) seenComments(chat.id, p.item, always: true);
  }

  /// Adds [link] by hand after the chat's others (Link another pull
  /// request…, a chip's Link to this chat; ADR 0117).
  Future<void> addLink(GitHubLink link) async {
    await daemon.client.linkChatPull(
      LinkChatPullRequest(chatId: chat.id, pull: link, add: true),
    );
    await again();
  }

  /// Links [link] by hand, or unlinks (null).
  Future<void> setLink(GitHubLink? link) async {
    await daemon.client.linkChatPull(
      LinkChatPullRequest(chatId: chat.id, pull: link),
    );
    chat.linkPull(link);
    _forgetWhole();
    _seed();
    notifyListeners();
    await refresh();
  }
}
