# 0087. Settings is a modal over the window

## Context
ADR 0053 made Settings a view in the chat's place, so its pages had room. With themes (ADR 0086) a pick should be judged on the app itself, and Settings in the chat's place hid the very chat a theme repaints. The owner: "I'm thinking we should make the settings a modal instead."

## Decision
- **Settings opens over the window**, which stays in sight, dimmed, behind it: about 960×720 at most, centered, 40 px from the window's edges when the window is smaller; the same nav of sections and pages (`settings_rows.dart`'s layout, ADR 0053's), under a title bar with Close. A theme picked repaints the app behind it at once.
- **It's state, not a place**: `Daemon.settingsOpen` (its section and the agent Agents marks), beside `place`, which it never changes. Closing it (Esc, Close, ⌘, again, a click on the dim) leaves the window as it was, the focus back where it was. Every way in is still `Daemon.openSettings(section:, folder:, agent:)`; the sidebar's Settings row opens it and is never marked as the place.
- **Nothing behind it takes keys or focus** while it's open: the app behind is out of focus traversal, and the app's own keys (⌘K, ⌘N, ⌘1–⌘9…) stop at the modal, but ⌘,. A menu bar item, or anything in Settings that starts work elsewhere (a chat from a skill, a chat's copy opened from Chat history, a trust card asking), shuts it first; going to a place or picking a chat does too. A sheet opened from a page (Set up, Add server) is a dialog over the modal and keeps it.

## Consequences
- A page has about 700 px for its content at most, less in a small window: pages are laid out for that width (Appearance's cards are three across at most).
- ADR 0053's "Esc goes back to what showed before" is the modal's own: nothing in the main area moved.
- The window's size no longer sets Settings' size; a long page scrolls inside the modal.

## Alternatives considered
- Keep Settings in the chat's place: a theme can't be judged on the chat it repaints.
- A separate window (macOS's usual Settings window): ADR 0053's reasons stand (focus moving between windows on every deep link).
- A modal route on the navigator: its open and closed state would live beside the daemon's and the deep links that switch a page while it's open would have to reach into the route.
