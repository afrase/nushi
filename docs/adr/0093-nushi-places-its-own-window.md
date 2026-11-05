# 0093. Nushi places its own window

Status: accepted, 2026-11-05.

## Context
The owner, on two displays: "after upgrading the window is restored to the correct monitor but some time later it gets moved to the main monitor. It also tweens to the other monitor which is weird." Just before, they were "maybe opening a chat".

The window kept its frame under the autosave name "Nushi". On macOS 27 setting that name places the window on the main screen, fitted to it, so the app read the frame first and put it back on its own display (3f2c24c3). But setting the name also made AppKit keep the main-screen frame as the one a zoom goes back to (`_saveZoomInFrame`, which a drag or a resize replaces and a programmatic `setFrame` doesn't). A window filling its display (the owner's saved frame fills its screen, with a tile state) counts as zoomed, so the next zoom, a double click in an empty part of a header (ADR 0080), easily made when a double click on a chat's title to rename it lands just past the text, animated it back to the main screen. Dragging the window once after launch hid the bug.

## Decision
- **Nushi saves and restores the place itself**, as `NushiWindowPlacement` in its defaults: the frame, the display's UUID (which outlasts a reconnect, unlike its display ID), that screen's frame then, and the frame a zoom goes back to. No autosave name and no window restoration, so AppKit never places the window, applies a saved tile or keeps a zoom frame of its own. The old `NSWindow Frame Nushi` is read once to migrate (its frame only; the tile state is ignored), then left alone.
- **At launch** the window goes on its own display when that is connected, moved as far as the display moved in the arrangement, and fitted to it; otherwise on the screen most of it lies on; on none, centred.
- **Zoom is Nushi's**: `zoom(_:)` and `performZoom(_:)` toggle between the window's own screen's visible area and the user's frame on that screen (a frame 10% in from each side when there is none), never another screen.
- **A display that goes**: macOS moves the window off it, and that move isn't saved; when the display comes back the window goes home, unless the user moved it meanwhile, which makes their place the new home. A display that only sleeps stays connected and changes nothing.
- The maths is `Placement` (`app/macos/Runner/Placement.swift`): plain functions with no AppKit, tested by `make test-window` with swiftc, since RunnerTests is hosted by the app and would launch it.

## Consequences
- AppKit still does the drag, live resize, full screen (ADR 0080's `keepFullScreen`; the saved frame is the one from before), tiling, Stage Manager, Spaces, minimizing and moving windows off a display that went.
- A move while the home display is gone counts as the user's only during a drag of theirs or up to a second after its button comes up (willMove, posted as a title-bar drag starts, or a header's drag; the window server may post a drag's didMove only at its end, with the button already up), with the left button held (a live resize) or in a zoom: one made from the green button's tiling menu then isn't saved.
- The frame is saved 0.3 s after moves stop, and on close and quit.

## Alternatives considered
- Keeping the autosave name and resetting AppKit's zoom frame after the restore: the zoom frame is private state, and AppKit would still place the window on the main screen first.
- Replacing the header's double click with nothing: a title bar zooms on double click, and the zoom itself was what went to the wrong screen.
