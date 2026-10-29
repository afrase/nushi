import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/phone/connection_bar.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/scan_screen.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/theme/theme.dart';
import 'package:remote_transport/remote_transport.dart' show PairingRefused;

/// Pairing with a Mac (ADR 0054): Scan its QR code with the camera, or
/// paste the link its Pair dialog copies; then the code both screens show.
/// In Safari, before Nushi is on the Home Screen, it says how to put it
/// there first: the Home Screen app keeps its storage apart from Safari's,
/// so pairing must happen inside it. Opened from the Mac's QR code by the
/// iPhone's Camera (which opens Safari), it says to open Nushi and scan
/// there, and offers the link to copy.
class PairScreen extends StatefulWidget {
  const new(this.phone, {super.key});

  final Phone phone;

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  late final _link = TextEditingController(
    text: widget.phone.platform.openedWith ?? '',
  );
  late final _name = TextEditingController(
    text: widget.phone.platform.iPhone ? 'iPhone' : 'Web browser',
  );
  bool _pairing = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final platform = widget.phone.platform
      ..onPairLink = (link) => setState(() {
        _link.text = link;
      });
    // Opened with a link inside the Home Screen app (no other page can
    // open it there): pair at once; the code check still stands.
    if (platform.openedWith != null && platform.installed && platform.iPhone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_pair());
      });
    }
  }

  /// Scans the Mac's QR code, then pairs with it.
  Future<void> _scan() async {
    final link = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (link == null || !mounted) return;
    setState(() => _link.text = link);
    await _pair();
  }

  @override
  void dispose() {
    widget.phone.platform.onPairLink = null;
    _link.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    setState(() {
      _pairing = true;
      _error = '';
    });
    try {
      await widget.phone.pair(_link.text, _name.text);
    } on FormatException catch (e) {
      _error = e.message.startsWith('This link is for')
          ? '${e.message}.'
          : "That isn't a Nushi pairing link: copy it again on the Mac.";
    } on PairingRefused {
      _error = 'The Mac refused this device, or no one answered in time.';
    } on Object catch (e) {
      // A relay that can't be reached says so ("Connection refused"), not
      // that the Mac refused.
      _error = "Couldn't pair: $e";
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final platform = widget.phone.platform;
    final notInstalled = platform.iPhone && !platform.installed;
    final muted = phoneText(context, color: t.textSecondary, size: 15);
    return ListenableBuilder(
      listenable: widget.phone,
      builder: (context, _) {
        final code = widget.phone.pairing?.code;
        return PhoneScreen(
          title: 'Pair with a Mac',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              UpdateBar(widget.phone),
              if (notInstalled && platform.openedWith != null) ...[
                Text(
                  'Open Nushi from your Home Screen',
                  style: phoneText(context, weight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'and tap Scan or Paste there: Nushi on the Home Screen keeps '
                  'its own storage, apart from Safari’s. Not there yet? Tap '
                  'Share, then “Add to Home Screen”.',
                  style: muted,
                ),
                const SizedBox(height: 12),
                PhoneButton(
                  'Copy link',
                  onTap: () => unawaited(
                    Clipboard.setData(
                      ClipboardData(text: platform.openedWith!),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ] else if (notInstalled) ...[
                Text(
                  'Add Nushi to the Home Screen first',
                  style: phoneText(context, weight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap Share, then “Add to Home Screen”, and open Nushi from '
                  'there. Pair inside that app: it keeps its own storage, '
                  'apart from Safari’s, and only it gets notifications.',
                  style: muted,
                ),
                const SizedBox(height: 28),
              ],
              if (code != null) ...[
                Text('Check the Mac shows', style: muted),
                const SizedBox(height: 8),
                Text(
                  code,
                  textAlign: TextAlign.center,
                  style: NushiTheme.of(context)
                      .code(t.text, size: 40)
                      .copyWith(letterSpacing: 4),
                ),
                const SizedBox(height: 8),
                Text(
                  'then Allow there. If it shows another code, Deny it.',
                  style: muted,
                ),
              ] else if (!notInstalled) ...[
                Text(
                  'On the Mac: Settings › Remote access › Pair a phone.',
                  style: muted,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  style: phoneText(context),
                  decoration: const InputDecoration(
                    labelText: 'This device’s name, as the Mac shows it',
                  ),
                ),
                const SizedBox(height: 16),
                PhoneButton(
                  _pairing ? 'Connecting…' : 'Scan QR code',
                  primary: _link.text.trim().isEmpty,
                  onTap: _pairing ? null : () => unawaited(_scan()),
                ),
                const SizedBox(height: 24),
                Text('Or paste the link it copies:', style: muted),
                const SizedBox(height: 8),
                TextField(
                  controller: _link,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLines: 3,
                  minLines: 1,
                  style: phoneText(context, size: 14),
                  decoration: const InputDecoration(
                    labelText: 'Pairing link',
                    hintText: 'https://…/#pair?…',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                PhoneButton(
                  'Pair',
                  primary: _link.text.trim().isNotEmpty,
                  onTap: _pairing || _link.text.trim().isEmpty ? null : _pair,
                ),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_error, style: phoneText(context, color: t.crashed)),
              ],
            ],
          ),
        );
      },
    );
  }
}
