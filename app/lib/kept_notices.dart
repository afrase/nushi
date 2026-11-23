import 'package:flutter/material.dart';

import 'package:nushi/kept_trouble.dart';
import 'package:nushi/toast.dart';

/// How long a kept file's notice stays, unless closed: long enough to
/// read two sentences and the name of the copy kept.
const keptNoticeFor = Duration(seconds: 12);

/// Says each trouble met reading a file the app keeps ([keptTroubles]),
/// once, as a closable failure toast, from when the window is up: on the
/// Mac and Linux, under the window's [ToastHost] (the phone keeps no
/// files). One that comes later (a file first read later, or read again
/// before a save) is said when it comes.
class KeptNotices extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<KeptNotices> createState() => _KeptNoticesState();
}

class _KeptNoticesState extends State<KeptNotices> {
  /// How many of [keptTroubles] were said.
  int _said = 0;
  bool _due = false;

  @override
  void initState() {
    super.initState();
    keptTroubles.addListener(_soon);
    _soon();
  }

  @override
  void dispose() {
    keptTroubles.removeListener(_soon);
    super.dispose();
  }

  /// After the frame: a trouble may be noted while the window builds (a
  /// pref read for the first time).
  void _soon() {
    if (_due) return;
    _due = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _due = false;
      if (mounted) _say();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _say() {
    final all = keptTroubles.value;
    if (all.length < _said) _said = 0; // forgotten (a test's)
    final toasts = Toasts.maybeOf(context);
    for (final t in all.skip(_said)) {
      showFailure(
        toasts,
        keptTroubleText(t),
        duration: keptNoticeFor,
        key: ValueKey('kept ${t.file} ${t.kind.name}'),
      );
    }
    _said = all.length;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
