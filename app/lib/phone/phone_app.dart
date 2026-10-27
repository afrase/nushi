import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/phone/pair_screen.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/theme/theme.dart';

/// The phone's app (ADR 0054): pairing until paired, then the chats.
/// Light or dark as the system is.
class PhoneApp extends StatefulWidget {
  const new(this.phone, {super.key});

  final Phone phone;

  @override
  State<PhoneApp> createState() => _PhoneAppState();
}

class _PhoneAppState extends State<PhoneApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.phone
      ..addListener(_opening)
      ..opening.addListener(_opening);
  }

  @override
  void dispose() {
    widget.phone
      ..removeListener(_opening)
      ..opening.removeListener(_opening);
    super.dispose();
  }

  /// Opens the chat a notification asked for, once the chats are known.
  void _opening() {
    final phone = widget.phone;
    final daemon = phone.daemon;
    final id = phone.opening.value;
    final context = _navigator.currentContext;
    if (id == null || daemon == null || context == null) return;
    final chat = daemon.chats[id];
    if (chat == null) {
      daemon.addListener(_opening); // the list may not be in yet
      return;
    }
    daemon.removeListener(_opening);
    phone.opening.value = null;
    _navigator.currentState!.popUntil((r) => r.isFirst);
    unawaited(openPhoneChat(context, phone, chat));
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    title: 'Nushi',
    debugShowCheckedModeBanner: false,
    theme: _phone(const NushiTheme(Tokens.light).toThemeData()),
    darkTheme: _phone(const NushiTheme(Tokens.dark).toThemeData()),
    // The Mac's transcript and controls are drawn for a desk: larger text,
    // and targets for a finger, on a phone.
    builder: (context, child) => TouchTargets(
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.15,
        child: child!,
      ),
    ),
    home: ListenableBuilder(
      listenable: widget.phone,
      builder: (context, _) => !widget.phone.loaded
          ? const SizedBox.shrink()
          : widget.phone.daemon == null
          ? PairScreen(widget.phone)
          : ChatsScreen(widget.phone),
    ),
  );
}

/// Material's touch sizes for a phone, over the Mac's theme.
ThemeData _phone(ThemeData d) => d.copyWith(
  materialTapTargetSize: MaterialTapTargetSize.padded,
  visualDensity: VisualDensity.standard,
  platform: TargetPlatform.iOS,
);
