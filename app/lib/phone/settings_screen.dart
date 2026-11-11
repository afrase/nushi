import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/subscription.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/remote.dart' show keyFingerprint;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme_preview.dart';
import 'package:nushi/widgets.dart';

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
    final machine = phoneHost.machine;
    final sure = await confirm(
      context,
      'Forget this $machine?',
      'This device forgets the $machine and its own key; pairing again makes '
          'a new one. Revoke it on the $machine too: until then the $machine '
          'lists it.',
      'Forget',
      destructive: true,
    );
    if (sure) {
      await phone.forget();
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final machine = phoneHost.machine;
    final heading = machine[0].toUpperCase() + machine.substring(1);
    return ListenableBuilder(
      listenable: Listenable.merge([phone, ?phone.daemon]),
      builder: (context, _) {
        final connected = phone.daemon?.connected ?? false;
        final note = switch (phone.push) {
          PushState.unsupported =>
            'Notifications work once Nushi is on the Home Screen.',
          PushState.denied =>
            'Notifications are off for Nushi in the phone’s Settings.',
          _ when !connected => 'Connect to the $machine to change this.',
          _ =>
            'When a chat finishes or needs you. They say only what '
                'happened, never what’s in the chat.',
        };
        return PhoneScreen(
          title: 'Settings',
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PhoneHeading(heading),
              _Line('Relay', phone.paired?.relay.toString() ?? ''),
              _Line(
                "$heading's key",
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
                  phone.forgetting ? 'Forgetting…' : 'Forget this $machine',
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

/// The built-in themes (ADR 0086), two across, each a picture of Nushi in
/// it (in the phone's brightness) over its name, the one picked ringed and
/// checked; a tap picks one at once.
class _Themes extends StatelessWidget {
  const new(this.phone);

  final Phone phone;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    Widget card(ColorTheme c, {required bool picked}) => Semantics(
      selected: picked,
      button: true,
      label: c.name,
      child: Pressable(
        onTap: () => unawaited(phone.pickTheme(c)),
        builder: (context, look) => Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            // A card on the screen (ADR 0111), no outline; the picked one
            // keeps its ring, always as wide, so nothing inside moves.
            color: look.hover ? Color.alphaBlend(t.hover, t.raised) : t.raised,
            border: Border.all(
              color: picked ? t.accentInk : const Color(0x00000000),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(NushiTheme.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              framed(
                // A hairline where the picture meets the card: another
                // theme's window can be the card's own color.
                border: t.line,
                // Inside its card's padding (6) and ring.
                radius: NushiTheme.inner(NushiTheme.card, 8),
                child: ThemePreview(c.of(t.brightness), dark: c.dark),
              ),
              SizedBox(
                height: 24,
                child: Row(
                  children: [
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: phoneText(context),
                      ),
                    ),
                    if (picked) Icon(Icons.check, size: 20, color: t.accentInk),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return ValueListenableBuilder(
      valueListenable: phone.theme,
      builder: (context, picked, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          spacing: 12,
          children: [
            for (var i = 0; i < builtInThemes.length; i += 2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  for (var j = i; j < i + 2; j++)
                    Expanded(
                      child: j < builtInThemes.length
                          ? card(
                              builtInThemes[j],
                              picked: builtInThemes[j].id == picked.id,
                            )
                          : const SizedBox(),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
