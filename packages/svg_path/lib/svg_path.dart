import 'dart:ui';

/// Parses SVG path data (a path's `d` attribute) into a [Path]: every
/// command of SVG 1.1's path grammar, absolute and relative. Throws a
/// [FormatException] on data it can't read.
Path parseSvgPath(String d) {
  final path = Path();
  final s = _Scanner(d);
  var cmd = '', prev = '';
  var cur = Offset.zero, start = Offset.zero, ctrl = Offset.zero;
  while (!s.done) {
    if (s.command() case final c?) {
      cmd = c;
    } else if (cmd.isEmpty || cmd.toUpperCase() == 'Z') {
      throw FormatException('a number without a command', d, s.i);
    }
    final rel = cmd == cmd.toLowerCase();
    final base = rel ? cur : Offset.zero;
    Offset pt() => base + Offset(s.number(), s.number());
    // A control point reflected through the current point, after a
    // segment of the same kind (S after C or S, T after Q or T).
    Offset mirror(String kinds) => kinds.contains(prev) ? cur * 2 - ctrl : cur;
    final upper = cmd.toUpperCase();
    switch (upper) {
      case 'M':
        cur = start = pt();
        path.moveTo(cur.dx, cur.dy);
        cmd = rel ? 'l' : 'L'; // pairs after a moveto are linetos
      case 'L':
        cur = pt();
        path.lineTo(cur.dx, cur.dy);
      case 'H':
        cur = Offset(s.number() + base.dx, cur.dy);
        path.lineTo(cur.dx, cur.dy);
      case 'V':
        cur = Offset(cur.dx, s.number() + base.dy);
        path.lineTo(cur.dx, cur.dy);
      case 'C' || 'S':
        final c1 = upper == 'C' ? pt() : mirror('CS');
        ctrl = pt();
        cur = pt();
        path.cubicTo(c1.dx, c1.dy, ctrl.dx, ctrl.dy, cur.dx, cur.dy);
      case 'Q' || 'T':
        ctrl = upper == 'Q' ? pt() : mirror('QT');
        cur = pt();
        path.quadraticBezierTo(ctrl.dx, ctrl.dy, cur.dx, cur.dy);
      case 'A':
        final radius = Radius.elliptical(s.number().abs(), s.number().abs());
        final rotation = s.number();
        final large = s.flag(), sweep = s.flag();
        cur = pt();
        path.arcToPoint(
          cur,
          radius: radius,
          rotation: rotation,
          largeArc: large,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
        cur = start;
      default:
        throw FormatException('unknown command $cmd', d, s.i);
    }
    prev = upper;
  }
  return path;
}

class _Scanner {
  _Scanner(this.d);

  final String d;
  int i = 0;

  static final _space = RegExp(r'[\s,]*');
  static final _number = RegExp(r'[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?');

  bool get done {
    i = _space.matchAsPrefix(d, i)!.end;
    return i >= d.length;
  }

  /// The command letter at the cursor, if there is one.
  String? command() {
    if (done || !RegExp('[A-Za-z]').hasMatch(d[i])) return null;
    return d[i++];
  }

  double number() {
    done;
    final m = _number.matchAsPrefix(d, i);
    if (m == null) throw FormatException('a number expected', d, i);
    i = m.end;
    return double.parse(m[0]!);
  }

  /// An arc's flag: one digit, which may touch what follows ("a1 1 0 01 1").
  bool flag() {
    if (done || (d[i] != '0' && d[i] != '1')) {
      throw FormatException('a flag expected', d, i);
    }
    return d[i++] == '1';
  }
}
