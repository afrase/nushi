import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/alerts.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Settings › General's Notifications: each kind on or off, the sound and
/// the Dock badge (`alerts.dart`); and, when macOS has them off for Nushi,
/// a way to its settings.
class NotificationsGroup extends StatefulWidget {
  const new({super.key, this.channel = alertsChannel});

  final MethodChannel channel;

  @override
  State<NotificationsGroup> createState() => _NotificationsGroupState();
}

class _NotificationsGroupState extends State<NotificationsGroup> {
  String? _allowed;

  @override
  void initState() {
    super.initState();
    alertsAllowed(widget.channel).then((a) {
      if (mounted) setState(() => _allowed = a);
    }).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    SettingsRow row(String label, String text, ValueNotifier<bool> on) =>
        SettingsRow(
          label,
          description: text,
          control: SettingsSwitch(
            value: on.value,
            onChanged: (v) => on.value = v,
          ),
        );
    return ListenableBuilder(
      listenable: Listenable.merge([
        alertNeedsYou,
        alertFinished,
        alertFailed,
        alertSound,
        dockBadge,
      ]),
      builder: (context, _) => SettingsGroup(
        title: 'Notifications',
        footer: const Text(
          "Shown while Nushi isn't the app in front, or for a chat other "
          'than the one showing. A click opens the chat. They stay on this '
          'Mac.',
        ),
        children: [
          if (_allowed == 'denied')
            SettingsRow(
              'Off in macOS',
              description: 'macOS has notifications off for Nushi.',
              descriptionColor: t.needs,
              control: Button(
                label: 'Open Notifications…',
                onPressed: () => tryOrShow(
                  context,
                  () => widget.channel.invokeMethod<void>('openSettings'),
                ),
              ),
            ),
          row(
            'A chat needs you',
            'A permission prompt or a question.',
            alertNeedsYou,
          ),
          row('A turn ends', 'The agent finished its turn.', alertFinished),
          row('A turn fails', 'The turn ended with an error.', alertFailed),
          row('Sound', 'Play the notification sound.', alertSound),
          row(
            'Dock badge',
            "The number of chats that need you, on Nushi's icon.",
            dockBadge,
          ),
        ],
      ),
    );
  }
}
