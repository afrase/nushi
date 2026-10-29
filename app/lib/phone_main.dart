import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:nushi/paced.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';

/// The phone's web app (ADR 0054): `flutter build web -t
/// lib/phone_main.dart` (make web).
void main() {
  // The address isn't a route: its fragment carries a pairing link or a
  // chat to open (PhonePlatform reads and clears it), and the browser's
  // history never pushes a screen (iOS showed a back button on the chats
  // when it did).
  setUrlStrategy(null);
  // A streaming reply shows as it comes, not paced: in Chrome a step of it
  // took 17 ms at the median and 29 at p90 (debug), too near a frame for
  // a phone (step 413).
  Paced.paces = false;
  WidgetsFlutterBinding.ensureInitialized();
  final platform = PhonePlatform();
  unawaited(platform.registerWorker());
  final phone = Phone(platform);
  unawaited(phone.start());
  runApp(PhoneApp(phone));
}
