import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// Settings' parts, as macOS System Settings lays them out: a section's
// title, then rounded groups of rows, each row its label (and a muted
// line under it) on the left and its control on the right, at the
// group's edge.

/// A section of Settings: [title] (with [actions] at the end of its line)
/// and [children], then any [slivers] (a long list built lazily), in a
/// column at most [maxWidth] wide, [gutter] from the nav (left-aligned:
/// centered, a wide window put the content far from the nav it belongs
/// to); [bottom] stays under it all, outside the scroll.
class SettingsPage extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.actions = const [],
    this.children = const [],
    this.slivers = const [],
    this.bottom,
    this.controller,
  });

  /// The content's widest.
  static const maxWidth = 720.0;

  /// The space between the nav and the content, and at least this on the
  /// right.
  static const gutter = 32.0;

  final String title;
  final List<Widget> actions;
  final List<Widget> children;
  final List<Widget> slivers;
  final Widget? bottom;
  final ScrollController? controller;

  /// The right padding that keeps the column at most [maxWidth] wide in
  /// [width].
  static double right(double width) => max(gutter, width - gutter - maxWidth);

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return LayoutBuilder(
      builder: (context, box) {
        final pad = EdgeInsets.only(left: gutter, right: right(box.maxWidth));
        final name = Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.ui(t.text, size: 20, weight: FontWeight.w600),
        );
        // Narrow, the actions go under the title rather than cut it.
        final narrow =
            box.maxWidth - gutter - right(box.maxWidth) < 520 &&
            actions.isNotEmpty;
        final heading = Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    SizedBox(height: 30, child: name),
                    Row(spacing: 8, children: actions),
                  ],
                )
              : SizedBox(
                  height: 30,
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(child: name),
                      ...actions,
                    ],
                  ),
                ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  SliverPadding(
                    padding: pad.copyWith(top: 22),
                    sliver: SliverList.list(children: [heading, ...children]),
                  ),
                  for (final s in slivers)
                    SliverPadding(padding: pad, sliver: s),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
            if (bottom case final b?) Padding(padding: pad, child: b),
          ],
        );
      },
    );
  }
}

/// A group of rows in a rounded box, an optional [title] over it (and
/// [about], what the group holds, under the title) and a [footer] under it;
/// a hairline between rows, and [empty] ("None") in the box without any.
class SettingsGroup extends StatelessWidget {
  const new({
    required this.children,
    super.key,
    this.title,
    this.about,
    this.footer,
    this.empty,
  });

  final String? title;
  final String? about;
  final Widget? footer;
  final String? empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || about != null)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title case final title?)
                    Text(
                      title,
                      style: theme.ui(
                        t.textSecondary,
                        size: 12,
                        weight: FontWeight.w600,
                      ),
                    ),
                  if (about case final about?) Text(about, style: muted),
                ],
              ),
            ),
          framed(
            border: t.borderSubtle,
            fill: t.raised,
            radius: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (children.isEmpty && empty != null)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(empty!, style: muted),
                  ),
                for (final (i, c) in children.indexed) ...[
                  if (i > 0) Container(height: 1, color: t.borderSubtle),
                  c,
                ],
              ],
            ),
          ),
          if (footer case final f?)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 7),
              child: DefaultTextStyle(style: muted, child: f),
            ),
        ],
      ),
    );
  }
}

/// A row's height at least.
const settingsRowHeight = 46.0;

/// A row of a [SettingsGroup]: [label] and its [description] on the left,
/// [control] on the right, at the group's edge.
class SettingsRow extends StatelessWidget {
  const new(
    this.label, {
    super.key,
    this.description,
    this.control,
    this.descriptionColor,
  });

  final String label;
  final String? description;
  final Widget? control;
  final Color? descriptionColor;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: settingsRowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.ui(t.text)),
                  if (description case final d? when d.isNotEmpty)
                    Text(
                      d,
                      style: theme.ui(
                        descriptionColor ?? t.textMuted,
                        size: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (control case final c?) ...[const SizedBox(width: 16), c],
          ],
        ),
      ),
    );
  }
}

/// A switch, Settings' size everywhere. [onChanged] takes a change; or
/// [run] makes it as a call, the switch off while it runs (a double click
/// sends once) and its error shown, as a [RunButton]. Off with neither.
class SettingsSwitch extends StatefulWidget {
  const new({required this.value, super.key, this.onChanged, this.run});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Future<void> Function({required bool on})? run;

  @override
  State<SettingsSwitch> createState() => _SettingsSwitchState();
}

class _SettingsSwitchState extends State<SettingsSwitch> {
  final _runner = Runner();

  @override
  void dispose() {
    _runner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _runner,
    builder: (context, running, _) => SizedBox(
      height: 20,
      child: FittedBox(
        child: Switch(
          value: widget.value,
          onChanged: switch (widget.run) {
            null => widget.onChanged,
            _ when running => null,
            final run => (on) => _runner.run(context, () => run(on: on)),
          },
        ),
      ),
    ),
  );
}
