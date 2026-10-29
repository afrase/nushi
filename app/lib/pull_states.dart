import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pull_summary.dart';
import 'package:nushi/theme/theme.dart';

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
/// asked of the daemon in one call (GetGitHubStates: one query a host, kept
/// 30 s there) while something watches, at once, each minute quietly, and
/// when a chat gets a pull request; a chat's widget puts what it read too.
class PullStates extends ChangeNotifier {
  /// The one of [daemon].
  factory of(Daemon daemon) => _all[daemon] ??= PullStates._(daemon);

  new _(this.daemon);

  static final _all = Expando<PullStates>();

  final Daemon daemon;
  final _items = <String, GitHubItem>{}; // by node id
  int _watchers = 0;
  Timer? _timer;
  Timer? _soon;
  Set<String> _asked = const {};

  /// [link]'s pull request as last known.
  GitHubItem? item(GitHubLink? link) => link == null ? null : _items[link.id];

  /// Takes [it] as current (a widget read the pull request whole).
  void put(GitHubItem it) {
    if (_items[it.id] == it) return;
    _items[it.id] = it;
    notifyListeners();
  }

  void watch() {
    if (_watchers++ > 0) return;
    daemon.addListener(_chatsChanged);
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(refresh(quiet: true)),
    );
    unawaited(refresh());
  }

  void unwatch() {
    if (--_watchers > 0) return;
    daemon.removeListener(_chatsChanged);
    _timer?.cancel();
    _soon?.cancel();
  }

  Iterable<GitHubLink> get _links => [
    for (final ChatState c in daemon.chats.values)
      if (c.pull case final l? when !c.archived) l,
  ];

  /// A chat got a pull request (or lost one): ask in a moment.
  void _chatsChanged() {
    final ids = {for (final l in _links) l.id};
    if (ids.difference(_asked).isEmpty) return;
    _soon?.cancel();
    _soon = Timer(const Duration(seconds: 1), () => unawaited(refresh()));
  }

  Future<void> refresh({bool quiet = false}) async {
    final links = _links.toList();
    _asked = {for (final l in links) l.id};
    if (links.isEmpty) return;
    try {
      final r = await daemon.client.getGitHubStates(
        GetGitHubStatesRequest(items: links, quiet: quiet),
      );
      for (final it in r.items) {
        _items[it.id] = it;
      }
      notifyListeners();
    } on Object {
      // The last known states stay.
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

  static const passedFor = Duration(milliseconds: 4300);
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
    _checks = widget.states.item(widget.chat.pull)?.checks;
  }

  @override
  void dispose() {
    widget.states.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final now = widget.states.item(widget.chat.pull)?.checks;
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
    final it = widget.states.item(widget.chat.pull);
    final passed = it?.checks == 'success' && running;
    final (color, words) = switch (it?.checks) {
      'failure' || 'error' => (t.crashed, 'failing'),
      'pending' => (t.needs, 'running'),
      'success' when passed => (t.done, 'passed'),
      _ => (null, ''),
    };
    if (it == null || color == null) return const SizedBox.shrink();
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
    return Tooltip(
      message: '#${it.ref.number}: checks $words',
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Transform.translate(
          offset: Offset(0, -hop),
          child: CustomPaint(
            size: const Size.square(PullDot.size),
            painter: ChecksMark(
              color.withValues(alpha: color.a * fade),
              ringing: it.checks == 'pending' && !still,
              scale: pop,
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
  new(this.color, {required this.ringing, this.scale = 1})
    : super(repaint: ringing ? loopRepaint : null);

  final Color color;
  final bool ringing;
  final double scale;

  static const period = Duration(milliseconds: 1600);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (ringing) {
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
/// failing or running checks, changes requested or a reviewer waited on,
/// open threads; or Ready, Draft, Merged, Closed), from the pull request
/// whole, asked at once and each minute (quietly) while it shows; until
/// then its number and checks' icon from the chats' states. A tap opens
/// it on GitHub.
class PullChip extends StatefulWidget {
  const new(this.daemon, this.chat, {required this.onOpen, super.key});

  final Daemon daemon;
  final ChatState chat;

  /// Opens the pull request's page (its link, http or https).
  final ValueChanged<String> onOpen;

  @override
  State<PullChip> createState() => _PullChipState();
}

class _PullChipState extends State<PullChip> {
  late final PullStates _states;
  GitHubPull? _pull;
  String? _asked; // the link last asked for
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _states = PullStates.of(widget.daemon)..watch();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_ask(quiet: true)),
    );
    widget.chat.addListener(_chatChanged);
    unawaited(_ask());
  }

  @override
  void dispose() {
    widget.chat.removeListener(_chatChanged);
    _timer?.cancel();
    _states.unwatch();
    super.dispose();
  }

  /// The chat's link changed: the pull request it names is asked for.
  void _chatChanged() {
    if (widget.chat.pull?.id == _asked) return;
    setState(() => _pull = null);
    unawaited(_ask());
  }

  /// Asks for the linked pull request whole.
  Future<void> _ask({bool quiet = false}) async {
    final l = widget.chat.pull;
    _asked = l?.id;
    if (l == null) return;
    try {
      final r = await widget.daemon.client.getGitHubPull(
        GetGitHubPullRequest(
          ref: GitHubRef(host: l.host, repo: l.repo, number: l.number),
          quiet: quiet,
        ),
      );
      if (mounted && widget.chat.pull?.id == l.id) {
        setState(() => _pull = r.pull);
        _states.put(r.pull.item);
      }
    } on Object {
      // What shows stays: the states' summary.
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _states,
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final l = widget.chat.pull;
      if (l == null) return const SizedBox.shrink();
      final p = _pull?.item.id == l.id ? _pull : null;
      final it = p?.item ?? _states.item(l);
      final checks = it == null ? null : checksIcon(t, it.checks);
      final open = p?.threads.where((x) => !x.resolved).length ?? 0;
      final words = [
        'Pull request #${l.number}',
        if (it != null) itemState(it),
        ?checks?.words.toLowerCase(),
        if (open > 0) '$open open thread${open == 1 ? '' : 's'}',
      ].join(', ');
      return Semantics(
        button: true,
        label: words,
        excludeSemantics: true,
        child: InkResponse(
          onTap: it == null || it.url.isEmpty
              ? null
              : () => widget.onOpen(it.url),
          radius: 22,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: p != null
                  ? Center(
                      widthFactor: 1,
                      child: pullSummary(
                        theme,
                        number: l.number,
                        pull: p,
                        size: 13,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 3,
                      children: [
                        Text(
                          '#${l.number}',
                          style: theme.code(
                            it == null ? t.link : itemColor(t, it),
                            size: 14,
                          ),
                        ),
                        if (checks != null)
                          Icon(checks.icon, size: 15, color: checks.color),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
}
