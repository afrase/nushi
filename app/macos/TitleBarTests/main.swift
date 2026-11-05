// What AppKit takes for its title bar in a window set up as Nushi's
// (Runner/TitleBar.swift, ADR 0080), built with it by `make test-window`.
// The window is never ordered in and no event is sent: AppKit is asked, by
// its own check, whether a point is on content that keeps its double
// clicks and drags (the theme frame's title-bar double-click recognizer and
// the title bar's release both ask it), and which view a press would hit.
import AppKit

var failed = 0

func expect<T: Equatable>(_ got: T, _ want: T, _ what: String, line: Int = #line) {
  guard got != want else { return }
  failed += 1
  print("FAIL line \(line): \(what): got \(got), want \(want)")
}

/// An opaque view, as FlutterView is, that takes presses and says nothing
/// of the title bar.
final class Content: NSView {
  override var isOpaque: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// A window as MainFlutterWindow makes it, its content [covered] or not.
func window(covered: Bool) -> (NSWindow, Content) {
  let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: true)
  w.isReleasedWhenClosed = false
  let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
  let content = Content(frame: wrapper.bounds)
  content.autoresizingMask = [.width, .height]
  wrapper.addSubview(content)
  w.contentView = wrapper
  w.titlebarAppearsTransparent = true
  w.titleVisibility = .hidden
  w.styleMask.insert(.fullSizeContentView)
  if covered { TitleBarCover.cover(wrapper) }
  return (w, content)
}

typealias PointCheck = @convention(c) (AnyObject, Selector, NSPoint) -> Bool
let onContent = NSSelectorFromString("_pointCoincidesWithOpaqueSubview:")

/// Whether AppKit counts [fromTop] points below the window's top, in its
/// middle, as content that keeps its clicks rather than its title bar.
func isContent(_ w: NSWindow, fromTop: CGFloat) -> Bool? {
  guard let frame = w.contentView?.superview, frame.responds(to: onContent) else { return nil }
  let p = frame.convert(NSPoint(x: 400, y: w.frame.height - fromTop), from: nil)
  return unsafeBitCast(frame.method(for: onContent), to: PointCheck.self)(frame, onContent, p)
}

_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)

let (bare, _) = window(covered: false)
let strip = bare.frame.height - bare.contentLayoutRect.height
expect(strip >= 22, true, "a title bar's strip under the transparent title bar (\(strip) points)")
if isContent(bare, fromTop: 16) == nil {
  // macOS 26's AppKit (CI's) has no such check to ask; from 27 on, a
  // missing one means AppKit renamed or dropped it: the cover may no
  // longer work, so a double click on a header's button may zoom the
  // window again.
  let os = ProcessInfo.processInfo.operatingSystemVersion
  if os.majorVersion >= 27 {
    failed += 1
    print("FAIL: AppKit no longer answers \(NSStringFromSelector(onContent)); check TitleBarCover")
  } else {
    print("title bar: macOS \(os.majorVersion) has no \(NSStringFromSelector(onContent)), not asked")
  }
}
let asks = isContent(bare, fromTop: 16) != nil

// Uncovered, an opaque content view in the strip is AppKit's title bar
// (what zoomed the window on a double click on a header's button).
if asks { expect(isContent(bare, fromTop: 16), false, "uncovered: the strip is the title bar's") }

// Covered, all of the strip is content's, high and low in it.
let (covered, content) = window(covered: true)
for top in [2.0, 16, strip - 2] where asks {
  expect(isContent(covered, fromTop: top), true, "covered: \(top) points from the top is content")
}

// The cover takes no press: the content does, in the strip and below it,
// and the traffic lights keep theirs.
let frame = covered.contentView!.superview!
for top in [16.0, strip + 20] {
  let p = frame.convert(NSPoint(x: 400, y: covered.frame.height - top), from: nil)
  expect(frame.hitTest(p) === content, true, "covered: a press \(top) points from the top is the content's")
}
if let close = covered.standardWindowButton(.closeButton), let bar = close.superview {
  let p = frame.convert(bar.convert(NSPoint(x: close.frame.midX, y: close.frame.midY), to: nil), from: nil)
  expect(frame.hitTest(p).map { $0 === close || $0.isDescendant(of: close) } ?? false, true, "the close button keeps its press")
} else {
  failed += 1
  print("FAIL: no close button")
}

// HeaderDrag: a header's press, from its down to Flutter's release.
let at = CGPoint(x: 300, y: 580)
func point(_ dx: CGFloat) -> CGPoint { CGPoint(x: at.x + dx, y: at.y) }

/// A press down at 10 s, the header's arm for it, and its moves past the
/// given distances: the steps of each move.
func press(clicks: Int = 1, armed: TimeInterval? = 10, moves: [CGFloat], held: Bool = true) -> (HeaderDrag, [HeaderDrag.Step]) {
  var d = HeaderDrag()
  _ = d.down(at: 10, clicks: clicks, at: at)
  if let armed { d.arm(began: armed) }
  let steps = moves.map { d.dragged(to: point($0), held: held) }
  return (d, steps)
}

do {
  // The window moves from the dragged event that goes past the pan's
  // slop, once: the later ones go on to Flutter.
  var (d, steps) = press(moves: [1, HeaderDrag.panSlop, 3, 40])
  expect(steps, [.pass, .pass, .moveWindow, .pass], "an armed press moved past the pan's slop")
  expect(d.dragging, true, "the window server has the press")
  // The window server takes the release: the button seen up is Flutter's
  // release, once, and the real release, if it comes later, is dropped.
  expect(d.letGo(held: true), false, "still held: no release")
  expect(d.letGo(held: false), true, "let go: Flutter's release")
  expect(d.letGo(held: false), false, "no second release")
  expect(d.up(), .drop, "the real release after Flutter had one")
  expect(d.down(at: 12, clicks: 1, at: at), .pass, "the next press goes as it is")
}
do {
  // The real release first: it's Flutter's one, and no click.
  var (d, _) = press(moves: [3])
  expect(d.up(), .dragReleased, "the real release of a drag")
  expect(d.letGo(held: false), false, "nothing more to let go")
}
do {
  // No release came, and the next press did: Flutter is let go first, or
  // it would take the press for a move of the last one.
  var (d, _) = press(moves: [3])
  expect(d.down(at: 11, clicks: 1, at: at), .releaseFirst, "a press while Flutter holds the last")
  expect(d.up(), .pass, "that press's release")
}

// A click never moves the window, nor a press the header never armed, one
// armed after its release, or one armed for an earlier press.
expect(press(moves: [1, HeaderDrag.panSlop]).1, [.pass, .pass], "a click")
expect(press(armed: nil, moves: [3, 40]).1, [.pass, .pass], "not armed: a control's press")
expect(press(armed: 9, moves: [3, 40]).1, [.pass, .pass], "armed for an earlier press")
expect(press(armed: 9.9995, moves: [3]).1, [.moveWindow], "the engine's rounding down")
do {
  var d = HeaderDrag()
  _ = d.down(at: 10, clicks: 1, at: at)
  expect(d.up(), .pass, "a click's release")
  d.arm(began: 10)
  expect(d.dragged(to: point(40), held: true), .pass, "armed after its release")
  expect(d.letGo(held: false), false, "no press to let go")
}
// The button up already (its release still queued): no drag, which would
// follow the pointer with no button held.
expect(press(moves: [3, 40], held: false).1, [.pass, .pass], "the button already up")

// A double click's second press (or third): its release is the header's
// double click, until it goes past a click's slop; then it's a drag, as a
// title bar's.
expect(press(clicks: 2, moves: [3, HeaderDrag.clickSlop, 20]).1, [.pass, .pass, .moveWindow], "a second press")
expect(press(clicks: 3, moves: [3, 20]).1, [.pass, .moveWindow], "a third press")

// A press whose release Flutter never got (a web view's tracking took it):
// the pointer moving with no button is the sign, as for a drag's, but its
// real release, if it comes after all, goes on.
do {
  var d = HeaderDrag()
  _ = d.down(at: 10, clicks: 1, at: at)
  expect(d.letGo(held: true), false, "held: no release")
  expect(d.letGo(held: false), true, "moved with no button: Flutter's release")
  expect(d.up(), .pass, "a release of no drag goes on")
}

if failed > 0 {
  print("\(failed) title bar check(s) failed")
  exit(1)
}
print("title bar: ok")
