import 'package:flutter/material.dart';
import 'package:nushi/github_text.dart';
import 'package:nushi/theme/theme.dart';

/// The Pull request tab before its pull request was ever read: its head
/// (a pill, the title, the branches), the four lights and To do's rows as
/// bars in the tab's column, so the page's shape is there at once.
class PullSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t.borderSubtle,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    Widget box(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: t.borderSubtle),
        borderRadius: BorderRadius.circular(NushiTheme.control + 2),
      ),
      child: child,
    );
    return Semantics(
      label: 'Loading the pull request',
      child: LayoutBuilder(
        builder: (context, size) => ListView(
          padding: EdgeInsets.fromLTRB(
            readablePad(size.maxWidth),
            16,
            readablePad(size.maxWidth),
            16,
          ),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Row(spacing: 8, children: [bar(52, 18), bar(110, 12)]),
            const SizedBox(height: 12),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.6,
              child: bar(double.infinity, 18),
            ),
            const SizedBox(height: 10),
            Row(
              spacing: 8,
              children: [bar(140, 14), bar(40, 14), bar(120, 12)],
            ),
            const SizedBox(height: 22),
            Row(
              spacing: 8,
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: box(
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 7,
                          children: [bar(44, 9), bar(80, 12), bar(96, 9)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            box(
              Column(
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      decoration: i == 0
                          ? null
                          : BoxDecoration(
                              border: Border(
                                top: BorderSide(color: t.borderSubtle),
                              ),
                            ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        spacing: 10,
                        children: [
                          bar(16, 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 6,
                              children: [
                                FractionallySizedBox(
                                  widthFactor: const [0.4, 0.55, 0.35, 0.5][i],
                                  child: bar(double.infinity, 11),
                                ),
                                FractionallySizedBox(
                                  widthFactor: const [0.8, 0.65, 0.75, 0.6][i],
                                  child: bar(double.infinity, 9),
                                ),
                              ],
                            ),
                          ),
                          bar(56, 22),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
