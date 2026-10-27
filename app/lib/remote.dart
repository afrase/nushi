import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/commits.dart' show ago;
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:qr/qr.dart';

/// Remote access as the daemon last said (ADR 0034); null until it has.
final remoteState = ValueNotifier<Remote?>(null);

const _states = {
  'connected': 'Connected',
  'connecting': 'Connecting…',
  'reconnecting': 'Reconnecting…',
  'off': 'Off',
  'error': "Can't reach the relay",
};

/// Settings → Remote access: the switch, the relay, the state, pairing a
/// phone, and the paired phones.
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
    _relay.text = remoteState.value?.relay ?? '';
  }

  @override
  void dispose() {
    _relay.dispose();
    super.dispose();
  }

  Future<void> _set(bool on) => tryOrShow(
    context,
    () => widget.client.setRemote(
      SetRemoteRequest(on: on, relay: _relay.text.trim()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ValueListenableBuilder(
      valueListenable: remoteState,
      builder: (context, r, _) {
        if (r == null) return const SizedBox.shrink();
        final muted = theme.ui(t.textMuted, size: 12);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Remote access',
                  style: theme.ui(t.text, weight: FontWeight.w600),
                ),
                const Spacer(),
                SizedBox(
                  height: 20,
                  child: FittedBox(
                    child: Switch(value: r.on, onChanged: _set),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _relay,
              style: theme.code(t.text),
              decoration: const InputDecoration(
                // The owner's, as an example of what goes here.
                hintText: 'For example wss://nushi.taile2d635.ts.net',
                isDense: true,
              ),
              onSubmitted: (_) => r.on ? _set(true) : null,
            ),
            const SizedBox(height: 6),
            Text(
              switch (r.state) {
                'error' => "${_states['error']}: ${r.error} (trying again)",
                'reconnecting' when r.error.isNotEmpty =>
                  '${_states['reconnecting']} The relay dropped the link: '
                      '${r.error}',
                _ => _states[r.state] ?? r.state,
              },
              style: theme.ui(
                r.state == 'error' ? t.crashed : t.textSecondary,
                size: 12,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (r.on) Text('Keeps the Mac awake while on.', style: muted),
            if (r.key.isNotEmpty)
              Text(
                "This Mac's key: ${keyFingerprint(r.key)}, as a paired "
                'phone shows it.',
                style: muted,
              ),
            const SizedBox(height: 8),
            for (final d in r.devices) _DeviceRow(d, widget.client),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Button(
                label: 'Pair a phone',
                onPressed: r.on ? () => _pair(context, widget.client) : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A paired device: its name, whether it's the web app or an app, whether
/// it gets notifications, and when it was last seen; Send a test
/// notification and Revoke.
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
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Sent a test notification to ${d.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    final seen = d.connected
        ? 'connected'
        : d.lastSeen > 0
        ? _seen(d.lastSeen.toInt())
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: d.name, style: theme.ui(t.text, size: 12.5)),
                  TextSpan(
                    text:
                        '  ${d.kind == 'web' ? 'Web' : 'iPhone app'}'
                        ' · notifications ${d.push ? 'on' : 'off'}'
                        '${seen.isEmpty ? '' : ' · $seen'}',
                    style: muted,
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Button(
            label: 'Send a test notification',
            tooltip: d.push ? '' : 'Notifications are off on this device',
            onPressed: d.push ? () => _test(context) : null,
          ),
          const SizedBox(width: 6),
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
/// same parameters, in the fragment, so they never reach a server.
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
  await _show(context, client, start.qr);
}

/// Whether a pairing dialog is open.
var _open = false;

Future<void> _show(
  BuildContext context,
  NushiServiceClient client,
  String qr,
) async {
  _open = true;
  try {
    await showDialog<void>(
      context: context,
      builder: (_) => _Pairing(client, qr),
    );
  } finally {
    _open = false;
  }
}

/// Asks Allow or Deny whenever a pairing reaches its code, whoever started
/// it, unless a pairing dialog is open already.
void watchPairings(
  GlobalKey<NavigatorState> navigator,
  NushiServiceClient client,
) {
  var asked = '';
  remoteState.addListener(() {
    final r = remoteState.value;
    final code = r != null && r.hasPairing() ? r.pairing.code : '';
    final context = navigator.currentContext;
    if (code.isEmpty || code == asked || _open || context == null) return;
    asked = code;
    unawaited(_show(context, client, ''));
  });
}

class _Pairing extends StatelessWidget {
  const new(this.client, this.qr);

  final NushiServiceClient client;
  final String qr; // empty when another client started the pairing

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
        if (p == null || p.code.isEmpty && qr.isEmpty) {
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
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 220,
                    child: CustomPaint(painter: _QrPainter(qr)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Scan with Nushi on the phone, or copy the link and paste '
                  'it in Nushi on the phone’s Home Screen.',
                  textAlign: TextAlign.center,
                  style: theme.ui(t.textSecondary),
                ),
              ],
            ),
            [_CopyLink(pairingLink(qr)), close],
          );
        }
        return nushiDialog(
          'Pair ${p.name}?',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.code,
                style: theme
                    .code(t.text)
                    .copyWith(fontSize: 32, letterSpacing: 4),
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
        return Tooltip(
          message:
              'Remote access: ${_states[r.state] ?? r.state}'
              '${phones > 0 ? ', $phones connected' : ''}',
          child: Padding(
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

/// When a device was last seen, [ms] after the epoch, as "5m ago".
String _seen(int ms) {
  final at = DateTime.fromMillisecondsSinceEpoch(ms);
  return ago(DateTime.now().difference(at), at);
}
