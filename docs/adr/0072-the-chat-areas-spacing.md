# 0072. The chat area's spacing

Status: accepted, 2026-10-31.

## Context
The owner: "I kind of don't like how crammed a lot of the ui is." An audit found row heights mostly fine. The crowding comes from uneven gaps, tight gutters and boxes inside boxes: the chat header had seven gap sizes, side gutters ran from 4 to 20, and every tool call sat in a tinted box. They had rejected layouts that move things, so this is spacing only: the same controls in the same places, with more room.

## Decision
- **One scale, in the theme.** `NushiTheme.gutter` 24 at each side, `barGap` 12 between controls in a bar, `groupGap` 24 between groups of them, `iconGap` 2 between icon buttons, which carry their own padding. The transcript and the composer take the gutter, and the header's and bars' edges match them.
- **Heights.** The chat header and every side pane's header are 44 (`PaneHeader.height`). The composer's box is 48 with 12 inside at its sides; its footer is 8 under it and 12 from the bottom. Both stop at the transcript's cap and keep to its left, so their edges are the text's on a wide window. The tab lines stay on the rows' bottom borders (ADR 0071). The pane's row lies under the header, as it always has.
- **The transcript.** Text 14 on 22; items 16 apart, 32 before what opens a chapter; text capped at the existing `readableWidth` (860) and kept at the left, under the chat's title, not centred.
- **A tool row has no box until it fails.** On the Mac a call is its line: no fill, no outline. A failed one keeps its red outline and tint, on the text column as the permission card is, and its chevron and icon stay where a row without a box has them, so nothing moves as a call fails. "failed" ends where a Preview button does.
- **Gaps come out of room over.** Where a bar would otherwise fold or cut more, it keeps the room: the header takes its full gaps only once everything fits with them (`headerFolds`' `roomy`, on top of its unchanged fold points), and spends the same 97 points it always did below that, with the gutters still 24. The preview pane's title row has 24 between groups from 640 wide and 12 or less below, since at its starting 560 that room is three short names' tabs; under 460 (520 with a page's two more buttons) it has its old gaps and gutters. So have other side panes under 320 and the Changes bar under 560.
- **The phone keeps its values.** It shares `Composer`, `Transcript`, `Collapsible` and `TurnStatus`, each of which decides by `TouchTargets`, and no shared token changed.
- **Light icons where the bars meet.** The owner picked matched line icons for the header: the terminal and Details share one rounded square, a stroke of 1.6 on a 24 box. The preview's title row matches with Show in Finder and its closes, and the header's and that row's ⋯ are three light dots. They're `LineIcon` (`line_icons.dart`), drawn with no font or package; `IconTap.line`, `MenuIcon.line` and `MenuEntry.line` take them, as `IconData` is a final class. Everywhere else stays Material.
- **Ready is said once.** On a pull request's page the Merge control says it, beside the button. The header's move line goes when it would repeat the control's words, and the To do list says nothing of it.

## Consequences
- The header's gaps step between two sets at one width, rather than growing with the window.
- The GitHub and Jira views' own bars, the details panel, Settings and the terminal's tabs keep their spacing. A pull request's page has 24 at least at each side, in the GitHub view too, since it's one page.

## Alternatives considered
- Tightening the gutters at a narrow window: the row's old gaps had enough to give, so the gutters stay 24 at every width and the title stays over the transcript.
- Folding the header sooner to keep 12 and 24 everywhere: folds are what the owner sees as things jumping.
- The audit's three layouts (a side column, a tab strip, a rail): rejected by the owner.
- Putting the pane's title row beside the header, so their bottoms line up: it moves the header and the pane, which is a layout change.
