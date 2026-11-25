import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';

import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/usage_rows.dart';
import 'package:nushi/widgets.dart';

/// How often today's spend is asked while the window shows: a turn's end
/// asks at once, so this only keeps it from going stale.
const _every = Duration(minutes: 1);

/// Today's spend, for the status card: what the turns that ended since
/// the Mac's midnight cost, as GetUsage sums it (ADR 0136). Null until
/// known, and while today cost nothing (no turn, or agents that report no
/// cost, as on a subscription) or the daemon is older than GetUsage.
/// Asked as it starts, as the window shows again, as any chat's turn ends
/// and each minute while the window shows; never while it's hidden. A
/// failed ask keeps the last answer and says nothing: Settings › Usage
/// shows why.
class TodaySpend extends ValueNotifier<Spent?> {
  new(this.daemon) : super(_last[daemon]) {
    _timer = Timer.periodic(_every, (_) => unawaited(_ask()));
    daemon.macView.windowShows.addListener(_shown);
    daemon.addListener(_follow);
    _follow();
    unawaited(_ask());
  }

  final Daemon daemon;

  /// The last answer, by daemon: the card goes and comes with the
  /// sidebar, and one that comes shows it while it asks again.
  static final _last = Expando<Spent>();

  late final Timer _timer;
  int _asks = 0; // which ask is the latest: an older answer is dropped
  final _busy = <String>{}; // the chats whose turn runs, to see one end
  Listenable? _chats;
  bool _gone = false;

  @override
  void dispose() {
    _gone = true;
    _timer.cancel();
    daemon.macView.windowShows.removeListener(_shown);
    daemon.removeListener(_follow);
    _chats?.removeListener(_turns);
    super.dispose();
  }

  /// The window back from hidden asks at once: the last answer may be
  /// hours old.
  void _shown() {
    if (daemon.macView.window) unawaited(_ask());
  }

  /// Follows the chats the daemon lists now, for their turns' ends.
  void _follow() {
    _chats?.removeListener(_turns);
    _chats = Listenable.merge([...daemon.chats.values])..addListener(_turns);
    _turns();
  }

  /// Asks again when a chat that was busy no longer is (or went).
  void _turns() {
    final ended = _busy.any((id) => daemon.chats[id]?.busy != true);
    _busy
      ..clear()
      ..addAll([
        for (final c in daemon.chats.values)
          if (c.busy) c.id,
      ]);
    if (ended) unawaited(_ask());
  }

  Future<void> _ask() async {
    if (!daemon.macView.window ||
        !daemon.connected ||
        daemon.daemonApi < usageApi) {
      return;
    }
    final ask = ++_asks;
    final now = clock();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final got = await daemon.client.getUsage(
        GetUsageRequest(from: Int64(midnight.millisecondsSinceEpoch)),
      );
      if (_gone || ask != _asks) return;
      final spent = Spent.of(got.totals);
      _last[daemon] = spent;
      value = spent;
    } on Object {
      // The last answer stays until the next.
    }
  }
}

/// A day's spend as the card shows it: the amount, as Settings › Usage
/// writes money, and the turns it took.
@immutable
final class Spent {
  const new(this.amount, this.turns);

  /// [t]'s spend in the currency most was spent in, or null when nothing
  /// reported a cost.
  static Spent? of(UsageTotals t) {
    final measure = UsageMeasure.mostSpent(t);
    if (!measure.costs) return null;
    return Spent(measure.write(measure.of(t)), t.turns.toInt());
  }

  /// "$12.40".
  final String amount;
  final int turns;

  @override
  bool operator ==(Object other) =>
      other is Spent && other.amount == amount && other.turns == turns;

  @override
  int get hashCode => Object.hash(amount, turns);
}

/// The card's spend: the amount and "today"; a press opens Settings ›
/// Usage.
class SpendButton extends StatelessWidget {
  const new(this.spent, this.daemon, {required this.style, super.key});

  final Spent spent;
  final Daemon daemon;

  /// Its figure's style: the card's small, muted, tabular text.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final turns = spent.turns;
    return Tap(
      key: const ValueKey('status-spend'),
      onTap: () => daemon.openSettings(section: .usage),
      tooltip: 'Spent today, $turns turn${turns == 1 ? '' : 's'}',
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text('${spent.amount} today', style: style, maxLines: 1),
    );
  }
}
