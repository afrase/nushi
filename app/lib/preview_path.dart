import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart' show relativeIn;
import 'package:nushi/folder_button.dart' show tildePath;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/widgets.dart';

// The line over a file's preview, as Claude's desktop app has it (ADR 0106):
// the file's path, which a click copies, and at its right end the source
// button, in the place of the Preview and Source tabs.

/// What [path] (relative to [folder], or absolute) copies as: relative to
/// the chat's folder when inside it, else absolute.
String copiedPath(String folder, String path) => relativeIn(folder, path);

/// [path] as the path line shows it: [copiedPath], from ~ outside the
/// folder, its parts apart ("docs / roadmap.md").
String shownPath(String folder, String path) {
  final copied = copiedPath(folder, path);
  final shown = copied.startsWith('/') ? tildePath(copied) : copied;
  return plainPath(shown).split('/').join(' / ').trimLeft();
}

/// The path line: [path] in a quiet line, tinted under the pointer; a click
/// copies it and says so. [trailing] sits at its right end (the source
/// button). [status] sits between the two, at the path's right end (the
/// Files pane's word on the file's change marks, ADR 0131): the path is
/// cut before it is, so it stays whole beside the buttons. [inset], [end]
/// and [top] are its sides' room.
class PathLine extends StatelessWidget {
  const new({
    required this.folder,
    required this.path,
    super.key,
    this.trailing,
    this.status,
    this.inset = PathLine.textInset - textPad,
    this.end = 4,
    this.top = 6,
  });

  final String folder;
  final String path;
  final Widget? trailing;
  final Widget? status;
  final double inset;
  final double end;
  final double top;

  /// Where the path's text starts from the line's left by default: the
  /// preview's text's edge.
  static const textInset = 28.0;

  /// The room left of the text inside its tint.
  static const textPad = 6.0;

  /// The least of the path that shows beside its [status].
  static const pathLeast = 56.0;

  /// The least room its [status] shows in.
  static const statusLeast = 48.0;

  Future<void> _copy(BuildContext context) => tryOrShow(context, () async {
    await Clipboard.setData(ClipboardData(text: copiedPath(folder, path)));
    if (context.mounted) showToast(Toasts.maybeOf(context), 'Copied');
  });

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, top, end, 0),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          spacing: 8,
          children: [
            Expanded(
              child: Pressable(
                onTap: () => _copy(context),
                tooltip: 'Copy path',
                // Across the line, as Claude's is, its text where it was.
                builder: (context, look) => Container(
                  // The line's width: a touch target centres what it holds.
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: textPad,
                    vertical: 4,
                  ),
                  decoration: look.hover
                      ? BoxDecoration(
                          color: look.pressed ? t.pressed : t.hover,
                          borderRadius: BorderRadius.circular(
                            NushiTheme.control,
                          ),
                        )
                      : null,
                  foregroundDecoration: focusRing(t, look),
                  child: Text(
                    shownPath(folder, path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(t.textSecondary),
                  ),
                ),
              ),
            ),
            // Squeezed past a pill's least, the path alone.
            if (status case final status?
                when box.maxWidth - pathLeast - 8 >= statusLeast)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: box.maxWidth - pathLeast - 8,
                ),
                child: status,
              ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The source button, `</>`: shows the file's source, or its rendering
/// again. While the source shows it's lit (the accent), its tooltip "View
/// preview".
class SourceButton extends StatelessWidget {
  const new({required this.source, required this.onChanged, super.key});

  final bool source;
  final ValueChanged<bool> onChanged;

  /// What its tooltip says: what it'll do.
  static String tooltip({required bool source}) =>
      source ? 'View preview' : 'View source';

  @override
  Widget build(BuildContext context) => IconTap.line(
    LineIcon.source,
    tooltip: tooltip(source: source),
    lit: source,
    onTap: () => onChanged(!source),
  );
}
