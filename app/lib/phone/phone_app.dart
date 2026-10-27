import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/phone/keyboard.dart';
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

class _PhoneAppState extends State<PhoneApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();

  /// A route the browser asks for (its address, its history) is taken
  /// here and dropped, before the app's Navigator would push it.
  @override
  Future<bool> didPushRouteInformation(RouteInformation _) async => true;

  @override
  void initState() {
    super.initState();
    // Before MaterialApp's own observer, which would push the route.
    WidgetsBinding.instance.addObserver(this);
    // The browser's back (iOS's edge swipe) goes back a screen in the app,
    // and at its root does nothing.
    widget.phone.platform.onBack = () => _navigator.currentState?.maybePop();
    widget.phone
      ..addListener(_opening)
      ..opening.addListener(_opening);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    // and targets for a finger, on a phone. Every screen, dialog and sheet
    // keeps clear of the on-screen keyboard.
    builder: (context, child) => KeyboardInset(
      widget.phone.platform.keyboard,
      child: TouchTargets(
        child: MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.15,
          child: child!,
        ),
      ),
    ),
    // One root, whatever the address says: pairing until paired, then the
    // chats (pairing gives way to them, Forget brings it back), never a
    // screen on top of another root.
    home: _Root(widget.phone),
  );
}

class _Root extends StatefulWidget {
  const new(this.phone);

  final Phone phone;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool? _paired;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.phone,
    builder: (context, _) {
      final phone = widget.phone;
      if (!phone.loaded) return const SizedBox.shrink();
      final paired = phone.daemon != null;
      if (_paired != null && _paired != paired) {
        // Paired or forgotten: what was on top of the root goes.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        });
      }
      _paired = paired;
      return paired ? ChatsScreen(phone) : PairScreen(phone);
    },
  );
}

/// Material's touch sizes for a phone, over the Mac's theme.
ThemeData _phone(ThemeData d) => d.copyWith(
  materialTapTargetSize: MaterialTapTargetSize.padded,
  visualDensity: VisualDensity.standard,
  platform: TargetPlatform.iOS,
);
