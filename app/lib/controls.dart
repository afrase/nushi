import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:nushi/line_icons.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';

export 'package:nushi/line_icons.dart';

part 'controls_buttons.dart';
part 'controls_menus.dart';
part 'controls_pills.dart';
part 'controls_press.dart';
part 'controls_segmented.dart';
part 'controls_slider.dart';
part 'controls_small.dart';

// The app's controls: one look for each kind of thing that can be
// pressed, so what's clickable looks it. [Button] for an action,
// [MenuField] for a value picked from a list, [LinkText] for going
// somewhere from within text, [IconTap] where an icon alone is clear,
// [DragGrip] where something can be moved. Plain text is never clickable;
// all of these show the pointing hand. Their parts: `controls_press`
// (pressing, touch targets, and [Tap] for rows and tabs),
// `controls_buttons`, `controls_menus`, `controls_small` (links, icons,
// swatches, grips, key hints and caps), `controls_slider` ([LineSlider]),
// `controls_segmented`
// ([Segmented]) and `controls_pills` ([PillButton] and [RoundButton], a
// card's own buttons); what they share is here.

/// A button's and a field's height.
const controlHeight = 26.0;

/// How a control is, to draw it: under the pointer, focused from the
/// keyboard, pressed (the pointer down on it: a click shows at once, before
/// what it does is done), pressable at all. A pressed control is also
/// hover, so one drawn only for hover still answers a press.
typedef ControlLook = ({bool hover, bool focus, bool pressed, bool enabled});

/// The ring a focused control wears, over its border ([radius]: a
/// control's corners unless given).
BoxDecoration? focusRing(Tokens t, ControlLook look, {BorderRadius? radius}) =>
    look.focus
    ? BoxDecoration(
        border: Border.all(color: t.focus, width: 2),
        borderRadius: radius ?? BorderRadius.circular(NushiTheme.control),
      )
    : null;

/// The tint under a control: deeper while it's pressed.
Color _tint(Tokens t, ControlLook look) => look.pressed ? t.pressed : t.hover;

/// [child] faded while [look] is disabled.
Widget _faded(ControlLook look, Widget child) =>
    look.enabled ? child : Opacity(opacity: 0.45, child: child);
