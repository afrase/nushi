import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import 'commits.dart' show ago;
import 'gen/nushi/v1/nushi.connect.client.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// Remote access as the daemon last said (ADR 0034); null until it has.
final remoteState = ValueNotifier<Remote?>(null);

const _states = {
  'connected': 'Connected',
  'connecting': 'Connecting…',
  'off': 'Off',
  'error': 'Can\'t reach the relay',
};

/// Settings → Remote access: the switch, the relay, the state, pairing a
/// phone, and the paired phones.
class RemoteSection extends StatefulWidget {
  const RemoteSection(this.client, {super.key});

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
    final theme = NushiTheme.of(context), t = theme.t;
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
                hintText: 'wss://relay.example.com',
                isDense: true,
              ),
              onSubmitted: (_) => r.on ? _set(true) : null,
            ),
            const SizedBox(height: 6),
            Text(
              r.state == 'error'
                  ? '${_states['error']}: ${r.error}'
                  : _states[r.state] ?? r.state,
              style: theme.ui(
                r.state == 'error' ? t.crashed : t.textSecondary,
                size: 12,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (r.on) Text('Keeps the Mac awake while on.', style: muted),
            const SizedBox(height: 8),
            for (final d in r.devices)
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: d.name,
                            style: theme.ui(t.text, size: 12.5),
                          ),
                          TextSpan(
                            text: d.connected
                                ? '  connected'
                                : d.lastSeen > 0
                                ? '  ${ago(DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(d.lastSeen.toInt())), DateTime.fromMillisecondsSinceEpoch(d.lastSeen.toInt()))}'
                                : '',
                            style: muted,
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Button(
                    label: 'Revoke',
                    kind: ButtonKind.ghost,
                    height: 22,
                    onPressed: () => tryOrShow(
                      context,
                      () => widget.client.revokeDevice(
                        RevokeDeviceRequest(id: d.id),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Button(
                label: 'Pair a phone',
                kind: ButtonKind.secondary,
                onPressed: r.on ? () => _pair(context, widget.client) : null,
              ),
            ),
          ],
        );
      },
    );
  }
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
  await showDialog<void>(
    context: context,
    builder: (_) => _Pairing(client, start.qr),
  );
}

class _Pairing extends StatelessWidget {
  const _Pairing(this.client, this.qr);

  final NushiServiceClient client;
  final String qr;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    Future<void> answer(String code, bool allow) async {
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
        final p = r?.hasPairing() == true ? r!.pairing : null;
        final close = Button(
          label: 'Close',
          kind: ButtonKind.ghost,
          onPressed: () => Navigator.pop(context),
        );
        if (p == null) {
          return nushiDialog(
            'Pair a phone',
            Text('The code has expired.', style: theme.ui(t.textSecondary)),
            [close],
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
                  'Scan with Nushi on the phone.',
                  style: theme.ui(t.textSecondary),
                ),
              ],
            ),
            [close],
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
              kind: ButtonKind.ghost,
              onPressed: () => answer(p.code, false),
            ),
            Button(
              label: 'Allow',
              kind: ButtonKind.primary,
              onPressed: () => answer(p.code, true),
            ),
          ],
        );
      },
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(String text)
    : _image = QrImage(
        QrCode(
          payload: QrPayload.fromString(text),
          errorCorrectLevel: QrErrorCorrectLevel.medium,
        ),
      );

  final QrImage _image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = _image.moduleCount, cell = size.width / n;
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
  const RemoteMark({super.key});

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
              'Remote access: ${_states[r.state] ?? r.state}${phones > 0 ? ', $phones connected' : ''}',
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
