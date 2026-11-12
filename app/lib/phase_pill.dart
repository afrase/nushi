import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

String _capital(String word) => word[0].toUpperCase() + word.substring(1);

/// A state's ink and the soft fill its pill has: a state that asks for
/// nothing (idle, asleep, new) is a quiet word on a card's fill.
(Color, Color) phasePill(ChatPhase p, Tokens t) => switch (p) {
  .waiting => (t.needs, t.needsSoft),
  .working || .background => (t.running, t.accentSoft),
  .failed => (t.crashed, t.crashedSoft),
  .done => (t.done, t.doneSoft),
  .expired ||
  .asleep ||
  .fresh ||
  .idle ||
  .archived => (t.textSecondary, t.raised),
};

/// A chat's state as a pill (ADR 0111): its word, capitalised, in the
/// state's ink on that ink's soft fill, [lead] (its dot) before it. In the
/// chat's header; [small], at the end of a sidebar row, where only a chat
/// that needs the user gets one.
class PhasePill extends StatelessWidget {
  const new(this.phase, {super.key, this.lead, this.small = false});

  final ChatPhase phase;
  final Widget? lead;
  final bool small;

  /// The header's pill's height.
  static const height = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final (ink, fill) = phasePill(phase, theme.t);
    return Container(
      height: small ? null : height,
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
          : EdgeInsets.only(left: lead == null ? 10 : 7, right: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(NushiTheme.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          ?lead,
          Text(
            _capital(phaseName(phase)),
            maxLines: 1,
            softWrap: false,
            style: theme.ui(
              ink,
              size: small ? 11 : 12,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
