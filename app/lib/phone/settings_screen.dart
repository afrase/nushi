import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/subscription.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/remote.dart' show keyFingerprint;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme_strip.dart';

/// The phone's settings: the relay, this device's name, notifications, the
/// theme, and Forget this Mac.
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
              _Line(
                "Mac's key",
                phone.paired == null ? '' : keyFingerprint(phone.paired!.key),
              ),
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
              const PhoneHeading('Theme'),
              _Themes(phone),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: PhoneButton(
                  phone.forgetting ? 'Forgetting…' : 'Forget this Mac',
                  destructive: true,
                  onTap: phone.forgetting
                      ? null
                      : () => unawaited(_forget(context)),
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

/// The built-in themes (ADR 0086), each its name and its key colors in the
/// phone's brightness, the one picked checked; a tap picks one at once.
class _Themes extends StatelessWidget {
  const new(this.phone);

  final Phone phone;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ValueListenableBuilder(
      valueListenable: phone.theme,
      builder: (context, picked, _) => Column(
        children: [
          for (final c in builtInThemes)
            Semantics(
              selected: c.id == picked.id,
              child: Pressable(
                onTap: () => unawaited(phone.pickTheme(c)),
                builder: (context, look) => Container(
                  constraints: const BoxConstraints(minHeight: touch),
                  color: look.hover ? t.hover : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    spacing: 12,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(c.name, style: phoneText(context)),
                      ),
                      Expanded(
                        child: ThemeStrip(
                          c.of(t.brightness),
                          outline: t.borderStrong,
                          height: 18,
                        ),
                      ),
                      SizedBox(
                        width: 22,
                        child: c.id == picked.id
                            ? Icon(Icons.check, size: 20, color: t.accentInk)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
