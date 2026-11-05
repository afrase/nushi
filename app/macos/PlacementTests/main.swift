// The window placement maths (Runner/Placement.swift, ADR 0093), built with
// it by `make test-window` and run with no window: RunnerTests is hosted by
// the app, so xcodebuild test would launch Nushi.
import CoreGraphics
import Foundation

var failed = 0

func expect<T: Equatable>(_ got: T, _ want: T, _ what: String, line: Int = #line) {
  guard got != want else { return }
  failed += 1
  print("FAIL line \(line): \(what): got \(got), want \(want)")
}

func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }

// The owner's desk: the main screen (a laptop, 1800 by 1130 under the menu
// bar and Dock) and a larger display B to its right.
let main = Placement.Screen(id: "MAIN", frame: r(0, 0, 1800, 1169), visible: r(0, 39, 1800, 1100))
let b = Placement.Screen(id: "B", frame: r(1800, 0, 2560, 1440), visible: r(1800, 0, 2560, 1415))
let both = [main, b]

// Saved: round trip, and what isn't one.
let saved = Placement.Saved(frame: r(1900, 100, 1200, 800), display: "B", screen: b.frame, user: r(1950, 150, 900, 700))
expect(Placement.Saved(saved.dict), saved, "round trip")
expect(Placement.Saved(["frame": "1 2 3"]), nil, "three numbers")
expect(Placement.Saved(["display": "B"]), nil, "no frame")
expect(Placement.Saved(["frame": "0 0 0 10"]), nil, "no width")
expect(Placement.Saved(["frame": "1 2 30 40"])?.display, "", "no display")

// The old autosave value: its frame only, the tile state ignored.
let old = #"0 0 1800 1130 0 0 1800 1130 {"tilingState":{"tilingPosition":9,"normalizedSize":1,"untiledFrame":"{{0, 39}, {1800, 1130}}"}}"#
expect(Placement.legacy(old), r(0, 0, 1800, 1130), "legacy")
expect(Placement.legacy(nil), nil, "legacy missing")
expect(Placement.legacy("garbage"), nil, "legacy garbage")

// fit: shrunk to the room, then moved in as little as it takes.
expect(Placement.fit(r(0, 0, 3000, 2000), in: b.visible), b.visible, "too big")
expect(Placement.fit(r(4000, -50, 800, 600), in: b.visible), r(3560, 0, 800, 600), "past the edge")
expect(Placement.fit(r(2000, 100, 800, 600), in: b.visible), r(2000, 100, 800, 600), "inside")

// place: on its own display, even when most of it lies on another.
let straddling = Placement.Saved(frame: r(1000, 100, 1200, 800), display: "B", screen: b.frame, user: nil)
expect(Placement.place(straddling, on: both)?.screen.id, "B", "own display wins")
expect(Placement.place(straddling, on: both)?.frame, r(1800, 100, 1200, 800), "fitted to own display")
// The display moved in the arrangement: the window moves with it.
let bLeft = Placement.Screen(id: "B", frame: r(-2560, 0, 2560, 1440), visible: r(-2560, 0, 2560, 1415))
expect(Placement.place(saved, on: [main, bLeft])?.frame, r(-2460, 100, 1200, 800), "display moved")
expect(Placement.place(saved, on: [main, bLeft])?.user, r(-2410, 150, 900, 700), "user frame moved")
// Its display missing: the screen most of it lies on.
expect(Placement.place(straddling, on: [main])?.screen.id, "MAIN", "display missing")
expect(Placement.place(straddling, on: [main])?.frame, r(600, 100, 1200, 800), "fitted to the main screen")
expect(Placement.place(saved, on: [main]) == nil, true, "on no connected screen")
// The old value has no display: the screen it lies on.
let migrated = Placement.Saved(frame: Placement.legacy(old)!, display: "", screen: .zero, user: nil)
expect(Placement.place(migrated, on: both)?.screen.id, "MAIN", "legacy place")
expect(Placement.place(migrated, on: both)?.frame, r(0, 39, 1800, 1100), "legacy fitted")

// same
expect(Placement.same(r(0, 0, 100, 100), r(10, -10, 90, 120)), true, "within 10")
expect(Placement.same(r(0, 0, 100, 100), r(0, 0, 111, 100)), false, "11 off")

// zoom: a window that doesn't fill its screen fills it, and is remembered.
let small = r(2000, 200, 1000, 700)
var z = Placement.zoom(frame: small, visible: b.visible, user: nil)
expect(z.target, b.visible, "zoom in")
expect(z.user, small, "remembers the user frame")
// And back.
z = Placement.zoom(frame: z.target, visible: b.visible, user: z.user)
expect(z.target, small, "zoom out to the user frame")
// The bug (ADR 0093): a window that fills B with no user frame, or one
// on the main screen, zooms out on B, never to the main screen.
z = Placement.zoom(frame: b.visible, visible: b.visible, user: nil)
expect(z.target, b.visible.insetBy(dx: 256, dy: 141.5), "no user frame")
expect(b.visible.contains(z.target), true, "stays on B")
z = Placement.zoom(frame: b.visible, visible: b.visible, user: r(0, 39, 1800, 1100))
expect(b.visible.contains(z.target), true, "user frame on another screen")
// A user frame that itself fills the screen isn't a way out.
z = Placement.zoom(frame: b.visible, visible: b.visible, user: r(1805, 0, 2555, 1415))
expect(z.target, b.visible.insetBy(dx: 256, dy: 141.5), "filled user frame")
// A user frame half off this screen comes back fitted to it.
z = Placement.zoom(frame: b.visible, visible: b.visible, user: r(3800, 100, 800, 600))
expect(z.target, r(3560, 100, 800, 600), "user frame fitted")

// returnFrame: home's display back and the window elsewhere.
let home = Placement.Saved(frame: small, display: "B", screen: b.frame, user: nil)
expect(Placement.returnFrame(home: home, screens: both, current: "MAIN"), small, "back to B")
expect(Placement.returnFrame(home: home, screens: both, current: "B"), nil, "already on B")
expect(Placement.returnFrame(home: home, screens: [main], current: "MAIN"), nil, "B still missing")
expect(Placement.returnFrame(home: migrated, screens: both, current: "B"), nil, "no home display")

if failed > 0 {
  print("\(failed) failed")
  exit(1)
}
print("placement: ok")
