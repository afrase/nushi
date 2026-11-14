# 0116. The title buttons stay put, and a hidden sidebar peeks

Status: accepted, 2026-11-14.

## Context
The sidebar's show/hide button rested in two places: at the right of the sidebar's top strip while it showed, and past the traffic lights in the main pane's header while it was hidden, gliding between them with the slide (`SidebarGlide`). A press moved it, against the owner's rule that a toggle never moves when pressed (ADR 0111). Claude's desktop app keeps it in one place, right of the traffic lights, whatever the sidebar does, and with its sidebar hidden, the pointer on that button brings the sidebar over the chat for as long as the pointer stays on it.

## Decision
- **The title buttons** (`TitleButtons`, `sidebar_button.dart`) are drawn over the window's top left by `SidebarBeside`, past the lights: the sidebar's button first. They are at one place in the window, the first icon 5 past where the lights leave room (`lightsInset`), level with the headers' middle, whether the sidebar shows, is hidden or slides: over the sidebar's top strip and the pane's header alike. Nothing moves them, so the glide of the button is gone; what leads a header still follows the sidebar's edge (`SidebarFollow`).
- **The sidebar's strip** has Arrange alone at its right. The sidebar is never narrower than the title buttons and Arrange need side by side (`Sidebar.minWidth`).
- **Linux too**: the sidebar's strip is as tall as the Mac's (the window's margin and a header), so the buttons sit at the same height in the strip and in a header there too; New chat starts under it.
- A header with the sidebar hidden starts past the buttons (`hiddenHeaderStart`).
- **A hidden sidebar peeks** (`SidebarBeside`, `sidebar_beside.dart`): the pointer on the sidebar's button, or resting 150 ms on the window's left edge (its margin, under the headers' band), slides the sidebar in over the main pane, which doesn't move. It's the same sidebar, working as it does shown (a pick, a menu, a drag), on a card 8 in from the window's top, left and bottom: its own `window` fill, so New chat and the status card stand out on it as they do shown, with what floats has, a soft shadow and a hairline (ADR 0111), not `raised`, on which those cards would vanish. It slides away once the pointer has been off it, the title buttons and the edge for 300 ms (a move on a slant to it doesn't close it), never while one of its menus (`MenuOpened`) or a dialog is open. Its button pressed then shows it for good, at once where it floated, with no slide. Hidden by its button, it doesn't peek until the pointer has left the button. Under Reduce Motion it comes and goes at once. The phone has no sidebar to hide.

## Consequences
- Amends 0111 (the strip's buttons: Arrange at its right, the sidebar's button past the lights; on Linux the strip is the Mac's height).
