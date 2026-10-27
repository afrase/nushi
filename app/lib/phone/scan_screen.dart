import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/phone/scanner.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/theme/theme.dart';
import 'package:remote_transport/remote_transport.dart' show PairingOffer;

/// Scanning the Mac's QR code: the back camera, asked for only now (a tap
/// brought this screen), and closed with it. A Nushi pairing code closes
/// it with the code's text; anything else says so and goes on looking.
class ScanScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scanner = Scanner();
  StreamSubscription<String>? _codes;
  String? _error; // why the camera can't be used
  String _note = ''; // a code that isn't Nushi's
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _codes = _scanner.codes.listen(_seen);
    unawaited(
      _scanner.start().then((why) {
        if (mounted && why != null) setState(() => _error = why);
      }),
    );
  }

  void _seen(String text) {
    if (_done || !mounted) return;
    try {
      PairingOffer.parse(text);
    } on FormatException {
      setState(() => _note = "That isn't a Nushi pairing code.");
      return;
    }
    _done = true;
    _scanner.stop();
    Navigator.of(context).pop(text);
  }

  @override
  void dispose() {
    unawaited(_codes?.cancel());
    _scanner.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return PhoneScreen(
      title: 'Scan the Mac’s code',
      body: _error != null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: phoneText(context, color: t.crashed)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: Colors.black, child: _scanner.view()),
                      // Where the code goes.
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.7,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white70,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Text(
                    _note.isNotEmpty
                        ? _note
                        : 'Point the camera at the code in Settings › Remote '
                              'access › Pair a phone on the Mac.',
                    textAlign: TextAlign.center,
                    style: phoneText(
                      context,
                      size: 15,
                      color: _note.isNotEmpty ? t.crashed : t.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
