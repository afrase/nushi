import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';

/// The phone's web app (ADR 0054): `flutter build web -t
/// lib/phone_main.dart` (make web).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = PhonePlatform();
  unawaited(platform.registerWorker());
  final phone = Phone(platform);
  unawaited(phone.start());
  runApp(PhoneApp(phone));
}
