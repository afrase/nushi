import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/theme/theme.dart';

/// Pairing with a Mac (ADR 0054): the link the Mac's Pair dialog copies,
/// pasted here, then the code both screens show. In Safari, before Nushi
/// is on the Home Screen, it says how to put it there first: the Home
/// Screen app keeps its storage apart from Safari's, so pairing must
/// happen inside it.
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
  void dispose() {
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
    } on FormatException {
      _error = "That isn't a Nushi pairing link: copy it again on the Mac.";
    } on Object catch (e) {
      _error = e.toString().contains('refused')
          ? 'The Mac refused this device, or no one answered in time.'
          : "Couldn't pair: $e";
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
              if (notInstalled) ...[
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
                if (platform.openedWith != null) ...[
                  const SizedBox(height: 12),
                  Text('Then paste this pairing link there:', style: muted),
                  const SizedBox(height: 8),
                  PhoneButton(
                    'Copy pairing link',
                    onTap: () => unawaited(
                      Clipboard.setData(
                        ClipboardData(text: platform.openedWith!),
                      ),
                    ),
                  ),
                ],
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
              ] else ...[
                Text(
                  'On the Mac: Settings › Remote access › Pair a phone, then '
                  'Copy link, and paste it here.',
                  style: muted,
                ),
                const SizedBox(height: 16),
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
                TextField(
                  controller: _name,
                  style: phoneText(context),
                  decoration: const InputDecoration(
                    labelText: 'This device’s name, as the Mac shows it',
                  ),
                ),
                const SizedBox(height: 20),
                PhoneButton(
                  _pairing ? 'Connecting…' : 'Pair',
                  primary: true,
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
