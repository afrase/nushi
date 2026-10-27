import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/theme/theme.dart';

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

/// A group of rows in a rounded box, an optional [title] over it and a
/// [footer] under it; a hairline between rows.
class SettingsGroup extends StatelessWidget {
  const new({required this.children, super.key, this.title, this.footer});

  final String? title;
  final Widget? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title case final title?)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 7),
              child: Text(
                title,
                style: theme.ui(
                  t.textSecondary,
                  size: 12,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          framed(
            border: t.borderSubtle,
            fill: t.raised,
            radius: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
              child: DefaultTextStyle(
                style: theme.ui(t.textMuted, size: 12),
                child: f,
              ),
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

/// A switch, Settings' size everywhere.
class SettingsSwitch extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: FittedBox(
      child: Switch(value: value, onChanged: onChanged),
    ),
  );
}
