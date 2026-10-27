import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/phone/link.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/theme/theme.dart';
import 'package:remote_transport/remote_transport.dart' show Unreachable;

/// How the link to the Mac stands, while it's down: a quiet
/// "Reconnecting…" at first; after two failed tries, why it can't reach
/// the Mac and when it was last seen, with Try again (a spinner, then the
/// result). It keeps trying on its own meanwhile; the raw error is in
/// Details.
class ConnectionBar extends StatelessWidget {
  const new(this.phone, {super.key});

  final Phone phone;

  @override
  Widget build(BuildContext context) {
    final link = phone.link;
    final daemon = phone.daemon;
    if (link == null || daemon == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([link, daemon]),
      builder: (context, _) {
        if (daemon.connected) return const SizedBox.shrink();
        final t = NushiTheme.of(context).t;
        final down = link.failures >= 2;
        final small = phoneText(context, size: 14);
        final muted = phoneText(context, size: 13, color: t.textSecondary);
        return Semantics(
          liveRegion: true,
          child: ColoredBox(
            color: down ? t.crashedSoft : t.raised,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: !down
                  ? Row(
                      children: [
                        const PhoneSpinner(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            link.answered ? 'Reconnecting…' : 'Connecting…',
                            style: small,
                          ),
                        ),
                        const SizedBox(height: touch),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                link.asked && !link.trying
                                    ? "Still can't reach your Mac"
                                    : "Can't reach your Mac",
                                style: small.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                [
                                  reason(link.why),
                                  if (link.seen case final s?) seenAt(s),
                                ].join(' · '),
                                style: muted,
                              ),
                            ],
                          ),
                        ),
                        if (link.trying)
                          const SizedBox(
                            width: touch * 2,
                            height: touch,
                            child: Center(child: PhoneSpinner()),
                          )
                        else
                          TextButton(
                            onPressed: () => unawaited(link.check(user: true)),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(touch, touch),
                            ),
                            child: Text(
                              'Try again',
                              style: phoneText(
                                context,
                                color: t.link,
                                size: 14,
                              ),
                            ),
                          ),
                        PhoneIcon(
                          Icons.info_outline,
                          label: 'Details',
                          onTap: () => _details(context, link),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  static void _details(BuildContext context, Link link) => unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection'),
        content: SelectableText(
          [
            'Tries that failed: ${link.failures}',
            if (link.next case final n?)
              'Next try: in ${n.difference(DateTime.now()).inSeconds} s',
            if (link.error case final e?) '$e',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

/// Why the Mac can't be reached, in a few words.
String reason(Unreachable? why) => switch (why) {
  Unreachable.mac => "it's asleep or offline, or its remote access is off",
  Unreachable.relay => "the relay can't be reached: check this phone's network",
  Unreachable.answer => "it didn't answer: was this phone removed there?",
  null => 'the connection failed',
};

/// "last seen 10:42", or with the day when it wasn't today.
String seenAt(DateTime s, {DateTime? now}) {
  final n = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final time = '${two(s.hour)}:${two(s.minute)}';
  if (s.year == n.year && s.month == n.month && s.day == n.day) {
    return 'last seen $time';
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return 'last seen ${months[s.month - 1]} ${s.day}, $time';
}

/// A newer version of the app is installed and waits: Reload brings it in
/// (the service worker never swaps it under a running page).
class UpdateBar extends StatelessWidget {
  const new(this.phone, {super.key});

  final Phone phone;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: phone.platform.updateReady,
    builder: (context, ready, _) {
      if (!ready) return const SizedBox.shrink();
      final t = NushiTheme.of(context).t;
      return ColoredBox(
        color: t.raised,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Nushi was updated',
                  style: phoneText(context, size: 14),
                ),
              ),
              TextButton(
                onPressed: phone.platform.applyUpdate,
                style: TextButton.styleFrom(
                  minimumSize: const Size(touch, touch),
                ),
                child: Text(
                  'Reload',
                  style: phoneText(context, color: t.link, size: 14),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
