# 0111. Surfaces, not outlines: floating panes on the window

Status: accepted, 2026-11-11.

## Context
The owner approved a mock of a fresh look (2026-11-11) and wants the app to look like it. Pass one made the corners rounder (ADR 0110). This is pass two, the frame: the window's surfaces, its shell, the sidebar and the chat's header. The rest of the app is restyled view by view after it, from this page.

## Decision
- **Things are told apart by their fill, a step at a time, not by a 1 px border.** The steps are tokens of `theme/tokens.dart`, in every theme and both brightnesses:

  | Token | What is filled with it | Nushi dark / light |
  | --- | --- | --- |
  | `window` | the window behind everything; the sidebar sits straight on it | `#131417` / `#ECEEF2` |
  | `base` | a pane: the main area, each card of the details column; a phone's screen | `#1B1C20` / `#FFFFFF` |
  | `raised` | a card on a pane or on the window (New chat, the status card), a segmented control's track, a neutral pill, a menu, a dialog | `#24262B` / `#F3F4F7` |
  | `lifted` | a raised bit on a card: a key's cap, a button or a track on a card or in a dialog | `#2F3138` / `#E6E8ED` |
  | `segment` | the picked segment of a segmented control, with a 1 px shadow under it | `#383B43` / `#FFFFFF` |

  A theme that doesn't give one gets it from its `base`, `raised` and `text`, and so does a theme file that names those but not these. `tokens_test` holds each step at least 1.8 apart (OKLab × 100; Nushi's quietest, a light card on the window, is 1.9) and text to AA on the window and on a row hovered there.
- **A hairline is `line`** (the text's color at 7% dark, 9% light), and only: a divider inside a pane (under a header, between the transcript and a pane beside it, over the terminal), and around the composer. **A border stays** on a text field (`fieldBorder`), as a focus ring (`focus`, 2 px), and for now on a menu's and a dialog's edge. `borderSubtle` and `borderStrong` are the old outlines: what a later pass restyles loses them, and nothing new uses them.
- **State is a tint, never a box**: under the pointer `hover`, pressed `pressed`, the open row or view `accentSoft` with its label semibold, a toggle that's on `accentSoft` with its icon in `accentInk` (`IconTap(lit:)`). A state in words is a pill (`PhasePill`): the state's ink on its soft fill (`needs` on `needsSoft`, `running` on `accentSoft`, `done` on `doneSoft`, `crashed` on `crashedSoft`), a state that asks for nothing `textSecondary` on `raised`. A link shown as a pill is `PillLink` (`accentInk` on `accentSoft`).
- **Panes float.** The window is `window`, with `NushiTheme.windowPad` (8) around the panes and `paneGap` (8) between them. The main area is one pane (`Pane`: `base`, corners `panel` 14, its content cut to them): the bars that come and go, the view's header, the view, and for a chat its side panes and terminal, hairlines between. A chat's details are beside its pane, each widget a card of its own (`base`, `panel`) with the gap between, 320 wide; they slide in and out, and the pane's edge is drawn following them (`Pane.reach`), so nothing gliding in it is cut. Radii nest: a pane 14, a card 12, a row or control 8, the picked segment `inner(control, 3)`.
- **The sidebar has no pane and no border.** A strip 32 high under the traffic lights, which stay where macOS puts them (9 to 23 from the top), holds Arrange and the hide button; New chat is a `WideButton` (38 high, `raised`, its key a `KeyCap`); a chat's row is 34 high with 2 between, its title `textSecondary`, the open one `text` semibold on `accentSoft`; a group's name is a small muted label (11.5, semibold, `textMuted`) with its collapse chevron after it, shown under the pointer, with the focus, or while collapsed; Jira, GitHub and Settings are quiet rows 32 high, with no line over them (the list fades out at its end); a chat that needs you says so in a small pill at its row's end, where the row has room. Its foot is the status card (`StatusBar(card:)`): the agents' counts and the memory. With the sidebar hidden the pane reaches the window's left margin, its header starting past the lights, and the same counts and memory are a line under the pane on the window's background.
- **A header is `PaneHeader.height` (56) high, with a hairline under it and no fill**: the chat's, a view's, a side pane's, so their lines meet. The chat's row starts at the transcript's gutter (24) and ends 12 from the pane's edge: title 14 semibold, the Jira issue a `PillLink`, the agent's mark and name, the state a `PhasePill` with its dot, then `Segmented(roomy:)` for Chat, Changes and Pull request (a `raised` track, the picked segment `segment`, a count as a small accent pill), and icon buttons 32 square (`IconTap.header`), lit while what they show is open.
- **No colored stripe down the side of a card, a row or a group** (the owner's rule). A chat's color was a bar at its row's left; it is a small lozenge at the row's end (`ColorChip`, 12 × 6, round ends so it reads apart from the round state dots), the same before the title in the header while the sidebar is hidden, and on the phone's list.
- **The phone** takes the surfaces' colors and the chip, and stays one column with no floating panes.

## Consequences
- `raised` went from "a panel or a bar" to "a card": what filled a bar with it (a pane's header, the sidebar, the status bar) has no fill now. Nushi's `base` and `raised` are darker in the dark set, and `raised` a little darker in the light one; Solarized's light cards and Catppuccin's dark ones took new tones, Nord's light window is nord4.
- A row's text sits on the window, so each light set's muted text, and two of its marks, were taken darker where they fell under AA there (Nushi's `textMuted` is the mock's).
- Headers are 12 higher (44 until now, ADR 0072), and the chat's row takes about 70 more before its title, so its parts fold in a window about that much wider; the state's word now folds before the tabs do, which stay a click away longer. Changes' bar takes its short labels in a narrow pane without the worktrees' menu too.
- The margins come out of the transcript: beside the details it keeps 476, not 500, so they hide at the window widths they did (ADR 0092). An expanded browser tab hides them rather than lying over them.
- Amends 0071 (the header's switch is the filled control again, as the mock has it), 0072 (the header's height and fold numbers), 0080 (the top is the sidebar's strip and the pane's header, not one band) and 0092 (the details' widgets are cards, not flat sections with hairlines).

## Still owed, by view
Each is restyled from this page: cards and rows by fill (`raised` on `base`), hairlines only as dividers, pills for state, no outlines, no side stripes.
- **The transcript**: tool rows, subagent lines and findings cards (their borders), the user's bubble, code blocks and diffs (the mock's are darker than the pane), permission and question cards.
- **The composer**: its box (a `raised` card with a `line` border and a shadow in the mock), round buttons, Queue, Steer and Stop.
- **The details cards' contents**: Context's bar and rows, the pull request's card and buttons, tasks, artifacts.
- **Changes**, **Settings**, **Jira**, **GitHub**, **Chat history**: their bars, lists, cards and tables, and their other tab bars (`PlainTabs`).
- **Dialogs, menus, tooltips, toasts**: still outlined in `borderStrong`.
- **The phone**: its details, cards and sheets.
- **The traffic lights**: the mock centres them in the sidebar's top row (26 from the top, 20 in). Moving them is native work that needs a look at a real window; with the sidebar hidden they now sit in the pane's top left corner, above its header's middle.
- **The sidebar's projects** as tiles with a rail: a separate decision (`docs/roadmap.md`).

## Alternatives considered
- Renaming `base` and `raised` to `pane` and `card`: every theme file names them, and some 110 lines of the app.
- `control` at the mock's 10: at 26 to 34 high a row or a button reads as bubbly (ADR 0110), and 8 nests well enough in a pane's 14.
- The details inside the main pane, behind a hairline: the mock has them on the window, and as cards they need no divider.
- A strip across the top for the lights while the sidebar is hidden: the owner took the title bar away for wasting that space (ADR 0080).
- Dropping the counts and the memory with the sidebar: the status bar was the only place for them.
