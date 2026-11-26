import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart' show agoAt;
import 'package:nushi/conventions.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/remote_reset.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:qr/qr.dart';

/// Remote access as the daemon last said (ADR 0034); null until it has.
final ValueNotifier<Remote?> remoteState = runValue(null);

const _states = {
  'connected': 'Connected',
  'connecting': 'Connecting…',
  'reconnecting': 'Reconnecting…',
  'off': 'Off',
  'error': "Can't reach the relay",
};

/// Settings › Remote access: that it was reset, if it was (RemoteResetLine),
/// the switch and the relay's state, the relay,
/// this computer's key, then the paired phones and Pair a phone.
class RemoteSection extends StatefulWidget {
  const new(this.client, {super.key});

  final NushiServiceClient client;

  @override
  State<RemoteSection> createState() => _RemoteSectionState();
}

class _RemoteSectionState extends State<RemoteSection> {
  final _relay = TextEditingController();

  @override
  void initState() {
    super.initState();
    remoteState.addListener(_seed);
    _seed();
  }

  /// Fills the field with the saved relay once the daemon has said it,
  /// and never again: what the user types is theirs until submitted.
  void _seed() {
    final r = remoteState.value;
    if (r == null) return;
    remoteState.removeListener(_seed);
    _relay.text = r.relay;
  }

  @override
  void dispose() {
    remoteState.removeListener(_seed);
    _relay.dispose();
    super.dispose();
  }

  /// Turning on sends the field's relay (typed, then switched on);
  /// turning off sends the [saved] one, so an edit never submitted, or a
  /// cleared field, isn't saved by the switch.
  Future<void> _set(bool on, String saved) async {
    final relay = on ? _relay.text.trim() : saved;
    await widget.client.setRemote(SetRemoteRequest(on: on, relay: relay));
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ValueListenableBuilder(
      valueListenable: remoteState,
      builder: (context, r, _) {
        if (r == null) return const SizedBox.shrink();
        final state = switch (r.state) {
          'error' => "${_states['error']}: ${r.error} (trying again)",
          'reconnecting' when r.error.isNotEmpty =>
            '${_states['reconnecting']} The relay dropped the link: '
                '${r.error}',
          _ => _states[r.state] ?? r.state,
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroup(
              children: [
                if (r.hasWasReset()) RemoteResetLine(r.wasReset),
                SettingsRow(
                  'Remote access',
                  description: state,
                  note: r.on ? 'Keeps the ${conventions.machine} awake' : null,
                  descriptionColor: r.state == 'error' ? t.crashed : null,
                  control: SettingsSwitch(
                    value: r.on,
                    run: ({required on}) => _set(on, r.relay),
                  ),
                ),
                SettingsRow(
                  'Relay',
                  // Narrow, the field goes under its label, as wide as the
                  // row allows, rather than leave the label a few points.
                  stackBelow: 440,
                  control: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: TextField(
                      controller: _relay,
                      style: theme.code(t.text),
                      decoration: const InputDecoration(
                        // The owner's, as an example of what goes here.
                        hintText: 'For example wss://relay.example.com',
                        isDense: true,
                      ),
                      onSubmitted: (_) => r.on
                          ? tryOrShow(context, () => _set(true, r.relay))
                          : null,
                    ),
                  ),
                ),
                if (r.key.isNotEmpty)
                  SettingsRow(
                    "This ${conventions.machine}'s key",
                    description: 'A paired phone shows the same.',
                    control: Text(
                      keyFingerprint(r.key),
                      style: theme.code(t.textSecondary),
                    ),
                  ),
              ],
            ),
            SettingsGroup(
              title: 'Phones',
              actions: [
                Button(
                  label: 'Pair a phone',
                  icon: Icons.add,
                  tooltip: r.on ? '' : 'Turn on Remote access first',
                  onPressed: r.on ? () => _pair(context, widget.client) : null,
                ),
              ],
              empty: 'No phones paired',
              // Why a button is off, where its fade alone said nothing.
              footer: _phonesNote(r),
              children: [
                for (final d in r.devices) _DeviceRow(d, widget.client),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The Phones group's note of why its buttons are off, if any are: Pair
/// a phone while Remote access is off, a test notification for a phone
/// whose notifications are off.
Widget? _phonesNote(Remote r) {
  final lines = [
    if (!r.on) 'Turn on Remote access to pair a phone.',
    if (r.devices.any((d) => !d.push))
      'A test notification needs the phone’s notifications on.',
  ];
  return lines.isEmpty ? null : Text(lines.join(' '));
}

/// A paired device (always the web app, ADR 0054): its name, whether it
/// gets notifications, and when it was last seen; Send a test notification
/// and Revoke.
class _DeviceRow extends StatelessWidget {
  const new(this.d, this.client);

  final Device d;
  final NushiServiceClient client;

  Future<void> _test(BuildContext context) async {
    var sent = false;
    await tryOrShow(context, () async {
      await client.sendTestPush(SendTestPushRequest(deviceId: d.id));
      sent = true;
    });
    if (sent && context.mounted) {
      showToast(
        Toasts.maybeOf(context),
        'Sent a test notification to ${d.name}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final seen = d.connected
        ? 'connected'
        : d.lastSeen > 0
        ? agoAt(d.lastSeen.toInt(), clock())
        : '';
    return SettingsRow(
      d.name,
      // Narrow, the two buttons go under the words rather than wrap them
      // to three lines.
      stackBelow: 520,
      description:
          'Notifications ${d.push ? 'on' : 'off'}'
          '${seen.isEmpty ? '' : ', $seen'}',
      control: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Button(
            label: 'Send a test notification',
            tooltip: d.push ? '' : 'Notifications are off on this device',
            onPressed: d.push ? () => _test(context) : null,
          ),
          Button(
            label: 'Revoke',
            kind: ButtonKind.destructive,
            onPressed: () => tryOrShow(
              context,
              () => client.revokeDevice(RevokeDeviceRequest(id: d.id)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The daemon's key as both the Mac and a paired phone show it: the first
/// 8 bytes of its SHA-256, in four groups ("3f9a c2e0 71b4 08d6"). A phone
/// that shows another Mac's was paired with someone else's daemon.
String keyFingerprint(List<int> key) {
  final hex = sha256.convert(key).toString().substring(0, 16);
  return [for (var i = 0; i < 16; i += 4) hex.substring(i, i + 4)].join(' ');
}

/// The QR code's pairing as a link to the relay's web app (ADR 0054): the
/// same parameters, in the fragment, so they never reach a server. The
/// daemon sends it as StartPairingResponse.link; this builds it for one
/// that doesn't (an older daemon, until it restarts for this app's).
String pairingLink(String qr) {
  final q = Uri.parse(qr);
  final relay = Uri.parse(q.queryParameters['r'] ?? '');
  final web = Uri(
    scheme: relay.scheme == 'ws' ? 'http' : 'https',
    host: relay.host,
    port: relay.hasPort ? relay.port : null,
    path: '/',
  );
  return '$web#pair?${q.query}';
}

/// Shows the QR code, then, once a phone has connected, its name and the
/// code to compare, with Allow and Deny.
Future<void> _pair(BuildContext context, NushiServiceClient client) async {
  final StartPairingResponse start;
  try {
    start = await client.startPairing(StartPairingRequest());
  } on Object catch (e) {
    if (context.mounted) showError(context, e);
    return;
  }
  if (!context.mounted) return;
  final link = start.link.isNotEmpty ? start.link : pairingLink(start.qr);
  await _show(context, client, link);
}

/// Whether a pairing dialog is open.
final ValueNotifier<bool> _open = runValue(false);

Future<void> _show(
  BuildContext context,
  NushiServiceClient client,
  String link,
) async {
  _open.value = true;
  try {
    await showDialog<void>(
      context: context,
      builder: (_) => _Pairing(client, link),
    );
  } finally {
    _open.value = false;
  }
}

/// Asks Allow or Deny whenever a pairing reaches its code, whoever started
/// it, unless a pairing dialog is open already.
/// Returns what stops it watching.
VoidCallback watchPairings(
  GlobalKey<NavigatorState> navigator,
  NushiServiceClient client,
) {
  var asked = '';
  void changed() {
    final r = remoteState.value;
    final code = r != null && r.hasPairing() ? r.pairing.code : '';
    final context = navigator.currentContext;
    if (code.isEmpty || code == asked || _open.value || context == null) return;
    asked = code;
    unawaited(_show(context, client, ''));
  }

  remoteState.addListener(changed);
  return () => remoteState.removeListener(changed);
}

class _Pairing extends StatelessWidget {
  const new(this.client, this.link);

  final NushiServiceClient client;
  final String link; // empty when another client started the pairing

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Future<void> answer(String code, {required bool allow}) async {
      await tryOrShow(
        context,
        () => client.confirmPairing(
          ConfirmPairingRequest(code: code, allow: allow),
        ),
      );
      if (context.mounted) Navigator.pop(context);
    }

    return ValueListenableBuilder(
      valueListenable: remoteState,
      builder: (context, r, _) {
        final p = r?.hasPairing() ?? false ? r!.pairing : null;
        final close = Button(
          label: 'Close',
          onPressed: () => Navigator.pop(context),
        );
        if (p == null || p.code.isEmpty && link.isEmpty) {
          return nushiDialog(
            'Pair a phone',
            Text(
              'This code is used up or has expired.',
              style: theme.ui(t.textSecondary),
            ),
            [
              close,
              if (r?.on ?? false)
                Button(
                  label: 'New code',
                  onPressed: () {
                    final nav = Navigator.of(context)..pop();
                    unawaited(_pair(nav.context, client));
                  },
                ),
            ],
          );
        }
        if (p.code.isEmpty) {
          return nushiDialog(
            'Pair a phone',
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  // design: a QR code is read dark on white.
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 220,
                    // The web app's link (parameters in the fragment): the
                    // iPhone's Camera opens it, and Nushi's Scan reads it.
                    child: CustomPaint(painter: _QrPainter(link)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Scan it with Scan in Nushi on the phone’s Home Screen, or '
                  'copy the link and paste it there.',
                  textAlign: TextAlign.center,
                  style: theme.ui(t.textSecondary),
                ),
              ],
            ),
            [_CopyLink(link), close],
          );
        }
        return nushiDialog(
          'Pair ${p.name}?',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.code,
                // design: the pairing code, large to read off
                style: theme.code(t.text, size: 32).copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              Text(
                'Allow only if the phone shows this code.',
                style: theme.ui(t.textSecondary),
              ),
            ],
          ),
          [
            Button(
              label: 'Deny',
              onPressed: () => answer(p.code, allow: false),
            ),
            Button(
              label: 'Allow',
              kind: ButtonKind.primary,
              onPressed: () => answer(p.code, allow: true),
            ),
          ],
        );
      },
    );
  }
}

/// Copies the pairing link, for the web app (AirDrop or Universal
/// Clipboard to the phone).
class _CopyLink extends StatefulWidget {
  const new(this.link);

  final String link;

  @override
  State<_CopyLink> createState() => _CopyLinkState();
}

class _CopyLinkState extends State<_CopyLink> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) => Button(
    label: _copied ? 'Copied' : 'Copy link',
    icon: Icons.link,
    onPressed: () async {
      await Clipboard.setData(ClipboardData(text: widget.link));
      if (mounted) setState(() => _copied = true);
    },
  );
}

class _QrPainter extends CustomPainter {
  new(String text)
    : _image = QrImage(QrCode(payload: QrPayload.fromString(text)));

  final QrImage _image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = _image.moduleCount;
    final cell = size.width / n;
    // design: a QR code is read dark on white.
    final dark = Paint()..color = Colors.black;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (_image.isDark(y, x)) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => false;
}

/// The status bar's mark while remote access is on, in red when it can't
/// reach the relay.
class RemoteMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ValueListenableBuilder(
      valueListenable: remoteState,
      builder: (context, r, _) {
        if (r == null || !r.on) return const SizedBox.shrink();
        final phones = r.devices.where((d) => d.connected).length;
        return tooltip(
          context,
          'Remote access: ${_states[r.state] ?? r.state}'
          '${phones > 0 ? ', $phones connected' : ''}',
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.phone_iphone,
              size: 12,
              color: r.state == 'error'
                  ? t.crashed
                  : (phones > 0 ? t.running : t.textSecondary),
            ),
          ),
        );
      },
    );
  }
}
