import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
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

/// The chats' pull requests as lists show them (their state and checks):
/// asked of the daemon in one call (GetGitHubStates: one query a host, kept
/// 30 s there) while something watches, at once, each minute quietly, and
/// when a chat gets a pull request; a chat's card puts what it read too.
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

  /// Takes [it] as current (a card read the pull request whole).
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

/// A chat's pull request's checks as a dot, in the chat's row: red while
/// one fails, amber while some run; nothing otherwise.
class PullDot extends StatelessWidget {
  const new(this.chat, this.states, {super.key});

  final ChatState chat;
  final PullStates states;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: states,
    builder: (context, _) {
      final t = NushiTheme.of(context).t;
      final it = states.item(chat.pull);
      final (color, words) = switch (it?.checks) {
        'failure' || 'error' => (t.crashed, 'failing'),
        'pending' => (t.needs, 'running'),
        _ => (null, ''),
      };
      if (it == null || color == null) return const SizedBox.shrink();
      return Tooltip(
        message: '#${it.ref.number}: checks $words',
        child: Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
    },
  );
}

/// A chat's pull request on the phone, in its bar: its number in its
/// state's color and its checks' icon; a tap opens it on GitHub. It asks
/// while it shows.
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
      final checks = switch (it?.checks) {
        'success' => (Icons.check, t.done, 'checks passed'),
        'failure' || 'error' => (Icons.close, t.crashed, 'checks failing'),
        'pending' => (Icons.schedule, t.needs, 'checks running'),
        _ => null,
      };
      final words = [
        'Pull request #${l.number}',
        if (it != null) itemState(it),
        ?checks?.$3,
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
              child: Row(
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
                    Icon(checks.$1, size: 15, color: checks.$2),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
