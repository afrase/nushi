import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/inline_edit.dart';

const _channel = MethodChannel('nushi/window');

/// Empty space at the window's top, which has no title bar to hold (the
/// content runs under the traffic lights): a drag moves the window and a
/// double click zooms it, as a title bar's would. Under what's in the bar
/// (a Stack), so a button there keeps its clicks.
class WindowDrag extends StatefulWidget {
  const new({super.key});

  /// How much room the traffic lights take at the top of the window.
  static const lights = 28.0;

  @override
  State<WindowDrag> createState() => _WindowDragState();
}

class _WindowDragState extends State<WindowDrag> {
  final _click = DoubleClick();

  void _send(String method) => _channel.invokeMethod<void>(method).ignore();

  @override
  Widget build(BuildContext context) => kIsWeb
      ? const SizedBox.shrink() // the phone's headers: no window to move
      : GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _send('drag'),
          onTap: () {
            if (_click()) _send('zoom');
          },
        );
}
