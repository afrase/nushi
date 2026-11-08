import 'package:flutter/foundation.dart';

import 'package:nushi/native.dart';

/// The modifier a platform's shortcuts are held with: the Mac's ⌘, or
/// Control.
enum CommandKey { meta, control }

/// What a platform names differently, and the key its shortcuts take
/// (ADR 0102): plain data on [Native], so a test or a render shows Linux's
/// on the Mac. Widgets read [conventions], never `defaultTargetPlatform`,
/// which says android under `flutter test`.
class Conventions {
  const new({
    required this.commandKey,
    required this.reveal,
    required this.system,
    required this.machine,
    required this.keyring,
    required this.badge,
  });

  /// The modifier of the app's shortcuts.
  final CommandKey commandKey;

  /// The action that shows a file in the file manager.
  final String reveal;

  /// The operating system's name.
  final String system;

  /// The computer the app runs on, as a sentence names it.
  final String machine;

  /// Where the system keeps passwords and tokens.
  final String keyring;

  /// The count on the app's icon.
  final String badge;
}

/// The Mac's.
const macConventions = Conventions(
  commandKey: CommandKey.meta,
  reveal: 'Show in Finder',
  system: 'macOS',
  machine: 'Mac',
  keyring: 'keychain',
  badge: 'Dock badge',
);

/// Linux's.
const linuxConventions = Conventions(
  commandKey: CommandKey.control,
  reveal: 'Show in Folder',
  system: 'Linux',
  machine: 'computer',
  keyring: 'keyring',
  badge: 'App icon badge',
);

/// The platform's conventions, as a widget reads them: the phone's web app,
/// which shares the widgets but has no native edge, keeps the Mac's.
Conventions get conventions => kIsWeb ? macConventions : native.conventions;
