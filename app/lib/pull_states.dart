import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_summary.dart';
import 'package:nushi/theme/theme.dart';

/// A chat's GitHub link as the ref GitHub's calls take.
extension GitHubLinkRef on GitHubLink {
  /// The pull request or issue it links.
  GitHubRef get asRef => GitHubRef(host: host, repo: repo, number: number);
}

/// An item's state's color: open green (gray when a draft), merged
/// violet, closed red.
Color itemColor(Tokens t, GitHubItem it) => switch (it.state) {
  'merged' => t.subagentAccent,
  'closed' => t.crashed,
  _ => it.draft ? t.textMuted : t.done,
};

/// An item's state as a word: "Open", "Draft", "Merged", "Closed".
String itemState(GitHubItem it) => switch (it.state) {
  'merged' => 'Merged',
  'closed' => 'Closed',
  _ => it.draft ? 'Draft' : 'Open',
};

/// A checks' state (an item's `checks`) as an icon, its color and its
/// words; null with no checks.
({IconData icon, Color color, String words})? checksIcon(
  Tokens t,
  String state,
) => switch (state) {
  'success' => (icon: Icons.check, color: t.done, words: 'Checks passed'),
  'failure' ||
  'error' => (icon: Icons.close, color: t.crashed, words: 'Checks failing'),
  'pending' => (icon: Icons.schedule, color: t.needs, words: 'Checks running'),
  _ => null,
};

/// The chats' pull requests as lists show them (their state and checks):
/// asked of the daemon in one call while something watches, at once, when
/// a chat gets a pull request, and on a timer quietly ([every]: each
/// minute, every 15 once all are merged or closed, every 5 at least while
/// the window isn't in front; ADR 0140). From API 133 that call is the
/// rows' items (GetGitHubItems: one query a host for every chat, whose
/// rows then need no ask of their own; the chats' linked issues ride on
/// it, for the header's chip), before it GetGitHubStates (one query a
/// host, kept 30 s there, its answers put over the rows there); a chat's
/// widget puts what it read whole. What it knows is GitHubItems' (one
/// store of the rows): it tells its listeners only when one of the chats'
/// pull requests changed there. Archived chats and chats without a pull
/// request aren't asked for.
class PullStates extends ChangeNotifier {
  /// The one of [daemon].
  factory of(Daemon daemon) => _all[daemon] ??= PullStates._(daemon);

  new _(this.daemon) : _items = GitHubItems.of(daemon) {
    _items.addListener(_itemsChanged);
  }

  static final _all = Expando<PullStates>();

  final Daemon daemon;
  final GitHubItems _items;

  /// The chats' pull requests as last told, by node id: what tells a
  /// change of theirs from GitHubItems' others (an asking flip, a chip's
  /// item).
  Map<String, GitHubItem?> _told = const {};
  int _watchers = 0;
  Timer? _timer;
  Timer? _soon;
  AppLifecycleListener? _front;
  Set<String> _asked = const {};

  /// When they were last asked for; null before.
  DateTime? asked;

  /// Whether something watches: they're asked on the timer.
  bool get watching => _watchers > 0;

  /// How long until the next ask: a minute; 15 once every one known is
  /// merged or closed; 5 at least while the window isn't in front.
  Duration get every {
    final known = [for (final l in _links) item(l)];
    final done =
        known.isNotEmpty &&
        known.every((it) => it != null && itemPoll(it) == pullDonePoll);
    return polledEvery(done ? pullDonePoll : pullWidgetPoll);
  }

  /// [link]'s pull request as last known (GitHubItems').
  GitHubItem? item(GitHubLink? link) =>
      link == null ? null : _items.look(addressOf(link)).item;

  /// The worst checks of [chat]'s open pull requests (ADR 0117): failing,
  /// then running, then passed; its primary's when none is open.
  String? checksOf(ChatState chat) {
    int rank(String? c) => switch (c) {
      'failure' || 'error' => 3,
      'pending' => 2,
      'success' => 1,
      _ => 0,
    };
    String? worst;
    for (final l in chat.pulls) {
      final it = item(l);
      if (l.id.isEmpty || it == null || it.state != 'open') continue;
      if (rank(it.checks) > rank(worst)) worst = it.checks;
    }
    return worst ?? item(chat.pull)?.checks;
  }

  /// Takes [whole] (a pull request read whole, whose item lacks what only
  /// a row says: its checks' counts, merge state, size, branches) as
  /// current in GitHubItems, over the row kept there; the counts go when
  /// its checks changed, until the next row says them.
  void put(GitHubItem whole) => _take(whole);

  /// Takes [said] (a whole read's item, or an older daemon's state) over
  /// the row GitHubItems keeps of it: what both say from [said], what only
  /// a row says (merge state, size, branches, when made) kept, and its
  /// checks' counts while its checks are the same. Its title on one line,
  /// as a row's is, so the two don't take turns.
  void _take(GitHubItem said) {
    final title = said.title.trim().split(_spaces).join(' ');
    final kept = _items.look(GitHubAddress.of(said.ref, pull: true)).item;
    if (kept == null) return _items.put(said.deepCopy()..title = title);
    final it = kept.deepCopy()
      ..title = title
      ..url = said.url
      ..state = said.state
      ..draft = said.draft
      ..author = said.author
      ..updatedMs = said.updatedMs
      ..review = said.review
      ..unresolved = said.unresolved
      ..comments = said.comments;
    if (said.checks != kept.checks || said.checksOid != kept.checksOid) {
      it
        ..checks = said.checks
        ..checksOid = said.checksOid
        ..clearCheckCounts();
    }
    if (it != kept) _items.put(it);
  }

  static final _spaces = RegExp(r'\s+');

  /// GitHubItems changed: told on only if one of the chats' pull requests
  /// did.
  void _itemsChanged() {
    final now = {for (final l in _links) l.id: item(l)};
    if (mapEquals(now, _told)) return;
    _told = now;
    notifyListeners();
  }

  void watch() {
    if (_watchers++ > 0) return;
    daemon.addListener(_chatsChanged);
    _front = AppLifecycleListener(onResume: _resumed);
    unawaited(refresh());
  }

  void unwatch() {
    if (--_watchers > 0) return;
    daemon.removeListener(_chatsChanged);
    _front?.dispose();
    _front = null;
    _timer?.cancel();
    _soon?.cancel();
  }

  /// The next ask: [every] after the last.
  void _schedule() {
    _timer?.cancel();
    if (_watchers == 0) return;
    final now = clock();
    final due = (asked ?? now).add(every).difference(now);
    _timer = Timer(
      due.isNegative ? Duration.zero : due,
      () => unawaited(refresh(quiet: true)),
    );
  }

  /// Back in front: asked now if the minute's pace says it's due, else
  /// on that pace again.
  void _resumed() {
    final at = asked;
    if (at == null || clock().difference(at) >= pullWidgetPoll) {
      unawaited(refresh(quiet: true));
    } else {
      _schedule();
    }
  }

  Iterable<GitHubLink> get _links => [
    for (final ChatState c in daemon.chats.values)
      if (!c.archived)
        for (final l in c.pulls)
          if (l.id.isNotEmpty) l,
  ];

  /// The chats' linked issues (a chat started from one), not archived.
  Iterable<GitHubLink> get _issues => [
    for (final ChatState c in daemon.chats.values)
      if (!c.archived)
        if (c.github case final l? when !l.pull) l,
  ];

  /// A chat got a pull request (or lost one): ask in a moment.
  void _chatsChanged() {
    final ids = {for (final l in _links) l.id};
    if (ids.difference(_asked).isEmpty) return;
    _soon?.cancel();
    _soon = Timer(const Duration(seconds: 1), () => unawaited(refresh()));
  }

  Future<void> refresh({bool quiet = false}) async {
    _timer?.cancel();
    final links = _links.toList();
    _asked = {for (final l in links) l.id};
    if (links.isEmpty) return; // asked again once a chat gets one
    try {
      if (daemon.daemonApi >= statesFromItemsApi) {
        // The chats' issues ride on it too (their header chip, ADR 0117):
        // the same query a host, no poll of their own.
        await _items.ask([
          for (final l in links) addressOf(l),
          ..._issues.map(addressOf),
        ], quiet: quiet);
      } else {
        final r = await daemon.client.getGitHubStates(
          GetGitHubStatesRequest(items: links, quiet: quiet),
        );
        // By node id: each its link's pull request, as GitHubItems keeps
        // it.
        for (final it in r.items) {
          final l = links.where((l) => l.id == it.id).firstOrNull;
          if (l == null) continue;
          if (!it.hasRef()) it.ref = l.asRef;
          _take(it..pull = true); // over the row ChatPull asked for
        }
      }
      _seenFirst();
    } on Object {
      // The last known states stay.
    } finally {
      asked = clock();
      _schedule();
    }
  }

  /// The comments each chat's pull requests have when first known aren't
  /// new to it (the PR widget's count, ADR 0140).
  void _seenFirst() {
    for (final c in daemon.chats.values) {
      if (c.archived) continue;
      for (final l in c.pulls) {
        if (item(l) case final it?) seenComments(c.id, it);
      }
    }
  }
}

/// A chat's pull request's checks as a dot, in the chat's row: amber with
/// the working ring growing out of it while they run (the ring and the dot
/// drawn from one centre), red while one fails; nothing otherwise. Seen
/// to change: passing, it turns green, pops and stays 4 s before fading,
/// so success is seen rather than just gone; failing, it pops red and hops
/// once. With Reduce Motion only the colors change (green still goes after
/// 4 s).
class PullDot extends StatefulWidget {
  const new(this.chat, this.states, {super.key});

  final ChatState chat;
  final PullStates states;

  /// The dot's width, as the row lays it out (the ring paints past it).
  static const size = 6.0;

  // design: how long a state shows, not motion
  static const passedFor = Duration(milliseconds: 4300);
  // design: how long a state shows, not motion
  static const failedFor = Duration(milliseconds: 1600);

  @override
  State<PullDot> createState() => _PullDotState();
}

class _PullDotState extends State<PullDot> with ClockRun {
  String? _checks; // as last shown

  @override
  void initState() {
    super.initState();
    widget.states.addListener(_changed);
    _checks = widget.states.checksOf(widget.chat);
  }

  @override
  void dispose() {
    widget.states.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final now = widget.states.checksOf(widget.chat);
    if (now == _checks) return;
    final was = _checks;
    _checks = now;
    final failing = now == 'failure' || now == 'error';
    if (now == 'success' && was != null) {
      // Green, seen: with Reduce Motion too, without the pop.
      runFor(PullDot.passedFor);
    } else if (failing && was != 'failure' && was != 'error') {
      if (reduceMotion(context)) {
        stopRun();
      } else {
        runFor(PullDot.failedFor);
      }
    } else {
      stopRun();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final checks = widget.states.checksOf(widget.chat);
    final passed = checks == 'success' && running;
    final (color, words) = switch (checks) {
      'failure' || 'error' => (t.crashed, 'failing'),
      'pending' => (t.needs, 'running'),
      'success' when passed => (t.done, 'passed'),
      _ => (null, ''),
    };
    if (checks == null || color == null) return const SizedBox.shrink();
    final still = reduceMotion(context);
    final ms = running ? ranMs : double.infinity;
    // Scale 1 → 1.6 (at 30%) → 1 over 400 ms; then, failing, a hop.
    final pop = still || ms > 400
        ? 1.0
        : ms < 120
        ? 1 + 0.6 * Curves.easeOut.transform(ms / 120)
        : 1 + 0.6 * (1 - Curves.easeOut.transform((ms - 120) / 280));
    final hop = still || !running || passed
        ? 0.0
        : hopHeight((ms - 400) / 1200);
    final fade = passed ? 1 - part(ms, 4000, 300) : 1.0;
    return tooltip(
      context,
      widget.chat.pulls.length > 1
          ? 'Pull requests: checks $words'
          : '#${widget.chat.pull?.number}: checks $words',
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Transform.translate(
          offset: Offset(0, -hop),
          child: CustomPaint(
            size: const Size.square(PullDot.size),
            painter: ChecksMark(
              color.withValues(alpha: color.a * fade),
              ringing: checks == 'pending' && !still,
              scale: pop,
              repaint: loopRepaintOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// A PR's checks' dot of [color], [scale]d; [ringing], the working ring
/// grows out of it and fades every 1.6 s on the shared clock
/// ([loopPhase]). The dot and the ring are drawn from the same centre, the
/// box's.
class ChecksMark extends CustomPainter {
  new(this.color, {required this.ringing, this.scale = 1, Listenable? repaint})
    : super(repaint: ringing ? repaint : null);

  final Color color;
  final bool ringing;
  final double scale;

  // design: a loop's beat, on pulseClock
  static const period = Duration(milliseconds: 1600);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (ringing && loopMoving) {
      final v = Curves.easeOut.transform(loopPhase(period));
      canvas.drawCircle(
        c,
        r * (1 + 1.6 * v),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.7 * (1 - v)),
      );
    }
    canvas.drawCircle(c, r * scale, Paint()..color = color);
  }

  @override
  bool shouldRepaint(ChecksMark old) =>
      old.color != color || old.ringing != ringing || old.scale != scale;
}

/// A chat's pull request on the phone, in its bar: the PR widget's
/// one-line summary (`pullSummary`: its number in its state's color, then
/// failing or running checks, changes requested or a review still
/// required, threads not resolved; or Ready, Draft, Merged, Closed), from
/// its row's item as the chats' states have it (GitHubItems; ADR 0140:
/// no read of its own); its number alone until then. A tap opens it on
/// GitHub; with several (ADR 0117) it says `+2` for the others and a tap
/// shows them all ([onMore]).
class PullChip extends StatefulWidget {
  const new(
    this.daemon,
    this.chat, {
    required this.onOpen,
    super.key,
    this.onMore,
  });

  /// Shows the chat's pull requests, when it has several.
  final VoidCallback? onMore;

  final Daemon daemon;
  final ChatState chat;

  /// Opens the pull request's page (its link, http or https).
  final ValueChanged<String> onOpen;

  @override
  State<PullChip> createState() => _PullChipState();
}

class _PullChipState extends State<PullChip> {
  late final PullStates _states;

  @override
  void initState() {
    super.initState();
    _states = PullStates.of(widget.daemon)..watch();
  }

  @override
  void dispose() {
    _states.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _states,
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final l = widget.chat.pull;
      if (l == null) return const SizedBox.shrink();
      final it = _states.item(l);
      final checks = it == null ? null : checksIcon(t, it.checks);
      final open = it?.unresolved ?? 0;
      final more = widget.chat.pulls.length - 1;
      final words = [
        'Pull request #${l.number}',
        if (more > 0) 'and $more more',
        if (it != null) itemState(it),
        ?checks?.words.toLowerCase(),
        if (open > 0) '$open open thread${open == 1 ? '' : 's'}',
      ].join(', ');
      return Semantics(
        button: true,
        label: words,
        excludeSemantics: true,
        child: InkResponse(
          onTap: more > 0 && widget.onMore != null
              ? widget.onMore
              : it == null || it.url.isEmpty
              ? null
              : () => widget.onOpen(it.url),
          radius: 22, // not a corner: its splash's reach
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                widthFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    pullSummary(
                      context,
                      theme,
                      number: l.number,
                      pull: null,
                      item: it,
                      size: 13,
                    ),
                    if (more > 0)
                      Text('+$more', style: theme.code(t.textMuted)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
