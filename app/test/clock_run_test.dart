import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/motion.dart';

// ClockRun: a motion that runs once, on its State's own ticker.

/// Runs for 200 ms as it's first built, counting its builds and saying
/// how far its run has gone.
class _Run extends StatefulWidget {
  const new(this.builds);

  final List<double> builds;

  @override
  State<_Run> createState() => _RunState();
}

class _RunState extends State<_Run>
    with SingleTickerProviderStateMixin, ClockRun {
  @override
  void initState() {
    super.initState();
    runFor(const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    widget.builds.add(ranMs);
    return const SizedBox();
  }
}

Widget _app(List<double> builds, {required bool shown}) => Directionality(
  textDirection: TextDirection.ltr,
  child: TickerMode(enabled: shown, child: _Run(builds)),
);

void main() {
  testWidgets('a run rebuilds every frame from zero to its length, then '
      'stops', (tester) async {
    final builds = <double>[];
    await tester.pumpWidget(_app(builds, shown: true));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(builds.first, 0);
    expect(builds.skip(1).first, 0, reason: 'its first tick is its start');
    expect(builds[2], 20);
    expect(builds.last, 200);
    final count = builds.length;
    await tester.pump(const Duration(milliseconds: 20));
    expect(builds, hasLength(count), reason: 'nothing ticks at rest');
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('hidden (tickers off) a run stands still, and shown again it '
      'goes on from where its time is, as a ticker does', (tester) async {
    final builds = <double>[];
    await tester.pumpWidget(_app(builds, shown: true));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    expect(builds.last, 20);
    await tester.pumpWidget(_app(builds, shown: false));
    final hidden = builds.length;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(builds, hasLength(hidden), reason: 'no frame while hidden');
    await tester.pumpWidget(_app(builds, shown: true));
    await tester.pump(const Duration(milliseconds: 20));
    // Its time went on while hidden: 20, then 120 more, then this frame.
    expect(builds.last, greaterThan(120));
    await tester.pump(const Duration(milliseconds: 60));
    expect(builds.last, 200, reason: 'ended');
  });
}
