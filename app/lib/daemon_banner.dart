import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';

/// The banner over the app while the connection to the daemon is lost: only
/// after [grace] without it, so a blip shows nothing. It slides down over
/// 200 ms, "reconnecting…" shining; once the daemon is back it turns green
/// and says "Reconnected" for [backFor], then slides up. A restart the user
/// asked for (Daemon.restarting) shows at once, wherever it was asked from,
/// and says "Daemon restarted" once the new one answers; one that failed
/// just goes (its caller says why). With Reduce Motion the same, without
/// the slides.
class DaemonBanner extends StatefulWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  static const grace = Duration(milliseconds: 800);
  static const backFor = Duration(milliseconds: 1200);
  static const slideFor = Duration(milliseconds: 200);

  @override
  State<DaemonBanner> createState() => _DaemonBannerState();
}

class _DaemonBannerState extends State<DaemonBanner> with ClockRun {
  Timer? _grace; // running out while the connection is lost
  Timer? _back; // the green "Reconnected", until it goes
  bool _lost = false; // it shows the lost connection
  bool _reconnected = false; // it shows the green "Reconnected"
  bool _opening = false; // the slide's way: down, or up
  bool _restart = false; // a restart asked for: what it says
  bool _restarted = false; // the green line is a restart's

  bool get _shows => _lost || _reconnected;

  @override
  void initState() {
    super.initState();
    widget.daemon.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    widget.daemon.removeListener(_changed);
    _grace?.cancel();
    _back?.cancel();
    super.dispose();
  }

  void _changed() {
    final d = widget.daemon;
    if (d.restarting && !_restart) {
      _restart = true;
      _grace?.cancel();
      _grace = null;
      _back?.cancel();
      if (_lost || _reconnected) {
        setState(() {
          _lost = true;
          _reconnected = _restarted = false;
        });
      } else {
        _slide(open: true, then: () => _lost = true);
      }
      return;
    }
    if (_restart && !d.restarting) {
      _restart = false;
      if (d.restartFailed && d.connected) {
        // It didn't stop: nothing was lost; the caller says why.
        _slide(open: false, then: () => _lost = false);
        return;
      }
      if (_lost && d.connected) {
        setState(() {
          _lost = false;
          _reconnected = true;
          _restarted = true;
        });
        _back = Timer(DaemonBanner.backFor, () {
          _slide(open: false, then: () => _reconnected = _restarted = false);
        });
        return;
      }
    }
    if (d.restarting) return;
    if (!d.connected) {
      _back?.cancel();
      if (_lost) {
        setState(() {}); // what it says may have changed
        return;
      }
      if (_reconnected) {
        // Lost again while it said so: amber again, open (or opening).
        _reconnected = _restarted = false;
        if (_opening) {
          setState(() => _lost = true);
        } else {
          _slide(open: true, then: () => _lost = true);
        }
        return;
      }
      _grace ??= Timer(DaemonBanner.grace, () {
        _grace = null;
        _slide(open: true, then: () => _lost = true);
      });
      return;
    }
    _grace?.cancel();
    _grace = null;
    if (!_lost) return;
    setState(() {
      _lost = false;
      _reconnected = true;
    });
    _back = Timer(DaemonBanner.backFor, () {
      _slide(open: false, then: () => _reconnected = false);
    });
  }

  /// Opens or closes the banner, sliding unless Reduce Motion: [then]
  /// changes what it shows (closing, after the slide).
  void _slide({required bool open, required VoidCallback then}) {
    if (!mounted) return;
    final still = reduceMotion(context);
    setState(() {
      _opening = open;
      if (open || still) then();
    });
    if (still) return;
    runFor(DaemonBanner.slideFor);
    if (!open) {
      Timer(DaemonBanner.slideFor, () {
        if (mounted && !_opening) setState(then);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shows) return const SizedBox.shrink();
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final back = _reconnected;
    final color = back ? t.done : t.needs;
    final bar = Container(
      color: back ? t.doneSoft : t.needsSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      alignment: Alignment.centerLeft,
      child: Shine(
        on: !back,
        color: color,
        child: Text(
          back
              ? (_restarted ? 'Daemon restarted' : 'Reconnected')
              : _restart
              ? 'Restarting the daemon…'
              : widget.daemon.updating
              ? 'Starting the new daemon…'
              : 'Lost the connection to the daemon; reconnecting…',
          style: theme.ui(color, size: 12),
        ),
      ),
    );
    if (!running) return _opening ? bar : const SizedBox.shrink();
    const slide = Cubic(0.2, 0.8, 0.2, 1);
    final v = slide.transform(
      (ranMs / DaemonBanner.slideFor.inMilliseconds).clamp(0.0, 1.0),
    );
    return ClipRect(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: _opening ? v : 1 - v,
        child: bar,
      ),
    );
  }
}
