import 'package:flutter/widgets.dart';
import 'package:nushi/text_width.dart';

/// A name with the folder that tells it from a twin before it, as the path
/// it is: "me/cubby" for a sidebar's twin projects, "site/plan.md" for two
/// open files of one name (issue 119; `docs/design.md`'s Words). [parent]
/// ends with its slash ('' for none) and is drawn in [parentStyle], muted
/// over [style]. The name is never what's cut: it keeps its width (cut
/// only where it alone is too wide), and the parent gives way in its
/// middle ("tenants-east/…/cubby", [pathThatFits]), keeping its start,
/// where twins whose parents share a name differ, and its end; where
/// fewer than four of its characters would show it shows none (the name
/// alone, never a lone "…"; a tooltip says the folder).
class PathName extends StatelessWidget {
  const new(
    this.parent,
    this.name, {
    required this.style,
    required this.parentStyle,
    super.key,
  });

  final String parent;
  final String name;
  final TextStyle style;
  final TextStyle parentStyle;

  @override
  Widget build(BuildContext context) {
    final named = Text(
      name,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (parent.isEmpty) return named;
    final muted = style.merge(parentStyle);
    return LayoutBuilder(
      builder: (context, box) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: LayoutBuilder(
              builder: (context, room) => Text(
                pathThatFits(context, parent, muted, room.maxWidth),
                maxLines: 1,
                softWrap: false,
                style: muted,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth),
            child: named,
          ),
        ],
      ),
    );
  }
}
