import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/subscription.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/theme/theme.dart';

/// The phone's settings: the relay, this device's name, notifications, and
/// Forget this Mac.
class SettingsScreen extends StatelessWidget {
  const new(this.phone, {super.key});

  final Phone phone;

  Future<void> _push(BuildContext context, {required bool on}) async {
    final why = await phone.setPush(on: on);
    if (why != null && context.mounted) phoneSay(context, why);
  }

  Future<void> _forget(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this Mac?'),
        content: const Text(
          'This device forgets the Mac and its own key; pairing again '
          'makes a new one. Revoke it on the Mac too: until then the Mac '
          'lists it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (sure ?? false) {
      await phone.forget();
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ListenableBuilder(
      listenable: Listenable.merge([phone, ?phone.daemon]),
      builder: (context, _) {
        final connected = phone.daemon?.connected ?? false;
        final note = switch (phone.push) {
          PushState.unsupported =>
            'Notifications work once Nushi is on the Home Screen.',
          PushState.denied =>
            'Notifications are off for Nushi in the phone’s Settings.',
          _ when !connected => 'Connect to the Mac to change this.',
          _ =>
            'When a chat finishes or needs you. They say only what '
                'happened, never what’s in the chat.',
        };
        return PhoneScreen(
          title: 'Settings',
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const PhoneHeading('Mac'),
              _Line('Relay', phone.paired?.relay.toString() ?? ''),
              _Line('This device', phone.name),
              _Line('Connection', connected ? 'Connected' : 'Not connected'),
              const PhoneHeading('Notifications'),
              SwitchListTile(
                title: Text('Notifications', style: phoneText(context)),
                subtitle: Text(
                  note,
                  style: phoneText(context, color: t.textMuted, size: 13),
                ),
                value: phone.push == PushState.on,
                onChanged:
                    phone.canPush && phone.push != PushState.denied && connected
                    ? (on) => unawaited(_push(context, on: on))
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: PhoneButton(
                  'Forget this Mac',
                  destructive: true,
                  onTap: () => unawaited(_forget(context)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const new(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: touch),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: phoneText(context))),
            Expanded(
              child: SelectableText(
                value,
                style: phoneText(context, color: t.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
