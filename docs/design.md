# Nushi's design guide

The one page to read before any work on the app's UI: what to draw a view with, and the rules it keeps. It's distilled from the code (`app/lib/theme/`, `app/lib/controls*.dart`, `app/lib/widgets.dart`) and the ADRs, which say why; it adds no rule of its own. When a UI rule changes, change this page in the same commit.

Three things hold it:

- **`tools/design-check`** (in `make lint-dart`) fails on code that goes around the shared pieces: a raw `Tooltip(`, a Material button, an `AlertDialog(` outside `nushiDialog`, a tooltip's shortcut in brackets or after spaces, a `Color(0x…)` or `Colors.<name>` (not `transparent`), a `fontSize:` number, a `Duration(milliseconds: …)` (`Motion` or `Waits` instead; in the controls' files too). A deliberate use takes `// design: <why>` on its line or alone on the line above.
- **`corners_test.dart`** fails on a corner that isn't a radius token (ADR [0110](adr/0110-corners-come-from-the-theme.md)); **`tokens_test.dart`** holds every theme's text to AA on its fills, and a field's hint to 3:1 and a clear step under its value.
- **The gallery**: `make gallery` draws every shared control in every state, one sheet per group, dark and light, to `app/build/gallery/` (`app/test/gallery/sheets.dart`); `gallery_test.dart` keeps the buttons', the small controls' and the fields' sheets as goldens, so a change to a component shows in review. A sheet forces each state with `ShowLook`. Add a new shared piece to a sheet.

## Tokens

### Colours (`theme/tokens.dart`, ADR [0086](adr/0086-color-themes.md), [0111](adr/0111-surfaces-and-floating-panes.md))

Every colour is a token of `Tokens`; a theme changes values, never names. Read them as `NushiTheme.of(context).t`.

**Surfaces**, told apart by fill, a step at a time, never by an outline (ADR [0111](adr/0111-surfaces-and-floating-panes.md)):

| Token | Fills |
|---|---|
| `window` | the window behind everything; the sidebar sits on it |
| `base` | a pane: the main area, a phone's screen |
| `raised` | a card (`cardBox`), a segmented track, what floats (`floatBox`: a menu, a dialog, a popover) |
| `lifted` | a raised bit on a card: a button, a menu field, a key's cap, a tooltip, a toast, a meter's track |
| `segment` | the picked segment of `Segmented` |
| `codeBlock` | code, sunk: a code block, a tool call's output, a diff |
| `selected` | a list's selected row (the keyboard's place) |
| `hover`, `pressed` | the tint over anything under the pointer, and while it's pressed |
| `quote` | quoted text's fill, in place of a bar down its side |

**Lines**: `line` is a hairline, only a divider inside a pane (under a header, between rows) and around the composer; `floatLine` the edge of what floats. A border stays only on a text field (`fieldBorder`, `fieldBorderHover`; `focus` with the caret, `crashed` in error) and as the focus ring.

**Text**, from strongest to faintest, three greys a clear step apart (at least 6 in L*, `tokens_test`; `textMuted` sits at AA on the fills it's on, `textSecondary` halfway to `text`). A named theme keeps its published colours, so four sets keep two greys nearly as one: Tokyo Night's (its own fg_dark and #9AA5CE; Day's text and AA floor sit together), Catppuccin Latte's (its Text, and Subtext1 and Subtext0 taken to AA land on it) and Solarized's dark set (its greys taken to AA land within 7 of each other).

| Token | For |
|---|---|
| `text` | body text, a value, a title, an open row's label |
| `textSecondary` | a row's title at rest, a label beside a value, a tooltip's words, an icon button's icon |
| `textMuted` | meta and small print: an age, a count, a description under a row, an empty state |
| `hint` | a field's hint, an example of what goes in it: `textMuted` taken toward the field's fill to 3.5:1 (`hintOn(fill)` for a box on another fill, as the composer's), a clear step under a typed value, so it never reads as typed |
| `faint` | a grey mark that stands back: the empty window's logo, a rail's dashes, the part of a meter that counts for nothing |
| `link` | `LinkText` only |
| `onAccent` | on the accent's fill |

**The accent**: `accent` fills (a primary button, a switch that's on; `accentPressed` pressed), `accentSoft` is its tint (the open row, a lit toggle, a choice to make), `accentInk` is the accent as text, an icon, or the focus ring (`focus`), since `accent` is too dark for that on dark surfaces.

**States**, each an ink and a soft fill for its pill (`PhasePill`): `running` (on `accentSoft`), `needs`/`needsSoft` (waiting on the user; a warning), `done`/`doneSoft`, `crashed`/`crashedSoft` (failed; destructive), `idle` (off, asleep). A state that asks for nothing is `textSecondary` on `raised`.

**Shadows**: `shadow`, and `floatShadow` under what floats (twice as deep on a dark set); `scrim` behind an image opened whole.

**The transcript's own**: `userBand*` (your message's bubble), `agentText`, `inlineCode`/`inlineCodeText`, `toolAccent`, `subagentTint`/`subagentAccent`, `findingsAccent`, `selectionBar*`, `shine`/`shineBand` (what's still going). **Marks**: `claude`, `ante`, `ompPlug`, `pi`, `pig`, `monogramText`, `gold`, `avatars` (people's and chats' colours). **Code**: `syntax` by `Capture`, `terminal` (ANSI), `diff`.

A new colour is a new token, with a value in every built-in theme and a line in `theme_file.dart` (ADR [0086](adr/0086-color-themes.md)).

### Type (`NushiTheme.ui`, `NushiTheme.code`, ADR [0114](adr/0114-app-and-code-fonts.md))

Text is set with `theme.ui(color, size:, weight:)` (the App font, IBM Plex Sans unless picked) or `theme.code(color, size:)` (the Code font, JetBrains Mono unless picked; ligatures off). Never a `TextStyle(fontSize: …)` of a view's own.

| Size | For |
|---|---|
| 20 w600 | a Settings page's title |
| 15 w600 | a dialog's title (the theme's) |
| 14 | the transcript's prose (on 22), the chat header's title (semibold), a large control's label, the composer's text |
| 13 | body text and a control's label (`ControlSize.text`) |
| 12 | meta: a row's description, a muted line, a tooltip, a compact picker |
| 11.5 | small print: a group's name (semibold, `textMuted`), a count in a pill |
| 11 | a key hint (`keyHint`, code) |

Nothing is set between the steps: a size that was (12.5, 13.5, 10.5) went to the nearest, and a tie to the smaller, but a control's label, which is 13 (`PillButton`, a pill `MenuField`, `SendButton`, the selection bar's actions). The theme picker's small picture of the app sets these steps at its own scale. Code is 13 in an editor and 12 in the transcript's blocks and tool rows. The phone's text is larger (`phoneText`, 16; 14 for a bar's words). Labels of controls are medium (w500); an open row's or a picked segment's label is semibold.

### Spacing (`NushiTheme`, ADR [0072](adr/0072-the-chat-areas-spacing.md), [0111](adr/0111-surfaces-and-floating-panes.md))

| Constant | Value | Between |
|---|---|---|
| `windowPad` | 8 | the window's edge and the pane |
| `paneGap` | 8 | panes side by side |
| `gutter` | 24 | a side of the transcript, the composer, the chat header |
| `barGap` | 12 | controls in a bar |
| `groupGap` | 24 | groups of controls in a bar |
| `iconGap` | 2 | icon buttons, which carry their own padding |
| `menuPad` | 5 | a menu's edge and its rows |

Fixed heights: a header `PaneHeader.height` 56 (with a hairline under it, no fill), Changes' bar 44, a tool call's row 36, a sidebar row 34, a settings row 46 at least, a menu row 30, the composer's row 32. The transcript's column is `chatWidth` 800 at most; the details panel 320. The phone keeps its own values (`TouchTargets`, every target 44).

### Corners (`NushiTheme`, ADR [0110](adr/0110-corners-come-from-the-theme.md))

Every rounded corner is one of these, or `NushiTheme.inner(outer, gap)` for a shape set inside a rounded one (its parent's radius less the gap, so the curves stay parallel):

| Token | Value | For |
|---|---|---|
| `tag` | 4 | a key hint, a branch's name, a loading bar, a checkbox |
| `control` | 8 | a compact control, an icon button, a row's hover and selected fill, a tool row, a code block, a diff, an image |
| `card` | 12 | a card, a settings group, a toast |
| `panel` | 14 | a pane, a menu, a dialog, a popover, a message's bubble, the composer |
| `pill` | 999 | round ends: chips, badges, counts, `PillButton`, `RoundButton`, a thin bar |

A row one line high is never a card (12 on 28 makes a lozenge). What isn't a corner (a dot, a scrollbar's thumb, an icon's geometry) says `// not a corner: <why>`.

### Control sizes (`theme/sizes.dart`, ADR [0122](adr/0122-control-sizes-by-place.md))

A control's size comes from where it sits, never from the call: a `ControlScale` above it says, and without one it's `regular`.

| Size | Height | Label | Ends | Icon | Narrowest | Where |
|---|---|---|---|---|---|---|
| `compact` | 26 | 13 | 10 | 14 | — | the details panel, a list's or table's row, a menu's row, a one-line toast, a narrow bar |
| `regular` | 30 | 13 | 12 | 14 | — | everywhere else: a bar, a card, a settings row, a form; every text field |
| `large` | 34 | 14 | 16 | 15 | 80 | a dialog's actions (`nushiDialog` sets it), a view's main call to action |

`Button`, `MenuButton`, `SplitButton`, `SendButton`, a filled `MenuField`, `Segmented` and `LineSlider` follow it; corners scale with the height. These keep their own sizes, set by what they sit in: the composer's pills and round buttons (32), a tool row's small pills (24), `IconTap` (26; 32 in a header), `WideButton` (38, its corners its height's share all the same: `ControlSize.radiusFor`), menu rows (30), settings rows (46). A new dense place says `ControlScale.compact`, or its buttons grow.

### Motion (`motion.dart`, ADR [0102](adr/0102-loops-run-on-a-pulse-only-in-front.md))

| `Motion.` | Value | For |
|---|---|---|
| `quick` | 120 ms | a crossfade of text or colour, a button swapping |
| `standard` | 200 ms | size: opening, folding, bars sliding |
| `enter` | 240 ms | coming in: panes, a toast |
| `exit` | 160 ms | going (two-thirds of coming in) |
| `settle` | curve | entering and moving |
| `size` | curve | heights and widths |
| `leave` | curve | leaving |

What waits, where several places wait alike, is `Waits.` (`motion.dart`; not motion, so Reduce Motion leaves it): `loading` 150 ms before a load's loading look shows, `typing` 250 ms of a pause in typing before it's acted on, `slow` 300 ms before a call that shows nothing says it's running, `save` 500 ms before a draft is written.

No view writes `Duration(milliseconds: …)`: `tools/design-check` flags it outside `motion.dart` and the theme's files, the controls' included. A duration that is no step of either, its own thing (a loop's beat on `pulseClock`, how long a state shows, a one-off flourish such as a check drawing itself, a hover's grace, a poll), keeps its number with `// design: <why>`.

Input never waits: the state changes at once and motion is only drawn; a second press reverses from where the motion is. Exits are faster than entries. Under `reduceMotion` sizes and places jump (a press's tint stays). Nothing runs at rest: what loops for as long as a state lasts repaints from `pulseClock` (20 Hz, only while Nushi is in front). The transcript's width never eases: lay out once at the final width and glide by a transform.

## Components

Everything clickable is one of these (`controls.dart` and its parts, ADR [0049](adr/0049-controls-look-like-controls.md)); all show the pointing hand, take the keyboard's focus with a ring, press on Enter and Space, show a press at once (before what it does is done), and are disabled with no `onTap`/`onPressed`. **Plain text is never clickable.**

| Piece | Use it for | Not for |
|---|---|---|
| `Button` | an action. Kinds: `primary` (the one main action of a dialog, card or bar: accent fill), `secondary` (every other: `lifted`), `quiet` (one that stands back beside a filled one: an inline box's Cancel), `destructive` (deletes or loses something: red on `lifted`), `danger` (red on its soft fill, beside a dialog's own Done, as Claude desktop's Clear all). `icon`, `hint` (a shortcut after the label), `menu` (a ▾) | going somewhere (`LinkText`); more than one primary in a place |
| `RunButton` (`widgets.dart`) | a `Button` whose action is a call: off while it runs, its error shown, `running` its label meanwhile | a call that shows its own progress |
| `MenuButton` | an action with choices ("Start work ▾") | a value (`MenuField`) |
| `SplitButton` | an action and a ▾ of how it goes ("Squash and merge") | |
| `SendButton` | every "send to the agent" (Send, Fix checks, Send all): arrow and label on the accent | |
| `WideButton` | a row-wide action on the window or a pane (the sidebar's New chat), its key as a `KeyCap` | inside a card or a bar |
| `MenuField` | a value picked from a list: its value and a ▾ on `lifted`. `compact` (no fill) in a header or a row; `pill` in the composer's row | an action (`MenuButton`) |
| `Segmented` | one of a few: the chat header's Chat, Changes, Pull request (`roomy`), and a value a form saves (a server's scope, a review's verdict). `onCard` on a card or dialog | other views of one thing (`PlainTabs`, ADR [0071](adr/0071-one-look-for-tabs.md)) |
| `PlainTabs` (`plain_tabs.dart`) | views of the same thing: Preview and Source, a pull request's sections, History's filters | a form's value |
| `IconTap` | an icon alone where it's clear in its place (close, back, reload beside "Updated 3m ago"), always with a tooltip. `held` keeps its tint while what it toggles is on; `lit` (accent tint and ink) a toggle that must read as on at a glance; `danger` solid red where stopping must stand out (a running server's Stop); `.working` a spinner that turns to ✕ under the pointer; `padding: IconTap.header` in a header (32 square); `.line` a drawn `LineIcon` (ADR [0072](adr/0072-the-chat-areas-spacing.md)) | an action the icon doesn't say (a `Button` with words) |
| `MenuIcon` | an icon that opens a menu (⋯); `heldOpen` tints it while open | |
| `LinkText` | going somewhere, in or beside text ("Settings › Agents"); on the phone, an action in a line of text (`PhoneLink`) | an action on the Mac (a `Button`) |
| `PillLink` | a link shown as a pill (a chat's Jira issue): `accentInk` on `accentSoft` | |
| `PillButton` | a pill on a card: the composer's Queue and Stop and send; `small` in a tool row (Preview, Open), `on` while what it opens is open | a dialog's or a bar's action |
| `RoundButton` | a round icon button on a card: `plain` (the composer's +), `primary` (Send) | |
| `Tap` | a list's row or a tab: a hover tint, `selected`, `fill` (a chat's colour), no ripple; focus shows as the tint | a button (use one) |
| `Pressable` | the base of every control: hover, focus, press and its tooltip, for a new shared control in `controls*.dart` | a view's one-off button |
| `PhoneIcon`, `PhoneButton` (`phone/ui.dart`) | the phone's icon button (44 square, a round tint pressed) and its full-width button (`primary` on the accent, `destructive` in red): on `Pressable`, so the focus ring and a press at once, as the Mac's | the Mac (`IconTap`, `Button`) |
| `Swatch`, `DragGrip`, `KeyCap`, `keyHint`, `LineSlider` | a colour to pick; what can be dragged; a key's cap beside its action; a shortcut in small code; a value along a line | |
| `SettingsSwitch` | an on/off, Settings' size everywhere; `run` makes it a call | |
| `nushiDialog` (`widgets.dart`) | every dialog: a title, content 460 wide (`width` for a form), actions large at the right; `onClose` puts a × at the title's end (a list to manage) | an `AlertDialog` of a view's own |
| `confirm` | a yes/no question: Cancel and the action, `destructive` in red (Cancel then has the focus) | |
| `cardBox`, `floatBox`, `framed` (`theme.dart`) | a card on a pane; what floats (hairline, soft shadow); a picture that needs an edge | an outlined box |
| `PhasePill`, `NeedsYou`, `StatePill`/`ItemStatePill` | a state in words: its ink on its soft fill; "Needs you" on a card that waits; a pull request's state | a tinted card |
| Chips: `ColorChip`, `GitHubLinkChip`, `JumpChip`, `FileChip`, `SideChip` | a chat's colour as a small lozenge; a GitHub link with its state; what floats over the text; a file; a side chat | a stripe down a side |
| `Menu`, `MenuEntry` (`menu.dart`) | the app's one menu, opened at once from one of the controls above or a row's right-click: rows with an icon, a `detail`, a `shortcut`, `checked`, `danger` (red), `submenu`, `heading`; a filter field past ten choices | a menu opened from bare text |
| `tooltip()`, `withKey()` | a tooltip: `Pressable`/`Tap`/`IconTap` take `tooltip:`, anything else is wrapped in `tooltip(context, words, child)`. A shortcut goes with `withKey('Forward', '⌘]')` | `Tooltip(` itself; "(⌘K)" |
| Toasts: `showError`, `tryOrShow`, `runAndSay`, `Runner` (`widgets.dart`) | an error, a call's error, a slow call's "running" then "done": a snack bar, `lifted` with a hairline, 420 wide on the Mac | a dialog for news |
| `Notice`, `FloatBar` | a problem or an old list above it (`needsSoft`); what floats over the pane under its header (the daemon's lost, an update waiting) | a bar across the pane's top |
| `SettingsPage`, `SettingsGroup`, `SettingsRow` (`settings_rows.dart`) | Settings' pages: a title, rounded groups of rows, each a label (and a muted line) at the left, its control at the right | |

## Patterns

- **Dialogs**: `nushiDialog`: a title that says what's asked ("Delete this chat?"), content in plain sentences, actions at the right, Cancel first and the one main action last. The main action is `primary`; one that deletes or loses something is `destructive` and says what it does ("Delete", not "OK"). The main action has the focus, unless it deletes or loses something: then Cancel has it, so Enter never deletes, as the Mac's alerts (`confirm(destructive: true)`, the chat's Delete, Clean up). A list to manage has a × and a Done. Esc cancels.
- **Cards in the transcript** (ADR [0111](adr/0111-surfaces-and-floating-panes.md)): a tool call's row is one line on `raised`, corners `control`; open, a card with its output in a `codeBlock` block. A card that waits on you (a permission, a question, the trust card) is a `cardBox` with an amber mark and `NeedsYou`; its one main answer solid, the rest secondary. Nothing is outlined, and nothing in a card is a card.
- **Empty states**: a muted line where the content would be, in `textMuted`: "None" in a settings group (`SettingsGroup.empty`), "No chats" in a group, "Nothing matches" under a filter, "Not shown: a.png is binary" in place of a file. It's a phrase, never a sentence: no full stop, even when a clause says what to do after a colon ("No inline comments: select lines in Files to add some"). An error or an explanation is a sentence and keeps its stop. A view with nothing open offers its main action large (the empty window's New chat).
- **Settings rows**: label left (13, `text`), an optional description under it (12, `textMuted`), the control at the group's right edge; a group is a card with hairlines between rows. Copy is short (the owner's rule).
- **Headers and bars**: 56 high, a hairline under, no fill; the title semibold 14 at the gutter, icon buttons 32 square at the end, 12 from the edge; controls `barGap` apart, groups `groupGap`. Empty space in a header moves the window (ADR [0080](adr/0080-no-title-bar.md)). Nothing a button opens changes the width of the bar it's in.
- **Hover and focus**: under the pointer a control takes `hover` over its fill (a filled primary goes a shade lighter), pressed `pressed`; focused from the keyboard it wears the 2-point ring in `focus` (`focusRing`); on the accent's fill (a primary button, `SplitButton`, `SendButton`, a primary `RoundButton`) the ring sits just outside it, with a 2-point line of `onAccent` at its edge (`accentFocusRing`), since a light set's `focus` is within a shade of `accent`. A row (`Tap`) shows focus as the hover tint. A toggle that's on is `lit` or `held`, never a different shape.
- **Disabled**: a control without its action is drawn at 45% (`_faded`; `PillLink` too), with no hand and no focus; an `IconTap` greys its icon instead (Claude desktop's Back with nowhere to go); a field's border goes to `line`.
- **Words**: the glossary's (`docs/glossary.md`); sentence case; a shortcut in a tooltip via `withKey`.

## The owner's rules

- **Never a coloured stripe down the side** of a card, row or group: use a chip, an icon or a fill (ADR [0111](adr/0111-surfaces-and-floating-panes.md); a chat's colour is a `ColorChip`, a quote is a `quote` fill).
- **State cues are unmistakable, not faint tints.** A running server's Stop is solid red (`IconTap(danger:)`); a toggle that's on is `lit`; a waiting card has its mark and a pill. The composer's own Stop is the neutral square in a circle the owner kept (ADR [0111](adr/0111-surfaces-and-floating-panes.md)).
- **A show/hide toggle never moves when pressed** (ADR [0111](adr/0111-surfaces-and-floating-panes.md), [0118](adr/0118-title-buttons-stay-put.md)): the header's buttons and the sidebar's button stay put whatever they show or hide.
- **A named third-party theme uses its published colours** and known variants (ADR [0086](adr/0086-color-themes.md)); only Nushi's own roles pick other steps of its palette.
- **Settings copy is short**: a label and at most a line under it.
- **Tooltips are muted, the key fainter, no brackets**: `textSecondary` words on `lifted`, the key in `tooltipKey` after an en space (`withKey`), as Claude desktop draws them.
- **Copying Claude desktop means its actual behaviour**, from the app or the owner's screenshots, not a guess at it (ADR [0094](adr/0094-browser-tabs-for-local-web-servers.md)'s amendments).
- **Nushi is unopinionated**: options and warnings over enforced flows.

## Known inconsistencies

Follow-ups, found while writing this page and drawing the gallery. Two small bugs it showed were fixed with it: a disabled `IconTap(danger:)` or `IconTap(lit:)` kept its fill and lost its mark, and a toast's action was all but invisible on a light set.

- **Two kinds of toast**: most are a plain snack bar, with Material's `SnackBarAction` where there's an action (the side chat's Go to chat); the archived side chat's is the app's own row of compact buttons (Undo, ×).
