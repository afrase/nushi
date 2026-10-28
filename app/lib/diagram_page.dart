import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nushi/mermaid.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// What draws a Mermaid file in the preview pane: on the Mac a WKWebView
/// of the app's mermaid.html ([WebKitDiagram]); tests make their own
/// ([newDiagramHost]).
abstract interface class DiagramHost {
  /// The view; built once and kept.
  Widget view(BuildContext context);

  /// Draws [source] in place of what showed (or its source and the error,
  /// when it doesn't parse).
  Future<void> show(
    String source, {
    required bool dark,
    required Color background,
    required Color foreground,
  });

  void dispose();
}

/// Makes the [DiagramHost] a preview pane uses.
DiagramHost Function() newDiagramHost = WebKitDiagram.new;

/// The app's mermaid.html in a WKWebView, its script the pinned
/// mermaid.min.js beside it, and nothing else: any other navigation is
/// refused (Mermaid's strict level has no links or clicks anyway).
class WebKitDiagram implements DiagramHost {
  new() {
    final nav = WebKitNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(
      nav.setOnNavigationRequest(
        (r) => !_loaded && r.url == Uri.file(_page).toString()
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ),
    );
    unawaited(nav.setOnPageFinished(_finished));
    unawaited(_c.setPlatformNavigationDelegate(nav));
    unawaited(_c.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(_load());
  }

  final _c = WebKitWebViewController(
    const PlatformWebViewControllerCreationParams(),
  );
  String _page = '';
  bool _loaded = false;
  String? _pending; // the script to run once loaded

  Future<void> _load() async {
    _page = await diagramPage();
    if (_page.isEmpty) return;
    await _c.loadFileWithParams(
      WebKitLoadFileParams(
        absoluteFilePath: _page,
        readAccessPath: _page.substring(0, _page.lastIndexOf('/')),
      ),
    );
  }

  void _finished(String url) {
    _loaded = true;
    if (_pending case final js?) {
      _pending = null;
      unawaited(_c.runJavaScript(js).catchError((_) {}));
    }
  }

  @override
  Widget view(BuildContext context) =>
      PlatformWebViewWidget(WebKitWebViewWidgetCreationParams(controller: _c))
          .build(context);

  @override
  Future<void> show(
    String source, {
    required bool dark,
    required Color background,
    required Color foreground,
  }) async {
    final opts = {
      'dark': dark,
      'background': cssColor(background),
      'foreground': cssColor(foreground),
      'center': true,
    };
    // Its promise isn't a result WebKit hands back.
    final js = 'show(${jsonEncode(source)}, ${jsonEncode(opts)}); void 0';
    if (!_loaded) {
      _pending = js;
      return;
    }
    await _c.runJavaScript(js);
  }

  @override
  void dispose() {
    unawaited(_c.loadRequest(LoadRequestParams(uri: Uri.parse('about:blank'))));
  }
}

/// A Mermaid file in [host] (made once), following [watch]: drawn again
/// each time the file or the app's theme changes. Until the first answer,
/// a note in its place.
class DiagramView extends StatefulWidget {
  const new({required this.host, required this.watch, super.key});

  final DiagramHost host;
  final FileWatch watch;

  @override
  State<DiagramView> createState() => _DiagramViewState();
}

class _DiagramViewState extends State<DiagramView> {
  Object? _shown; // (the file as sent, dark)

  @override
  void initState() {
    super.initState();
    widget.watch.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _changed();
  }

  @override
  void dispose() {
    widget.watch.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final f = widget.watch.file;
    if (!mounted || f == null || f.missing || f.tooLarge) return;
    final t = NushiTheme.of(context).t;
    final dark = t.brightness == Brightness.dark;
    final shown = (f, dark);
    if (shown == _shown) return;
    final first = _shown == null;
    _shown = shown;
    unawaited(
      widget.host.show(
        utf8.decode(f.data, allowMalformed: true),
        dark: dark,
        background: t.base,
        foreground: t.text,
      ),
    );
    if (first) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_shown == null) {
      return ListenableBuilder(
        listenable: widget.watch,
        builder: (context, _) =>
            previewStatus(context, widget.watch) ?? const SizedBox.shrink(),
      );
    }
    return widget.host.view(context);
  }
}
